// Locality: server. Hand a resting (or free) tasking unit an active order and a target: plan its route and
// arm the commit hold. Returns true if the order took. OPCOM cannot re-order a de-virtualised (live) unit --
// control returns only when it re-virtualises -- nor re-issue before the hold passes; both are refused here
// so the one primitive enforces the commitment rules the decision loop (Phase 4) relies on.
//   _order: "assault" "scout" "supply" "move" "guard".
//   _target: objective world position; ignored for guard (holds where it stands).
params ["_t", "_order", ["_target", []]];
if (!isServer) exitWith { false };

if (!(_order in ["assault", "scout", "supply", "move", "guard"])) exitWith {
    ["WARN", "OPCOM", format ["task: unknown order %1", _order]] call fnc_log; false
};
if (_order isNotEqualTo "guard" && {_target isEqualTo []}) exitWith {
    ["WARN", "OPCOM", format ["task: order %1 needs a target", _order]] call fnc_log; false
};
if ((_t get "grp") isNotEqualTo "") exitWith {
    ["INFO", "OPCOM", format ["task: tasking %1 is live -- cannot steer until it re-virtualises", _t get "id"]] call fnc_log; false
};
if (DUWS_opcom_tick < (_t get "hold")) exitWith {
    ["INFO", "OPCOM", format ["task: tasking %1 held until tick %2 (now %3)", _t get "id", _t get "hold", DUWS_opcom_tick]] call fnc_log; false
};

private _wasGarrison = (_t get "order") isEqualTo "garrison";
private _hz = _t get "homeZone";
_t set ["order", _order];
if (_order isEqualTo "guard") then {
    _t set ["target", _t get "pos"];
    _t set ["route", []];
} else {
    _t set ["target", _target];
    // Direct route (lambda 0): distance only. Flank/encircle (lambda 1) arrives with templates in Phase 5.
    ([_t get "pos", _target, _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
    _t set ["route", _pts];
    _t set ["routeMode", _mode];
};
_t set ["leg", 0];
_t set ["hold", DUWS_opcom_tick + OPCOM_COMMIT_HOLD];
// Drawing a garrison unit out of its zone reserve: pull any reserve-spawned defender (it is going mobile),
// then re-sync so the zone's reserve pool + ceiling drop by this unit. (A P4 draw-lock will refuse this while
// the zone is contested; P3 draws by hand.)
if (_wasGarrison && {_hz isNotEqualTo ""}) then {
    private _tok = [_t] call DUWS_fnc_opcom_reserveToken;
    { if ((_x getVariable ["DUWS_garrisonToken", ""]) isEqualTo _tok) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach allGroups;
    [_hz] call DUWS_fnc_opcom_zoneReserveSync;
};
["INFO", "OPCOM", format ["task: tasking %1 -> %2 at %3 (%4, %5 legs)", _t get "id", _order, _t get "target", _t get "routeMode", count (_t get "route")]] call fnc_log;
true
