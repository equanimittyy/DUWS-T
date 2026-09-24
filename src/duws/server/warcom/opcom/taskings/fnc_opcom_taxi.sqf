// Locality: server, [] call'd at load. Land-taxi: a lift over dry ground for a foot unit just given an order, bound
// at commit when the pickup drive plus the carry beats the walk (opcom_plan.md §Appraisal). The carry itself is the
// ferry's -- same binding, same orchestrator, same live and virtual steps -- with the drop latched at the bind.
if (!isServer) exitWith {};

// Ticks to cross a straight-line distance, the measure the delay discount runs on.
DUWS_fnc_opcom_moveTicks = {
    params ["_dist", "_moveType"];
    (_dist / OPCOM_GRID_CELL) * (DUWS_opcom_speed getOrDefault [_moveType, 15])
};

DUWS_fnc_opcom_taxiPool = {
    params [["_excludeId", -1]];
    [_excludeId, ["wheeled", "tracked", "rotary"]] call DUWS_fnc_opcom_ferryPool
};

// A lift carries a foot unit marching to a target it has not reached. A hull drives the rider's own ground, so only
// a rotor takes a route that crosses water -- the rest is the water ferry's job.
DUWS_fnc_opcom_taxiFits = {
    params ["_rider", "_moveType"];
    if (!("transportable" in (_rider get "flags")) || {(_rider getOrDefault ["ridingOn", -1]) >= 0}) exitWith { false };
    if (!((_rider get "order") in ["capture", "intercept", "return", "move"])) exitWith { false };
    if (_moveType isEqualTo "rotary") exitWith { true };
    ((_rider get "route") findIf { [_x] call DUWS_fnc_opcom_isWaterPt }) < 0
};

// The AP a lift adds to an order: the same Value lands sooner, and the delay discount prices the time it saves.
DUWS_fnc_opcom_taxiWorth = {
    params ["_value", "_walk", "_lift"];
    if (_lift >= _walk) exitWith { 0 };
    _value * ((2 ^ ((_walk - _lift) / OPCOM_VALUE_HALFLIFE)) - 1)
};

// The rider's fields come loose, so the Recruit rows can price an order the pick has not committed yet.
DUWS_fnc_opcom_taxiSaving = {
    params ["_value", "_rp", "_riderMove", "_to", "_from", "_moveType"];
    private _lift = [(_from distance2D _rp) + (_rp distance2D _to), _moveType] call DUWS_fnc_opcom_moveTicks;
    if (_moveType in ["wheeled", "tracked"]) then { _lift = _lift * OPCOM_ROAD_DETOUR };
    [_value, [_rp distance2D _to, _riderMove] call DUWS_fnc_opcom_moveTicks, _lift] call DUWS_fnc_opcom_taxiWorth
};

// The lift that saves the most, and none when walking beats every hull on hand.
DUWS_fnc_opcom_taxiBind = {
    params ["_rider"];
    private _to = _rider get "target";
    private _v = _rider getOrDefault ["expValue", 0];
    if (_v <= 0 || {_to isEqualTo []}) exitWith {};
    private _best = 0;
    private _pick = [];
    {
        if ([_rider, _x get "moveType"] call DUWS_fnc_opcom_taxiFits) then {
            private _s = [_v, _rider get "pos", _rider get "moveType", _to, _x get "pos", _x get "moveType"]
                call DUWS_fnc_opcom_taxiSaving;
            if (_s > _best) then { _best = _s; _pick = _x };
        };
    } forEach ([_rider get "id"] call DUWS_fnc_opcom_taxiPool);
    if (_pick isEqualTo []) exitWith {};
    // The saving is measured straight-line, so check the ground before binding: a hull that cannot drive to the
    // rider would bind and then sit, and no carry phase times a pickup drive out.
    if ((([_pick get "pos", _rider get "pos", _pick get "moveType", 0] call fnc_opcom_route) select 0) isEqualTo []) exitWith {};
    [_pick, _rider, _to] call DUWS_fnc_opcom_carryBind;
    ["INFO", "OPCOM", format ["taxi: tasking %1 rides %2 transport %3 to %4, saving %5 AP", _rider get "id",
        _pick get "moveType", _pick get "id", _to apply { round _x }, _best toFixed 1]] call fnc_log;
};
