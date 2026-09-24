// Locality: server, [] call'd at load. A Re-garrison's Value: what sending a worn unit home to heal is worth.
// Read from the pick's unscheduled pass, so nothing may suspend.
if (!isServer) exitWith {};

// The larger of the two, never the sum: the unit serves one role at a time, as a combatant hire does. Healing
// recovers the AP a rebuy would cost, so the Value climbs with wear while Cost, priced on the force left, falls.
DUWS_fnc_opcom_regarrisonValue = {
    params ["_full", "_eff", "_worth", "_exposure", "_zoneForce"];
    private _heal = (_full - _eff) * OPCOM_AP_PER_FORCE;
    _heal max ([_worth, _exposure, _eff, _zoneForce] call DUWS_fnc_opcom_hireDefense)
};
