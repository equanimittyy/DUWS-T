// Locality: server, [] call'd at load. Sourcing: each unit an action needs is a free unit or a hire, and one score
// picks between them (opcom_plan.md §Sourcing). Read from the pick's unscheduled pass, so nothing here may suspend.
//
// A source is [ref, start, force, moveType, flags, price, stake, mix]: ref ["free", taskingId] or ["hire", row, zoneKey],
// the price the pick charges, the stake the score adds to Cost, and the recruitMix factor on a hire's Value.
if (!isServer) exitWith {};

DUWS_fnc_opcom_nearestOpen = {
    params ["_pos", "_zones"];
    if (_pos isEqualTo []) exitWith { [] };
    private _best = 1e12;
    private _pick = [];
    { private _d = _pos distance2D (_x select 2); if (_d < _best) then { _best = _d; _pick = _x } } forEach _zones;
    _pick
};

// -> [menu row -> live units, the rows the faction can field now]. The mix is shared out over the fieldable rows only:
// a row the faction cannot hire would hold a share nothing can fill, and push every other row over its own.
DUWS_fnc_opcom_rosterSweep = {
    private _counts = createHashMap;
    {
        if ((_x get "status") isNotEqualTo "dead") then {
            private _r = _x get "menu";
            _counts set [_r, (_counts getOrDefault [_r, 0]) + 1];
        };
    } forEach DUWS_opcom_taskings;
    private _open = (keys DUWS_opcom_recruitMenu) select {
        (((DUWS_opcom_recruitMenu get _x) select 0) findIf { ([_x, "OPF"] call DUWS_fnc_tokenClass) isEqualTo "" }) < 0
    };
    [_counts, _open]
};

DUWS_fnc_opcom_unitCount = {
    { !("supply" in (_x get "flags")) && {(_x get "status") isNotEqualTo "dead"} } count DUWS_opcom_taskings
};

// -> [[row, flags, moveType, force, price, mix], ...]: every row the faction can field now. An unpriced or forceless
// row is one fnc_opcom_recruit refuses.
DUWS_fnc_opcom_hireRowsSweep = {
    (["roster", DUWS_fnc_opcom_rosterSweep] call DUWS_fnc_opcom_tickCached) params ["_counts", "_open"];
    private _mixRow = ["recruitMix"] call DUWS_fnc_opcom_archetypeTable;
    private _out = [];
    {
        (DUWS_opcom_recruitMenu get _x) params ["_comp", "_flags"];
        private _price = OPCOM_AP_UNIT getOrDefault [_x, -1];
        private _force = [_comp] call DUWS_fnc_tokenListForce;
        if (_price >= 0 && {_force > 0}) then {
            _out pushBack [_x, _flags, [_comp] call DUWS_fnc_opcom_moveType, _force, _price,
                [_mixRow, _counts, _x, _open] call DUWS_fnc_opcom_mixFactor];
        };
    } forEach _open;
    _out
};

DUWS_fnc_opcom_freeSource = {
    params ["_t"];
    [["free", _t get "id"], _t get "pos", _t get "effForce", _t get "moveType", _t get "flags", 0,
        [_t] call DUWS_fnc_opcom_commitCost, 1]
};

// The rows [flags, moveType] call _fits keeps, each raised at the zone of _zones nearest _near, a boat at that zone's
// port. At the unit cap only a truck is still hired.
DUWS_fnc_opcom_hireSources = {
    params ["_fits", "_near", "_zones"];
    private _capped = (["unitCount", DUWS_fnc_opcom_unitCount] call DUWS_fnc_opcom_tickCached) >= OPCOM_CAP_UNITS;
    private _out = [];
    {
        _x params ["_row", "_flags", "_mt", "_force", "_price", "_mix"];
        if ((!_capped || {"supply" in _flags}) && {[_flags, _mt] call _fits}) then {
            private _boat = _mt isEqualTo "boat";
            private _from = [_zones, _zones select { ([_x select 0] call DUWS_fnc_opcom_portOf) >= 0 }] select _boat;
            private _z = [_near, _from] call DUWS_fnc_opcom_nearestOpen;
            if !(_z isEqualTo []) then {
                private _zk = _z select 0;
                private _start = [_z select 2, [[_zk] call DUWS_fnc_opcom_portOf] call DUWS_fnc_opcom_c2w] select _boat;
                _out pushBack [["hire", _row, _zk], _start, _force, _mt, _flags, _price, _price, _mix];
            };
        };
    } forEach (["hireRows", DUWS_fnc_opcom_hireRowsSweep] call DUWS_fnc_opcom_tickCached);
    _out
};

// -> [[source, Value, P(win), Cost, price], ...]: the best of _offers sent at _to, and beside it a dearer one that
// outscores it, so the pick can bank toward what the wallet cannot pay yet. _offers pairs each source with the Value
// it returns at _to before the delay; _price and _cost are the action's own, to which each source adds its own.
// Distance is scored and never charged, which is what lets a near hire beat a far free unit.
DUWS_fnc_opcom_bestSources = {
    params ["_offers", "_to", "_fight", ["_price", 0], ["_cost", 0]];
    private _best = [];
    private _bs = -1;
    private _paid = [];
    private _ps = -1;
    {
        _x params ["_src", "_value"];
        _src params ["_ref", "_from", "_force", "_mt", "", "_sp", "_stake", "_mix"];
        private _pw = 1;
        if (_fight) then {
            _pw = if ((_ref select 0) isEqualTo "hire") then {
                [_to, _force] call DUWS_fnc_opcom_pWinWith
            } else {
                [_to, _from, _force] call DUWS_fnc_opcom_pWinSend
            };
        };
        if (_pw >= OPCOM_PWIN_FLOOR) then {
            private _d = _from distance2D _to;
            private _v = _value * _mix * ([_d, _mt] call DUWS_fnc_opcom_moveDelay);
            private _c = _cost + _stake + OPCOM_AP_PER_KM * _d / 1000;
            private _s = [_v, _pw, _c] call DUWS_fnc_opcom_score;
            private _row = [_src, _v, _pw, _c, _price + _sp];
            if (_s > _bs) then { _bs = _s; _best = _row };
            if ((_price + _sp) <= WARCOM_opfor_ap && {_s > _ps}) then { _ps = _s; _paid = _row };
        };
    } forEach _offers;
    if (_best isEqualTo []) exitWith { [] };
    if (_paid isEqualTo [] || {_ps >= _bs}) exitWith { [_best] };
    [_paid, _best]
};

// -> the tasking _ref names, hired first when it is a hire; nil when the hire is refused. The candidate's price
// already carries a hire, so fnc_opcom_recruit charges nothing.
DUWS_fnc_opcom_raise = {
    params ["_ref"];
    _ref params ["_kind", "_a", ["_zk", ""]];
    if (_kind isEqualTo "free") exitWith { [_a] call DUWS_fnc_opcom_byId };
    [_a, ([_zk] call fnc_site_at) get "pos", _zk, false] call fnc_opcom_recruit
};

// Unhires a unit raised for an order that never went, so a refused execute leaves no unpaid unit standing.
DUWS_fnc_opcom_dismiss = {
    params ["_ref", "_t"];
    if ((_ref select 0) isNotEqualTo "hire") exitWith {};
    DUWS_opcom_taskings = DUWS_opcom_taskings - [_t];
    [_t get "homeZone"] call DUWS_fnc_opcom_zoneReserveSync;
};
