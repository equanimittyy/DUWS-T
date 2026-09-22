// Locality: server, [] call'd at load. What a hire is worth: the action it unblocks, and the defense it adds at the
// zone that raises it (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
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

// -> [Value, the target's position], [0, []] with nothing blocked. Scored as if the hire already stood at that
// target, so OPCOM never hires for a fight it could not win.
DUWS_fnc_opcom_hireDemand = {
    params ["_flags", "_force", "_moveType", "_zones"];
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
    if (("transport" in _flags) && {_moveType in ["boat", "rotary"]}) then {
        {
            if ((_x getOrDefault ["strandTicks", 0]) > 0) then {
                private _v = _x getOrDefault ["expValue", 0];
                if (_v > _best) then { _best = _v; _at = _x get "pos" };
            };
        } forEach DUWS_opcom_taskings;
    };
    [_best, _at]
};
