// Locality: server, [] call'd at load. What a hire is worth: the action it unblocks, the lift or stock it gives, and
// the defense it adds at the zone that raises it (opcom_plan.md §Value). Read from the pick's unscheduled pass, so
// nothing here may suspend.
if (!isServer) exitWith {};

// A zone's garrison plus the combatants OPCOM has homed there, which the base ledger leaves out.
DUWS_fnc_opcom_zoneForcesSweep = {
    private _out = createHashMap;
    { _out set [_x select 0, [_x select 0] call DUWS_fnc_garrisonForce] } forEach (call DUWS_fnc_opcom_zonesOpen);
    {
        if ((_x get "order") isEqualTo "garrison" && {(_x get "status") isNotEqualTo "dead"}
            && {!("noncombat" in (_x get "flags"))}) then {
            private _hz = _x get "homeZone";
            private _cur = _out getOrDefault [_hz, -1];
            if (_cur >= 0) then { _out set [_hz, _cur + (_x get "effForce")] };
        };
    } forEach DUWS_opcom_taskings;
    _out
};

DUWS_fnc_opcom_zoneForce = {
    params ["_key"];
    (["zoneForces", DUWS_fnc_opcom_zoneForcesSweep] call DUWS_fnc_opcom_tickCached) getOrDefault [_key, 0]
};

DUWS_fnc_opcom_hireDefense = {
    params ["_worth", "_exposure", "_force", "_zoneForce"];
    _worth * _exposure * _force / ((_zoneForce + _force) max 1)
};

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

// -> [Value, the target's position], [0, []] when the hire serves nothing. Scored as if the hire already stood at that
// target, so OPCOM never hires for a fight it could not win.
DUWS_fnc_opcom_hireDemand = {
    params ["_flags", "_force", "_moveType", "_zones", "_row"];
    private _best = 0;
    private _at = [];
    private _weigh = {
        params ["_pos", "_v"];
        private _d = ([_pos, _force] call DUWS_fnc_opcom_pWinWith) * _v;
        if (_d > _best) then { _best = _d; _at = _pos };
    };
    if (!("noncombat" in _flags) && {!("recon" in _flags)}) then {
        // An Attack must stand in the zone to take it, so air fills no attacker's place.
        if (_moveType in ["inf", "wheeled", "tracked"]) then {
            { _x call _weigh } forEach (call DUWS_fnc_opcom_attackBlocked);
        };
        { _x call _weigh } forEach (call DUWS_fnc_opcom_interceptBlocked);
    };
    if ("recon" in _flags) then {
        private _k = OPCOM_RECON_K getOrDefault [_moveType, 1];
        {
            private _to = _x;
            private _z = [_to, _zones] call DUWS_fnc_opcom_nearestOpen;
            if (_z isNotEqualTo []) then { [_to, [_z select 2, _to, _k] call DUWS_fnc_opcom_scoutValue] call _weigh };
        } forEach (call DUWS_fnc_opcom_scoutBlocked);
    };
    // No P(win) on a lift: it fights nothing, and the rider's committed Value already carries the odds.
    if ("transport" in _flags) then {
        if (_moveType in ["boat", "rotary"]) then {
            {
                // Stopped at a water leg with no lift free: the whole order waits on a crossing.
                private _v = _x getOrDefault ["expValue", 0];
                if ((_x getOrDefault ["strandTicks", 0]) > 0 && {_v > _best}) then { _best = _v; _at = _x get "pos" };
            } forEach DUWS_opcom_taskings;
        };
        // Land-taxi binds only at commit, so a unit already marching can never ride: the lift is priced on the orders
        // the pick may send, less what the best hull on hand already saves them.
        if (_moveType in ["wheeled", "tracked", "rotary"]) then {
            private _price = OPCOM_AP_UNIT getOrDefault [_row, 0];
            private _rivals = (call DUWS_fnc_opcom_liftRows) select { (_x select 0) isNotEqualTo _row };
            {
                _x params ["_r", "_to", "_v"];
                private _rp = _r get "pos";
                private _z = [_rp, _zones] call DUWS_fnc_opcom_nearestOpen;
                if ("transportable" in (_r get "flags") && {_z isNotEqualTo []}) then {
                    private _rm = _r get "moveType";
                    private _zp = _z select 2;
                    private _s = [_v, _rp, _rm, _to, _zp, _moveType] call DUWS_fnc_opcom_taxiSaving;
                    // The lift rows compete on lift less price, so a dear fast hull takes only the long rides its
                    // time saving pays for; on score alone the cheapest hull would win every ride. A rival the wallet
                    // cannot pay beats no one, so a ride it wins still offers a cheaper hull the commander can afford.
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
        };
    };
    // An idle truck spares the next supply buy its hire. The saving splits across the trucks already idle, so the stock
    // settles where the hire's score meets Bank's; it rests at a random open zone, since that buy's target is unknown.
    if ("supply" in _flags) then {
        private _idle = { ((_x select 0) select 0) isEqualTo "truck" } count (call DUWS_fnc_opcom_truckSources);
        private _v = (OPCOM_AP_UNIT getOrDefault ["truck", 0]) / (_idle + 1);
        if (_v > _best) then { _best = _v; _at = (selectRandom _zones) select 2 };
    };
    [_best, _at]
};
