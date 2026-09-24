// Locality: server. Give a tasking an active order and target: plan the route, arm the commit hold. Returns
// true if it took. A live unit is re-ordered in place too, except a bound ferry carry (the transport owns it);
// a re-issue before the commit hold expires is refused.
//   _order: one of the orders below (opcom_orders_and_regarrison.md). `guard` holds where it stands and ignores
//     _target; `move` and `patrol` march to _target and settle to guard there. A `capture` takes the BLUFOR-held
//     holding at _target -- a zone, or a town they have garrisoned -- and aims at its centre; it ends when the ground
//     is no longer theirs (fnc_opcom_task_step). An `intercept`'s _target is a belief row key (a BLUFOR group's
//     netId); it follows the row's believed position.
//   _returnZone: `return` only, and required by it -- the site key, zone or town, whose garrison it joins on
//     arrival. A boat goes to the site's port instead of _target (never a land point); a portless one refuses it.
//   _errand: `errand` only, and required by it -- a supply run: ["reinforce" | "fortify" | "rapport", townIndex],
//     ["build", pos, type, refund] or ["mine", pos, [variant, [cols, rows]], refund], delivered on arrival
//     (DUWS_fnc_opcom_deliver) in place of a settle, and the truck spent. A build that finds no ground pays refund
//     back.
params ["_t", "_order", ["_target", []], ["_returnZone", ""], ["_errand", []]];
if (!isServer) exitWith { false };

if (!(_order in ["capture", "move", "patrol", "return", "errand", "guard", "intercept"])) exitWith {
    ["WARN", "OPCOM", format ["task: unknown order %1", _order]] call fnc_log; false
};
private _isReturn = _order isEqualTo "return";
private _isErrand = _order isEqualTo "errand";
if (_isReturn && {_returnZone isEqualTo ""}) exitWith {
    ["WARN", "OPCOM", format ["task: a return needs a site to garrison into (tasking %1)", _t get "id"]] call fnc_log; false
};
if (_isErrand && {_errand isEqualTo []}) exitWith {
    ["WARN", "OPCOM", format ["task: an errand needs goods to carry (tasking %1)", _t get "id"]] call fnc_log; false
};
if (_order isNotEqualTo "guard" && {_target isEqualTo []}) exitWith {
    ["WARN", "OPCOM", format ["task: order %1 needs a target", _order]] call fnc_log; false
};
if (_isErrand && {!((_errand param [0, ""]) in ["reinforce", "fortify", "rapport", "build", "mine"])}) exitWith {
    ["WARN", "OPCOM", format ["task: unknown errand %1", _errand]] call fnc_log; false
};
// An errand is goods spent on arrival, so it rides a supply unit (docs/plans/opcom/opcom_plan.md, What AP buys).
if (_isErrand && {!("supply" in (_t get "flags"))}) exitWith {
    ["INFO", "OPCOM", format ["task: tasking %1 carries no supply -- errand %2 refused", _t get "id", _errand]] call fnc_log; false
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
    // Zones first, so ground that is both falls to the bigger prize: a town inside a zone the player also holds is
    // taken by taking the zone.
    private _i = WARCOM_zones_controled_by_BLUFOR findIf {
        (_x distance2D _target) <= (([[_x] call fnc_zone_key] call fnc_site_at) getOrDefault ["radius", 0])
    };
    if (_i >= 0) then { _zk = [WARCOM_zones_controled_by_BLUFOR select _i] call fnc_zone_key } else {
        // A town the player garrisoned is capture ground too. Only a garrisoned one: a town with no tier changes
        // hands on reputation, and there would be nothing for an attacker to beat.
        private _tiers = missionNamespace getVariable ["DUWS_townGarrisonTier", []];
        for "_n" from 0 to (count _tiers - 1) do {
            if (_zk isEqualTo "" && {(_tiers select _n) > 0}
                && {([_n] call fnc_town_garrison_ownerAt) isEqualTo "BLU"}) then {
                private _tk = [_n] call fnc_town_site_key;
                private _site = [_tk] call fnc_site_at;
                private _sp = _site getOrDefault ["pos", []];
                if (_sp isNotEqualTo [] && {(_sp distance2D _target) <= (_site getOrDefault ["radius", 0])}) then {
                    _zk = _tk;
                };
            };
        };
    };
};
if (_order isEqualTo "capture" && {_zk isEqualTo ""}) exitWith {
    ["WARN", "OPCOM", format ["task: no BLUFOR-held holding at capture target %1", _target]] call fnc_log; false
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
private _rz = ["", _returnZone] select _isReturn;
private _boatHome = _isReturn && {(_t get "moveType") isEqualTo "boat"};
private _port = [_rz] call DUWS_fnc_opcom_portOf;
if (_boatHome && {_port < 0}) exitWith {
    ["INFO", "OPCOM", format ["task: site %1 has no port -- boat %2 refused", _rz, _t get "id"]] call fnc_log; false
};
if (_boatHome) then { _target = [_port] call DUWS_fnc_opcom_c2w };
// Direct route (lambda 0): distance only.
private _plan = if (_order isEqualTo "guard") then { [[], "grid"] } else {
    [_t get "pos", _target, _t get "moveType", 0] call fnc_opcom_route
};
_plan params ["_pts", "_mode"];
if (_order isNotEqualTo "guard" && {_pts isEqualTo []}) exitWith {
    ["INFO", "OPCOM", format ["task: no dry route for tasking %1 to %2 -- refused", _t get "id", _target]] call fnc_log; false
};

private _wasGarrison = (_t get "order") isEqualTo "garrison";
_t set ["order", _order];
if (_order isEqualTo "guard") then {
    _t set ["target", _t get "pos"];
    _t set ["route", []];
} else {
    _t set ["target", _target];
    _t set ["route", _pts];
    _t set ["routeMode", _mode];
};
// Cleared off every other order so a recycled record carries no stale supply mark.
_t set ["errand", [[], _errand] select _isErrand];
_t set ["returnZone", _rz];
_t set ["targetZone", _zk]; _t set ["settleZone", ""]; _t set ["inZone", false];
_t set ["interceptKey", _ik];
_t set ["leg", 0];
_t set ["hold", DUWS_opcom_tick + OPCOM_COMMIT_HOLD];
if (_wasGarrison) then { [_t] call DUWS_fnc_opcom_drawOut };
if (_live) then { [_t] call DUWS_fnc_opcom_reOrderLive };
["INFO", "OPCOM", format ["task: tasking %1 -> %2 at %3 (%4, %5 legs)", _t get "id", _order, _t get "target", _t get "routeMode", count (_t get "route")]] call fnc_log;
true
