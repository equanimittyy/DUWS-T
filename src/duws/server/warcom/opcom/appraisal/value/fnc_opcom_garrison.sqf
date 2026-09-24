// Locality: server, [] call'd at load. A Garrison's Value: the defense a unit adds at the zone it rests in, or for a
// worn unit the rebuy its heal recovers (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing may
// suspend.
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

DUWS_fnc_opcom_garrisonDefense = {
    params ["_worth", "_exposure", "_force", "_zoneForce"];
    _worth * _exposure * _force / ((_zoneForce + _force) max 1)
};

// The larger of the two, never the sum: the unit serves one role at a time. Healing recovers the AP a rebuy would
// cost, so the Value climbs with wear while Cost, priced on the force left, falls.
DUWS_fnc_opcom_garrisonValue = {
    params ["_full", "_eff", "_worth", "_exposure", "_zoneForce"];
    private _heal = (_full - _eff) * OPCOM_AP_PER_FORCE;
    _heal max ([_worth, _exposure, _eff, _zoneForce] call DUWS_fnc_opcom_garrisonDefense)
};
