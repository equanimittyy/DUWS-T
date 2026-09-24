// Locality: server, [] call'd at load. The lifts, sourced like any other unit (opcom_plan.md §Sourcing): a land-taxi
// priced with the order it carries, and the Ferry a unit stopped at a water leg waits on. Read from the pick's
// unscheduled pass, so nothing here may suspend; the runs route, so they execute after it.
if (!isServer) exitWith {};

DUWS_fnc_opcom_isTaxi = {
    params ["_flags", "_moveType"];
    "transport" in _flags && {_moveType in ["wheeled", "tracked", "rotary"]}
};

DUWS_fnc_opcom_isFerry = {
    params ["_flags", "_moveType"];
    "transport" in _flags && {_moveType in ["boat", "rotary"]}
};

// Conservative for a hull: a line over a bay reads wet though a road runs round it, but a dry line always has a land
// route along it.
DUWS_fnc_opcom_lineDry = {
    params ["_a", "_b"];
    private _steps = (ceil ((_a distance2D _b) / (OPCOM_GRID_CELL / 2))) max 1;
    private _dry = true;
    for "_i" from 0 to _steps do {
        private _f = _i / _steps;
        if ([[(_a select 0) + ((_b select 0) - (_a select 0)) * _f, (_a select 1) + ((_b select 1) - (_a select 1)) * _f, 0]]
            call DUWS_fnc_opcom_isWaterPt) exitWith { _dry = false };
    };
    _dry
};

DUWS_fnc_opcom_freeTaxis = {
    ["freeTaxis", {
        ((call DUWS_fnc_opcom_free) select { [_x get "flags", _x get "moveType"] call DUWS_fnc_opcom_isTaxi })
            apply { [_x] call DUWS_fnc_opcom_freeSource }
    }] call DUWS_fnc_opcom_tickCached
};

// -> [lift ref, saving, price, Cost], or [] when walking beats every lift. _budget caps the lift's price, so a lift
// never prices an order the wallet covers out of reach.
DUWS_fnc_opcom_liftFor = {
    params ["_src", "_to", "_v", "_pw", "_budget"];
    _src params ["", "_from", "", "_rm", "_flags"];
    if !("transportable" in _flags) exitWith { [] };
    private _dry = [_from, _to] call DUWS_fnc_opcom_lineDry;
    private _best = [];
    private _bn = 0;
    {
        _x params ["_ref", "_start", "", "_mt", "", "_price", "_stake"];
        if (_price <= _budget && {_mt isEqualTo "rotary" || {_dry && {[_start, _from] call DUWS_fnc_opcom_lineDry}}}) then {
            private _s = [_v, _from, _rm, _to, _start, _mt] call DUWS_fnc_opcom_taxiSaving;
            private _c = _stake + OPCOM_AP_PER_KM * (_start distance2D _from) / 1000;
            if ((_pw * _s - _c) > _bn) then { _bn = _pw * _s - _c; _best = [_ref, _s, _price, _c] };
        };
    } forEach ((call DUWS_fnc_opcom_freeTaxis)
        + ([DUWS_fnc_opcom_isTaxi, _from, call DUWS_fnc_opcom_zonesOpen] call DUWS_fnc_opcom_hireSources));
    _best
};

// The saving joins the Value, the lift's price the price and its Cost the Cost. expValue stays the walk's: a Ferry
// prices the order, not the ride.
DUWS_fnc_opcom_liftOffer = {
    params ["_best", "_to", "_task", "_label"];
    _best params ["_src", "_v", "_pw", "_c", "_p"];
    private _ref = _src select 0;
    private _name = format ["%1 with %2", _label, [_ref] call DUWS_fnc_opcom_sourceName];
    private _lift = if (_task isEqualTo []) then { [] } else {
        [_src, _to, _v, _pw, (WARCOM_opfor_ap - _p) max 0] call DUWS_fnc_opcom_liftFor
    };
    if (_lift isEqualTo []) exitWith { [[_ref, _task, _pw * _v, []], _p, _name, _v, _pw, _c] };
    _lift params ["_lref", "_s", "_lp", "_lc"];
    [[_ref, _task, _pw * _v, [_lref, _to]], _p + _lp, format ["%1 riding %2", _name, [_lref] call DUWS_fnc_opcom_sourceName],
        _v + _s, _pw, _c + _lc]
};

// -> true once _t has its order and the lift _lift names is bound to carry it. Both are routed before either is
// ordered, so a lift that cannot reach its rider commits neither.
DUWS_fnc_opcom_liftRun = {
    params ["_t", "_task", "_lift"];
    _lift params ["_ref", "_to"];
    private _tr = [_ref] call DUWS_fnc_opcom_raise;
    if (isNil "_tr") exitWith { false };
    private _mt = _tr get "moveType";
    private _reach = (([_tr get "pos", _t get "pos", _mt, 0] call fnc_opcom_route) select 0) isNotEqualTo [];
    private _fits = _mt isEqualTo "rotary" || {((([_t get "pos", _to, _t get "moveType", 0] call fnc_opcom_route) select 0)
        findIf { [_x] call DUWS_fnc_opcom_isWaterPt }) < 0};
    if (!_reach || {!_fits} || {!(([_t] + _task) call fnc_opcom_task)}) exitWith {
        [_ref, _tr] call DUWS_fnc_opcom_dismiss;
        false
    };
    [_tr, _t, _t get "target"] call DUWS_fnc_opcom_carryBind;
    ["INFO", "OPCOM", format ["taxi: tasking %1 rides %2 transport %3 to %4", _t get "id", _mt, _tr get "id",
        (_t get "target") apply { round _x }]] call fnc_log;
    true
};

// P(win) 1: a lift fights for nothing, and the order it unblocks is what it is worth.
DUWS_fnc_opcom_ferrySweep = {
    private _free = ((call DUWS_fnc_opcom_free) select { [_x get "flags", _x get "moveType"] call DUWS_fnc_opcom_isFerry })
        apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    private _out = [];
    {
        private _r = _x;
        if ((_r getOrDefault ["strandTicks", 0]) > 0 && {(_r getOrDefault ["ridingOn", -1]) < 0}
            && {(_r get "status") isNotEqualTo "dead"}) then {
            private _rp = _r get "pos";
            private _v = _r getOrDefault ["expValue", 0];
            private _offers = (_free + ([DUWS_fnc_opcom_isFerry, _rp, _zones] call DUWS_fnc_opcom_hireSources)) apply { [_x, _v] };
            {
                _x params ["_src", "_fv", "", "_c", "_p"];
                private _ref = _src select 0;
                _out pushBack [[_ref, _r get "id"], _p, format ["Ferry %1 %2 with %3", _r get "menu", _r get "id",
                    [_ref] call DUWS_fnc_opcom_sourceName], _fv, 1, _c];
            } forEach ([_offers, _rp, false] call DUWS_fnc_opcom_bestSources);
        };
    } forEach DUWS_opcom_taskings;
    _out
};

DUWS_fnc_opcom_ferryRun = {
    params ["_target"];
    _target params ["_ref", "_rid"];
    private _r = [_rid] call DUWS_fnc_opcom_byId;
    if (isNil "_r" || {(_r getOrDefault ["ridingOn", -1]) >= 0}) exitWith { false };
    private _tr = [_ref] call DUWS_fnc_opcom_raise;
    if (isNil "_tr") exitWith { false };
    private _at = [_tr, _r get "pos"] call DUWS_fnc_opcom_ferryApproach;
    if ((([_tr get "pos", _at, _tr get "moveType", 0] call fnc_opcom_route) select 0) isEqualTo []) exitWith {
        [_ref, _tr] call DUWS_fnc_opcom_dismiss;
        false
    };
    [_tr, _r] call DUWS_fnc_opcom_carryBind;
    _r set ["strandTicks", 0];
    ["INFO", "OPCOM", format ["ferry: tasking %1 takes %2 transport %3 for a water leg", _rid, _tr get "moveType",
        _tr get "id"]] call fnc_log;
    true
};
