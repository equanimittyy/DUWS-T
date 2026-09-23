// Locality: server, [] call'd at load. Supply trucks: where one can be had, what it costs to a destination, and the run
// that sends it (opcom_plan.md §What AP buys).
if (!isServer) exitWith {};

// -> [[source, pos, cost], ...]: an idle truck at 0, an open zone's hire at the hire price.
DUWS_fnc_opcom_truckSourcesSweep = {
    private _out = [];
    {
        if ("supply" in (_x get "flags") && {DUWS_opcom_tick >= (_x get "hold")} && {[_x] call DUWS_fnc_opcom_drawable}) then {
            _out pushBack [["truck", _x get "id"], _x get "pos", 0];
        };
    } forEach DUWS_opcom_taskings;
    private _comp = (DUWS_opcom_recruitMenu get "truck") select 0;
    private _hire = OPCOM_AP_UNIT getOrDefault ["truck", 0];
    // A zero price is an unpriced row, not a free truck; an empty class is a faction that cannot field one yet.
    if (_hire > 0 && {([_comp select 0, "OPF"] call DUWS_fnc_tokenClass) isNotEqualTo ""}) then {
        {
            _x params ["_zk"];
            _out pushBack [["hire", _zk], ([_zk] call fnc_site_at) get "pos", _hire];
        } forEach (call DUWS_fnc_opcom_zonesOpen);
    };
    _out
};

DUWS_fnc_opcom_truckSources = { ["truckSources", DUWS_fnc_opcom_truckSourcesSweep] call DUWS_fnc_opcom_tickCached };

// -> [source, cost, distance] for the cheapest truck to _dest, or [] with no source.
DUWS_fnc_opcom_truckFor = {
    params ["_sources", "_dest"];
    private _best = [];
    {
        _x params ["_src", "_pos", "_base"];
        private _d = _pos distance2D _dest;
        private _cost = _base + OPCOM_AP_PER_KM * _d / 1000;
        if (_best isEqualTo [] || {_cost < (_best select 1)}) then { _best = [_src, _cost, _d] };
    } forEach _sources;
    _best
};

DUWS_fnc_opcom_supplyFull = {
    ({ (_x getOrDefault ["errand", []]) isNotEqualTo [] && {(_x get "status") isNotEqualTo "dead"} } count DUWS_opcom_taskings)
        >= OPCOM_CAP_SUPPLY
};

// One supply truck per town at a time, so a second never lands a buy on a garrison the first already filled.
DUWS_fnc_opcom_townsSupplied = {
    private _busy = [];
    {
        (_x getOrDefault ["errand", []]) params [["_kind", ""], ["_town", -1]];
        if (_kind in ["reinforce", "fortify", "rapport"]) then { _busy pushBackUnique _town };
    } forEach DUWS_opcom_taskings;
    _busy
};

// -> true if the truck set off. A hire the router refuses is dismissed, so a refused action leaves no unpaid truck.
DUWS_fnc_opcom_supplyRun = {
    params ["_src", "_dest", "_errand"];
    _src params ["_kind", "_ref"];
    private _t = if (_kind isEqualTo "hire") then {
        ["truck", ([_ref] call fnc_site_at) get "pos", _ref, false] call fnc_opcom_recruit
    } else {
        [_ref] call DUWS_fnc_opcom_byId
    };
    if (isNil "_t") exitWith { false };
    private _ok = [_t, "move", _dest, "", _errand] call fnc_opcom_task;
    if (!_ok && {_kind isEqualTo "hire"}) then {
        DUWS_opcom_taskings = DUWS_opcom_taskings - [_t];
        [_ref] call DUWS_fnc_opcom_zoneReserveSync;
    };
    _ok
};
