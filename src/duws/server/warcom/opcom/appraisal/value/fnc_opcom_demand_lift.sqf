// Locality: server, [] call'd at load. What a lift hire is worth: the order stranded at a water leg, or the march a
// hull would cut short (opcom_plan.md §Value). No P(win) on a lift: it fights nothing, and the rider's committed Value
// already carries the odds. Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// -> [[row, moveType, price], ...]: the rows OPCOM can hire now to lift a unit over ground or through the air.
DUWS_fnc_opcom_liftRowsSweep = {
    private _out = [];
    {
        private _row = _x;
        _y params ["_comp", "_flags"];
        private _mt = [_comp] call DUWS_fnc_opcom_moveType;
        private _price = OPCOM_AP_UNIT getOrDefault [_row, -1];
        if ("transport" in _flags && {_mt in ["wheeled", "tracked", "rotary"]} && {_price >= 0}
            && {(_comp findIf { ([_x, "OPF"] call DUWS_fnc_tokenClass) isEqualTo "" }) < 0}) then {
            _out pushBack [_row, _mt, _price];
        };
    } forEach DUWS_opcom_recruitMenu;
    _out
};

DUWS_fnc_opcom_liftRows = { ["liftRows", DUWS_fnc_opcom_liftRowsSweep] call DUWS_fnc_opcom_tickCached };

// Stopped at a water leg with no lift free: the whole order waits on a crossing.
DUWS_fnc_opcom_demandStrand = {
    params ["_flags", "", "_moveType"];
    if (!("transport" in _flags) || {!(_moveType in ["boat", "rotary"])}) exitWith { [0, []] };
    private _best = 0;
    private _at = [];
    {
        private _v = _x getOrDefault ["expValue", 0];
        if ((_x getOrDefault ["strandTicks", 0]) > 0 && {_v > _best}) then { _best = _v; _at = _x get "pos" };
    } forEach DUWS_opcom_taskings;
    [_best, _at]
};

// Land-taxi binds only at commit, so a unit already marching can never ride: the lift is priced on the orders the pick
// may send, less what the best hull on hand already saves them.
DUWS_fnc_opcom_demandTaxi = {
    params ["_flags", "", "_moveType", "_zones", "_row"];
    if (!("transport" in _flags) || {!(_moveType in ["wheeled", "tracked", "rotary"])}) exitWith { [0, []] };
    private _price = OPCOM_AP_UNIT getOrDefault [_row, 0];
    private _rivals = (call DUWS_fnc_opcom_liftRows) select { (_x select 0) isNotEqualTo _row };
    private _best = 0;
    private _at = [];
    {
        _x params ["_r", "_to", "_v"];
        private _rp = _r get "pos";
        private _z = [_rp, _zones] call DUWS_fnc_opcom_nearestOpen;
        if ("transportable" in (_r get "flags") && {_z isNotEqualTo []}) then {
            private _rm = _r get "moveType";
            private _zp = _z select 2;
            private _s = [_v, _rp, _rm, _to, _zp, _moveType] call DUWS_fnc_opcom_taxiSaving;
            // The lift rows compete on lift less price, so a dear fast hull takes only the long rides its time saving
            // pays for; on score alone the cheapest hull would win every ride. A rival the wallet cannot pay beats no
            // one, so a ride it wins still offers a cheaper hull the commander can afford.
            private _beaten = (_rivals findIf {
                _x params ["", "_mt", "_p"];
                _p <= WARCOM_opfor_ap
                && {(([_v, _rp, _rm, _to, _zp, _mt] call DUWS_fnc_opcom_taxiSaving) - _p) > (_s - _price)}
            }) >= 0;
            if (!_beaten) then {
                private _have = 0;
                {
                    _have = _have max ([_v, _rp, _rm, _to, _x get "pos", _x get "moveType"] call DUWS_fnc_opcom_taxiSaving);
                } forEach ([_r get "id"] call DUWS_fnc_opcom_taxiPool);
                if ((_s - _have) > _best) then { _best = _s - _have; _at = _rp };
            };
        };
    } forEach (call DUWS_fnc_opcom_pendingRiders);
    [_best, _at]
};
