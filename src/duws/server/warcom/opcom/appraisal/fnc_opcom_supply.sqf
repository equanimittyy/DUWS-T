// Locality: server, [] call'd at load. Supply trucks: where one can be had, what it costs to a destination, and the run
// that sends it (opcom_plan.md §What AP buys).
if (!isServer) exitWith {};

// -> [[source ref, price, Value, Cost], ...]: the truck that best serves a delivery of _value to _dest, and a dearer one
// when it outscores that (DUWS_fnc_opcom_bestSources). _price is the goods', which every truck adds its own to.
DUWS_fnc_opcom_truckOffers = {
    params ["_dest", "_value", "_price"];
    private _free = ["freeTrucks", {
        ((call DUWS_fnc_opcom_free) select { "supply" in (_x get "flags") }) apply { [_x] call DUWS_fnc_opcom_freeSource }
    }] call DUWS_fnc_opcom_tickCached;
    private _hires = [{ params ["_flags"]; "supply" in _flags }, _dest, call DUWS_fnc_opcom_zonesOpen]
        call DUWS_fnc_opcom_hireSources;
    ([(_free + _hires) apply { [_x, _value] }, _dest, false, _price, _price] call DUWS_fnc_opcom_bestSources)
        apply { _x params ["_src", "_v", "", "_c", "_p"]; [_src select 0, _p, _v, _c] }
};

DUWS_fnc_opcom_supplyCount = {
    { (_x getOrDefault ["errand", []]) isNotEqualTo [] && {(_x get "status") isNotEqualTo "dead"} } count DUWS_opcom_taskings
};

DUWS_fnc_opcom_supplyClass = {
    params ["_kind", ["_type", ""]];
    OPCOM_SUPPLY_CLASS getOrDefault [_type, OPCOM_SUPPLY_CLASS getOrDefault [_kind, ""]]
};

// -> true if a truck may set off on a _kind errand carrying _type.
DUWS_fnc_opcom_supplyOpen = {
    params ["_kind", ["_type", ""]];
    private _class = [_kind, _type] call DUWS_fnc_opcom_supplyClass;
    DUWS_opcom_tick >= (DUWS_opcom_supplyReadyTick getOrDefault [_class, 0])
        && {(DUWS_opcom_taskings findIf {
            (_x getOrDefault ["errand", []]) params [["_k", ""], "", ["_spec", ""]];
            ([_k, _spec] call DUWS_fnc_opcom_supplyClass) isEqualTo _class && {(_x get "status") isNotEqualTo "dead"}
        }) < 0}
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
    private _t = [_src] call DUWS_fnc_opcom_raise;
    if (isNil "_t") exitWith { false };
    private _ok = [_t, "errand", _dest, "", _errand] call fnc_opcom_task;
    if (!_ok) exitWith { [_src, _t] call DUWS_fnc_opcom_dismiss; false };
    // Rolled at the order, not the delivery: killing a courier must not open the class to the next one at once.
    _errand params ["_kind", "", ["_spec", ""]];
    private _class = [_kind, _spec] call DUWS_fnc_opcom_supplyClass;
    OPCOM_SUPPLY_COOLDOWN params ["_min", "_max"];
    private _n = _min + floor random (_max - _min + 1);
    DUWS_opcom_supplyReadyTick set [_class, DUWS_opcom_tick + _n];
    ["INFO", "OPCOM", format ["supply: no %1 truck for %2 ticks", _class, _n]] call fnc_log;
    true
};
