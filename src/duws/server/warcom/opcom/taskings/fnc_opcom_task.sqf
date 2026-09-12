// Locality: server. Hand a tasking an active order and a target: plan its route and arm the commit hold.
// Returns true if the order took. A de-virtualised (live) unit is re-ordered too -- the new order is pushed
// onto its group (DUWS_fnc_opcom_reOrderLive) -- except a bound ferry carry, which the transport step owns. A
// re-issue before the commit hold passes is refused, so the one primitive still enforces the commitment rhythm
// the decision loop (Phase 4) relies on.
//   _order: "assault" "move" "guard".
//   _target: objective world position; ignored for guard (holds where it stands).
//   _returnZone: `move` only -- the zone it settles into as a garrison on arrival, else it settles to guard.
//   _supplyDrop: `move` only -- deleted and its delivery completed on arrival, in place of a settle.
//   Exclusive with _returnZone.
params ["_t", "_order", ["_target", []], ["_returnZone", ""], ["_supplyDrop", false]];
if (!isServer) exitWith { false };

if (!(_order in ["assault", "move", "guard"])) exitWith {
    ["WARN", "OPCOM", format ["task: unknown order %1", _order]] call fnc_log; false
};
if (_order isNotEqualTo "guard" && {_target isEqualTo []}) exitWith {
    ["WARN", "OPCOM", format ["task: order %1 needs a target", _order]] call fnc_log; false
};
private _live = (_t get "grp") isNotEqualTo "";
// A ferry carry/ride is driven by the transport step, not a steerable order; refuse rather than fight it.
if (_live && {((_t getOrDefault ["carrying", -1]) >= 0) || {(_t getOrDefault ["ridingOn", -1]) >= 0}}) exitWith {
    ["INFO", "OPCOM", format ["task: tasking %1 is a bound ferry carry -- cannot re-order", _t get "id"]] call fnc_log; false
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
// Cleared off a non-move so a recycled record never re-garrisons or self-deletes on a stale mark; exclusive
// on a move.
private _isMove = _order isEqualTo "move";
_t set ["supplyDrop", _isMove && _supplyDrop];
_t set ["returnZone", ["", _returnZone] select (_isMove && {!_supplyDrop})];
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
if (_live) then { [_t] call DUWS_fnc_opcom_reOrderLive };
["INFO", "OPCOM", format ["task: tasking %1 -> %2 at %3 (%4, %5 legs)", _t get "id", _order, _t get "target", _t get "routeMode", count (_t get "route")]] call fnc_log;
true
