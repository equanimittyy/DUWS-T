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
    private _capped = (["unitCount", DUWS_fnc_opcom_unitCount] call DUWS_fnc_opcom_tickCached) >= OPCOM_CAP_UNITS_PER_ZONE * count zone_meta_array;
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

// -> [source, Value, P(win), Cost, price] for _src sent at _to, the row every source is ranked on. _value is what it
// returns at _to before the delay; _price and _cost are the action's own, to which the source adds its own. Distance is
// scored and never charged, which is what lets a near hire beat a far free unit. _base is force already bound to the
// fight (DUWS_fnc_opcom_pWinSend).
DUWS_fnc_opcom_sourceRow = {
    params ["_src", "_value", "_to", "_fight", ["_price", 0], ["_cost", 0], ["_base", 0]];
    _src params ["_ref", "_from", "_force", "_mt", "", "_sp", "_stake", "_mix"];
    private _pw = 1;
    if (_fight) then {
        _pw = if ((_ref select 0) isEqualTo "hire") then {
            [_to, _force + _base] call DUWS_fnc_opcom_pWinWith
        } else {
            [_to, _from, _force, _base] call DUWS_fnc_opcom_pWinSend
        };
    };
    private _d = _from distance2D _to;
    [_src, _value * _mix * ([_d, _mt] call DUWS_fnc_opcom_moveDelay), _pw, _cost + _stake + OPCOM_AP_PER_KM * _d / 1000, _price + _sp]
};

// -> [[source, Value, P(win), Cost, price], ...]: the best of _offers sent at _to, and beside it a dearer one that
// outscores it, so the pick can bank toward what the wallet cannot pay yet. _offers pairs each source with its Value;
// the rest are DUWS_fnc_opcom_sourceRow's. A fight drops a source under _floor.
DUWS_fnc_opcom_bestSources = {
    params ["_offers", "_to", "_fight", ["_price", 0], ["_cost", 0], ["_floor", OPCOM_PWIN_FLOOR], ["_base", 0]];
    private _best = [];
    private _bs = -1;
    private _paid = [];
    private _ps = -1;
    {
        private _row = [_x select 0, _x select 1, _to, _fight, _price, _cost, _base] call DUWS_fnc_opcom_sourceRow;
        _row params ["", "_v", "_pw", "_c", "_p"];
        if (_pw >= _floor) then {
            private _s = [_v, _pw, _c] call DUWS_fnc_opcom_score;
            if (_s > _bs) then { _bs = _s; _best = _row };
            if (_p <= WARCOM_opfor_ap && {_s > _ps}) then { _ps = _s; _paid = _row };
        };
    } forEach _offers;
    if (_best isEqualTo []) exitWith { [] };
    if (_paid isEqualTo [] || {_ps >= _bs}) exitWith { [_best] };
    [_paid, _best]
};

// -> [members, price, Value, P(win), Cost, names]: the units one pick sends into an attack, [] when they fall under
// _floor. No-retreat punishes a muster that trickles in, so sources join best score first, a hire again for as long as
// the wallet and the unit cap allow, until the bound force meets the ideal bar or the attack holds
// OPCOM_ATTACK_UNITS. A member is [unit target, bucket, price], staged at the bucket DUWS_fnc_opcom_joinBucket would
// name. A free unit serves once, as a member or as another's lift. The Value is the weakest member's, since the attack
// goes only once its last unit is in. With nothing affordable the best source goes alone, so the pick can save for it.
// _buckets: [[rally, required, force, units, lambda], ...] as they stand (DUWS_fnc_opcom_attackBuckets). _vehicles: the
// vehicles the attack already binds, which sets each further vehicle's OPCOM_ATTACK_VEHICLE_BOOST; -1 boosts none.
DUWS_fnc_opcom_attackPackage = {
    params ["_offers", "_to", "_at", "_value", "_floor", "_buckets", "_base", "_label", ["_vehicles", -1]];
    _buckets = +_buckets;
    private _rows = _offers apply { [_x, _value, _to, true, 0, 0, _base] call DUWS_fnc_opcom_sourceRow };
    // Infantry and vehicles ranked apart: the boost scales every vehicle's score alike, so only the two heads need
    // comparing again after each vehicle taken.
    private _ranks = [[], []];
    {
        (_ranks select !(((_x select 0) select 3) isEqualTo "inf")) pushBack
            [[_x select 1, _x select 2, _x select 3] call DUWS_fnc_opcom_score, _forEachIndex];
    } forEach _rows;
    { _x sort false } forEach _ranks;
    private _k = [0, 0];
    private _fnc_boost = { if (_vehicles < 0) then { 1 } else { OPCOM_ATTACK_VEHICLE_BOOST param [_vehicles, 1] } };
    // -> the rank the next source comes off, 0 infantry or 1 vehicle; -1 once both are spent.
    private _fnc_next = {
        private _s = [0, 1] apply { ((_ranks select _x) param [_k select _x, [-1]]) select 0 };
        if ((_s select 0) < 0 && {(_s select 1) < 0}) exitWith { -1 };
        [0, 1] select ((_s select 1) * (call _fnc_boost) > (_s select 0))
    };
    private _fnc_row = {
        params ["_i"];
        private _row = _rows select (((_ranks select _i) select (_k select _i)) select 1);
        if (_i == 0) exitWith { _row };
        _row = +_row;
        _row set [1, (_row select 1) * (call _fnc_boost)];
        _row
    };
    private _ene = ([_at] call DUWS_fnc_opcom_blockForce) select 1;
    private _gain = call DUWS_fnc_opcom_blockGain;
    private _hires = OPCOM_CAP_UNITS_PER_ZONE * count zone_meta_array - (["unitCount", DUWS_fnc_opcom_unitCount] call DUWS_fnc_opcom_tickCached);
    private _room = OPCOM_ATTACK_UNITS;
    { _room = _room - (_x select 3) } forEach _buckets;
    private _members = [];
    private _names = [];
    private _used = [];
    private _price = 0;
    private _cost = 0;
    private _v = 1e12;
    private _force = _base;
    private _add = _base;
    private _fnc_bucket = {
        private _b = _buckets findIf { (_x select 1) && {(_x select 3) == 0} };
        if (_b >= 0) exitWith { _b };
        private _least = [];
        { _least pushBack [_x select 2, _forEachIndex] } forEach _buckets;
        _least sort true;
        (_least select 0) select 1
    };
    // A lift another member already takes is dropped, so the unit walks.
    private _fnc_member = {
        params ["_row", "_b", "_wallet"];
        (_buckets select _b) params ["_rally", "", "", "", "_lambda"];
        private _task = [["move", _rally, "", [], _lambda], []] select (_rally isEqualTo []);
        private _c = [_row, [_rally, _at] select (_rally isEqualTo []), _task, _label, _wallet] call DUWS_fnc_opcom_liftOffer;
        if ((((_c select 0) select 3) param [0, []]) in _used) then {
            _row params ["_src", "_rv", "_rpw", "_rc", "_rp"];
            _c = [[_src select 0, _task, _rpw * _rv, []], _rp, "", _rv, _rpw, _rc];
        };
        _c
    };
    private _fnc_take = {
        params ["_src", "_b", "_c"];
        private _ref = _src select 0;
        private _hire = (_ref select 0) isEqualTo "hire";
        // Copied: a hire taken again shares its source's arrays.
        _members pushBack [+(_c select 0), _b, _c select 1];
        _names pushBack ([_ref] call DUWS_fnc_opcom_sourceName);
        _price = _price + (_c select 1);
        _cost = _cost + (_c select 5);
        _v = _v min (_c select 3);
        _force = _force + (_src select 2);
        // As DUWS_fnc_opcom_pWinSend: a free unit already inside the block is counted there by the grid.
        if (_hire || {([_to, _src select 1] call DUWS_fnc_opcom_cellDist) > 1}) then { _add = _add + (_src select 2) };
        private _bk = _buckets select _b;
        _bk set [2, (_bk select 2) + (_src select 2)];
        _bk set [3, (_bk select 3) + 1];
        _room = _room - 1;
        private _lift = ((_c select 0) select 3) param [0, []];
        if ((_lift param [0, ""]) isEqualTo "free") then { _used pushBack _lift };
        if (_hire) then { _hires = _hires - 1 } else { _used pushBack _ref };
        if (_vehicles >= 0 && {!((_src select 3) isEqualTo "inf")}) then { _vehicles = _vehicles + 1 };
    };
    private _i = call _fnc_next;
    while { _room > 0 && {_i >= 0} && {_force * _gain / (_ene + 1) < OPCOM_MUSTER_IDEAL} } do {
        private _row = [_i] call _fnc_row;
        private _src = _row select 0;
        private _hire = ((_src select 0) select 0) isEqualTo "hire";
        private _b = call _fnc_bucket;
        private _c = [_row, _b, WARCOM_opfor_ap - _price] call _fnc_member;
        if ((_hire && {_hires <= 0}) || {(_src select 0) in _used} || {(_price + (_c select 1)) > WARCOM_opfor_ap}) then {
            _k set [_i, (_k select _i) + 1];
        } else {
            [_src, _b, _c] call _fnc_take;
            if (!_hire) then { _k set [_i, (_k select _i) + 1] };
        };
        _i = call _fnc_next;
    };
    if (_members isEqualTo [] && {count _rows > 0}) then {
        _k = [0, 0];
        private _row = [call _fnc_next] call _fnc_row;
        private _b = call _fnc_bucket;
        [_row select 0, _b, [_row, _b, WARCOM_opfor_ap] call _fnc_member] call _fnc_take;
    };
    if (_members isEqualTo []) exitWith { [] };
    private _pw = [_to, _add] call DUWS_fnc_opcom_pWinWith;
    if (_pw < _floor) exitWith { [] };
    [_members, _price, _v, _pw, _cost, _names joinString ", "]
};

// -> the tasking _ref names, hired first when it is a hire; nil when the hire is refused. The candidate's price
// already carries a hire, so fnc_opcom_recruit charges nothing.
DUWS_fnc_opcom_raise = {
    params ["_ref"];
    _ref params ["_kind", "_a", ["_zk", ""]];
    if (_kind isEqualTo "free") exitWith { [_a] call DUWS_fnc_opcom_byId };
    [_a, ([_zk] call fnc_site_at) get "pos", _zk, false] call fnc_opcom_recruit
};

DUWS_fnc_opcom_sourceName = {
    params ["_ref"];
    _ref params ["_kind", "_a", ["_zk", ""]];
    if (_kind isEqualTo "free") exitWith { format ["%1 %2", ([_a] call DUWS_fnc_opcom_byId) get "menu", _a] };
    format ["new %1 at %2", _a, [_zk] call DUWS_fnc_opcom_zoneLabel]
};

// Unhires a unit raised for an order that never went, so a refused execute leaves no unpaid unit standing.
DUWS_fnc_opcom_dismiss = {
    params ["_ref", "_t"];
    if ((_ref select 0) isNotEqualTo "hire") exitWith {};
    DUWS_opcom_taskings = DUWS_opcom_taskings - [_t];
    [_t get "homeZone"] call DUWS_fnc_opcom_zoneReserveSync;
};
