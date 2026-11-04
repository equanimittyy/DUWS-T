// Locality: server, [] call'd at load. A commander's side inputs, read off its record (_cmd): the enemy's ground, and
// the wallet, which a commander without one reads as empty and never pays from.
if (!isServer) exitWith {};

DUWS_fnc_opcom_enemyZones = { missionNamespace getVariable [_cmd get "enemyZones", []] };

// By key, since a held position may have round-tripped through a string.
DUWS_fnc_opcom_enemyHeld = {
    params ["_zoneKey"];
    ((call DUWS_fnc_opcom_enemyZones) findIf { ([_x] call fnc_zone_key) isEqualTo _zoneKey }) >= 0
};

DUWS_fnc_opcom_funds = { [0, WARCOM_opfor_ap] select (_cmd get "wallet") };

DUWS_fnc_opcom_pay = {
    params ["_ap", "_why"];
    if (_cmd get "wallet") then { ["OPF", _ap, _why] call fnc_ap_adjust };
};
