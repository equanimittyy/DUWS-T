// Locality: server, [] call'd at load. The table fnc_opcom_task_step dispatches through, the re-garrison a settle
// or a capture ends on, and guard and garrison, which are too small to earn a file. Move, capture and intercept
// carry their own, so the table is the only place that knows every order. A handler never asks whether the
// tasking is live: the step context normalises that away.
//
// DUWS_opcom_orders row: [_refresh, _step].
//   [_t, _live] call _refresh -> "arrived" / "water" / "moving" for a virtual tasking, "" for a live one the
//     engine moves. It also re-plans a moving target, which must happen before the record walks its route.
//   [_t, _ctx] call _step -> true when the record is finished this tick, so the ferry and stream stages skip it.
//   _ctx: [_pos, _grp, _live, _engaged, _arrived, _adv].
if (!isServer) exitWith {};

DUWS_fnc_opcom_garrisonInto = {
    params ["_t", "_zk"];
    _t set ["order", "garrison"]; _t set ["homeZone", _zk];
    _t set ["target", []]; _t set ["route", []]; _t set ["returnZone", ""]; _t set ["settleZone", ""];
    [_zk] call DUWS_fnc_opcom_zoneReserveSync;
};

DUWS_fnc_opcom_refreshMarch = {
    params ["_t", "_live"];
    if (_live) exitWith { "" };
    [_t] call DUWS_fnc_opcom_advance
};

// A held order owns no route, so advancing one would plan a march to the point it already stands on.
DUWS_fnc_opcom_refreshHold = { "" };

// Holds its point -- no march, no heal -- but the stream stage still renders it on approach or stows it.
DUWS_fnc_opcom_stepGuard = { false };

DUWS_fnc_opcom_stepGarrison = {
    params ["_t"];
    private _full = _t get "fullForce";
    _t set ["effForce", _full min ((_t get "effForce") + OPCOM_GARRISON_HEAL_RATE * _full)];
    // True, not false: a garrison rests virtual and defends through its zone's reserve wave, so it never streams.
    true
};

DUWS_opcom_orders = createHashMapFromArray [
    ["move",      [DUWS_fnc_opcom_refreshMarch,     DUWS_fnc_opcom_stepMove]],
    ["capture",   [DUWS_fnc_opcom_refreshMarch,     DUWS_fnc_opcom_stepCapture]],
    ["intercept", [DUWS_fnc_opcom_refreshIntercept, DUWS_fnc_opcom_stepIntercept]],
    ["guard",     [DUWS_fnc_opcom_refreshHold,      DUWS_fnc_opcom_stepGuard]],
    ["garrison",  [DUWS_fnc_opcom_refreshHold,      DUWS_fnc_opcom_stepGarrison]]
];

// An order with no row holds where it stands rather than throwing the daemon's tick.
DUWS_opcom_orderHold = [DUWS_fnc_opcom_refreshHold, DUWS_fnc_opcom_stepGuard];
