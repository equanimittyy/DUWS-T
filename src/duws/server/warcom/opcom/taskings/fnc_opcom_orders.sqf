// Locality: server, [] call'd at load. One handler per order, and the table fnc_opcom_task_step dispatches
// through. A handler never asks whether the tasking is live -- the step context normalises that away.
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

// Settle an arrived move: re-garrison a returnZone or hold as guard. Mutates the record only; true if it garrisoned.
DUWS_fnc_opcom_settleMove = {
    params ["_t", "_pos"];
    private _rz = _t getOrDefault ["returnZone", ""];
    if (_rz isNotEqualTo "") exitWith { [_t, _rz] call DUWS_fnc_opcom_garrisonInto; true };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    false
};

// -> true the tick an attacker enters its target zone's radius. A live one tracks it too, or a later stow re-reports.
DUWS_fnc_opcom_captureEnters = {
    params ["_t", "_pos"];
    private _site = [_t get "targetZone"] call fnc_site_at;
    private _in = (_pos distance2D (_site get "pos")) <= (_site get "radius");
    private _entered = _in && {!(_t getOrDefault ["inZone", false])};
    _t set ["inZone", _in];
    _entered
};

// -> true if it garrisoned. A live attacker inside the zone guards until it stows, so it never vanishes in front of a
// player; one still on the road re-garrisons there.
DUWS_fnc_opcom_captureEnd = {
    params ["_t", "_pos", "_grp"];
    private _zk = _t get "targetZone";
    private _site = [_zk] call fnc_site_at;
    _t set ["targetZone", ""];
    if ((_pos distance2D (_site get "pos")) > (_site get "radius")) exitWith {
        _t set ["hold", 0];
        if !([_t, "move", _site get "pos", _zk] call fnc_opcom_task) then { [_t, "guard"] call fnc_opcom_task };
        false
    };
    if (isNull _grp) exitWith { [_t, _zk] call DUWS_fnc_opcom_garrisonInto; true };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []]; _t set ["settleZone", _zk];
    [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder;
    ["INFO", "OPCOM", format ["capture: tasking %1 holds %2, garrisoning when it stows", _t get "id", _zk]] call fnc_log;
    false
};

DUWS_fnc_opcom_refreshMarch = {
    params ["_t", "_live"];
    if (_live) exitWith { "" };
    [_t] call DUWS_fnc_opcom_advance
};

DUWS_fnc_opcom_refreshIntercept = {
    params ["_t", "_live"];
    [_t, _live] call DUWS_fnc_opcom_interceptFollow;
    if (_live) exitWith { "" };
    [_t] call DUWS_fnc_opcom_advance
};

// A held order owns no route, so advancing one would plan a march to the point it already stands on.
DUWS_fnc_opcom_refreshHold = { "" };

DUWS_fnc_opcom_stepMove = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live", "", "_arrived"];
    // errand and returnZone are exclusive (set upstream), so a delivery cannot also settle.
    private _errand = _t getOrDefault ["errand", []];
    if (_errand isNotEqualTo []) exitWith {
        private _landed = (_pos distance2D (_t get "target")) < OPCOM_DELIVER_ARRIVE;
        if (_landed) then {
            [_t] call DUWS_fnc_opcom_deliver;
            if (_live) then { [_grp] call DUWS_fnc_opcom_despawn; _t set ["grp", ""] };
            _t set ["status", "done"];
        };
        _landed
    };
    if (!_arrived) exitWith { false };
    // A guard settle re-orders the group so map and group agree. A garrison settle despawns -- a combatant's token
    // now sits in the reserve wave, so a live copy would fight twice.
    if ([_t, _pos] call DUWS_fnc_opcom_settleMove) then {
        if (_live) then { [_t] call DUWS_fnc_opcom_reVirt };
    } else {
        if (_live) then { [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder };
    };
    true
};

DUWS_fnc_opcom_stepCapture = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live"];
    private _zk = _t get "targetZone";
    if (!([_zk] call fnc_zone_bluforHeld)) exitWith { [_t, _pos, _grp] call DUWS_fnc_opcom_captureEnd };
    private _entered = [_t, _pos] call DUWS_fnc_opcom_captureEnters;
    // Below is the virtual attacker's stand-in for a fight that never renders; a live one takes the zone by winning it.
    if (_live) exitWith { false };
    if (_entered) then {
        private _ni = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
        if (_ni >= 0) then { [(zone_namePOS_pairs select _ni) select 0, []] call fnc_enemy_contact };
    };
    // No BLUFOR count: any within K would have rendered the attacker, so its stored force outnumbers nobody.
    if ((_t get "inZone") && {(_t get "effForce") > 0}) then {
        private _zpos = ([_zk] call fnc_site_at) get "pos";
        private _trg = missionNamespace getVariable [format ["trigger_%1_%2", floor abs (_zpos select 0), floor abs (_zpos select 1)], objNull];
        if (!isNull _trg) then { call compile ((triggerStatements _trg) select 1) };
    };
    false
};

DUWS_fnc_opcom_stepIntercept = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp"];
    if (([_pos, _t get "target"] call DUWS_fnc_opcom_cellDist) != 0) exitWith { false };
    [_t, _pos, _grp] call DUWS_fnc_opcom_interceptArrive;
    false
};

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
