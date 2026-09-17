// Locality: server. Give a tasking an active order and target: plan the route, arm the commit hold. Returns
// true if it took. A live unit is re-ordered in place too, except a bound ferry carry (the transport owns it);
// a re-issue before the commit hold expires is refused.
//   _order: "capture"/"move"/"guard" (guard holds where it stands, ignores _target). A capture takes the BLUFOR-held
//     zone at _target and aims at its centre; it ends when the zone is OPFOR's (fnc_opcom_task_step). An intercept's
//     _target is a belief row key (a BLUFOR group's netId); it follows the row's believed position.
//   _returnZone: `move` only -- the zone it settles into as a garrison on arrival. Exclusive with _errand.
//     A boat goes to the zone's port instead of _target (never a land point); a portless zone refuses it.
//   _errand: `move` only -- a supply run: ["reinforce" | "fortify" | "rapport", townIndex] or ["build", pos, type],
//     delivered on arrival (DUWS_fnc_opcom_deliver) in place of a settle, and the truck spent.
params ["_t", "_order", ["_target", []], ["_returnZone", ""], ["_errand", []]];
if (!isServer) exitWith { false };

if (!(_order in ["capture", "move", "guard", "intercept"])) exitWith {
    ["WARN", "OPCOM", format ["task: unknown order %1", _order]] call fnc_log; false
};
if (_order isNotEqualTo "guard" && {_target isEqualTo []}) exitWith {
    ["WARN", "OPCOM", format ["task: order %1 needs a target", _order]] call fnc_log; false
};
if (_errand isNotEqualTo [] && {!((_errand param [0, ""]) in ["reinforce", "fortify", "rapport", "build"])}) exitWith {
    ["WARN", "OPCOM", format ["task: unknown errand %1", _errand]] call fnc_log; false
};
private _ik = "";
if (_order isEqualTo "intercept") then {
    _ik = _target;
    private _i = DUWS_opcom_belief_key findIf { _x isEqualTo _ik };
    _target = if (_i < 0) then { [] } else { +(DUWS_opcom_belief_pos select _i) };
};
if (_order isEqualTo "intercept" && {_target isEqualTo []}) exitWith {
    ["WARN", "OPCOM", format ["task: no belief row %1 to intercept", _ik]] call fnc_log; false
};
private _zk = "";
if (_order isEqualTo "capture") then {
    private _i = WARCOM_zones_controled_by_BLUFOR findIf {
        (_x distance2D _target) <= (([[_x] call fnc_zone_key] call fnc_site_at) getOrDefault ["radius", 0])
    };
    if (_i >= 0) then { _zk = [WARCOM_zones_controled_by_BLUFOR select _i] call fnc_zone_key };
};
if (_order isEqualTo "capture" && {_zk isEqualTo ""}) exitWith {
    ["WARN", "OPCOM", format ["task: no BLUFOR-held zone at capture target %1", _target]] call fnc_log; false
};
if (_zk isNotEqualTo "") then { _target = ([_zk] call fnc_site_at) get "pos" };
private _live = (_t get "grp") isNotEqualTo "";
// A bound ferry carry is driven by the transport step, not steerable; refuse rather than fight it.
if (_live && {((_t getOrDefault ["carrying", -1]) >= 0) || {(_t getOrDefault ["ridingOn", -1]) >= 0}}) exitWith {
    ["INFO", "OPCOM", format ["task: tasking %1 is a bound ferry carry -- cannot re-order", _t get "id"]] call fnc_log; false
};
if (DUWS_opcom_tick < (_t get "hold")) exitWith {
    ["INFO", "OPCOM", format ["task: tasking %1 held until tick %2 (now %3)", _t get "id", _t get "hold", DUWS_opcom_tick]] call fnc_log; false
};
private _isMove = _order isEqualTo "move";
private _errandSet = _isMove && {_errand isNotEqualTo []};
private _rz = ["", _returnZone] select (_isMove && {!_errandSet});
private _boatHome = _rz isNotEqualTo "" && {(_t get "moveType") isEqualTo "boat"};
private _port = [_rz] call DUWS_fnc_opcom_portOf;
if (_boatHome && {_port < 0}) exitWith {
    ["INFO", "OPCOM", format ["task: zone %1 has no port -- boat %2 refused", _rz, _t get "id"]] call fnc_log; false
};
if (_boatHome) then { _target = [_port] call DUWS_fnc_opcom_c2w };

private _wasGarrison = (_t get "order") isEqualTo "garrison";
private _hz = _t get "homeZone";
_t set ["order", _order];
if (_order isEqualTo "guard") then {
    _t set ["target", _t get "pos"];
    _t set ["route", []];
} else {
    _t set ["target", _target];
    // Direct route (lambda 0): distance only.
    ([_t get "pos", _target, _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
    _t set ["route", _pts];
    _t set ["routeMode", _mode];
};
// Cleared off a non-move so a recycled record carries no stale re-garrison / supply mark; exclusive on a move.
_t set ["errand", [[], _errand] select _errandSet];
_t set ["returnZone", _rz];
_t set ["targetZone", _zk]; _t set ["settleZone", ""]; _t set ["inZone", false];
_t set ["interceptKey", _ik]; _t set ["contact", false];
_t set ["leg", 0];
_t set ["hold", DUWS_opcom_tick + OPCOM_COMMIT_HOLD];
// Drawing a garrison unit out: delete its reserve-spawned defender (going mobile), then re-sync so the zone's
// reserve pool and ceiling drop by this unit.
if (_wasGarrison && {_hz isNotEqualTo ""}) then {
    private _tok = [_t] call DUWS_fnc_opcom_reserveToken;
    { if ((_x getVariable ["DUWS_garrisonToken", ""]) isEqualTo _tok) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach allGroups;
    [_hz] call DUWS_fnc_opcom_zoneReserveSync;
};
if (_live) then { [_t] call DUWS_fnc_opcom_reOrderLive };
["INFO", "OPCOM", format ["task: tasking %1 -> %2 at %3 (%4, %5 legs)", _t get "id", _order, _t get "target", _t get "routeMode", count (_t get "route")]] call fnc_log;
true
