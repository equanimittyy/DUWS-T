// Locality: server, [] call'd at load. The zones and towns the actions read: which zones OPCOM holds open, and a
// site's name and position.
if (!isServer) exitWith {};

DUWS_fnc_opcom_zoneLabel = {
    params ["_zk"];
    private _i = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
    if (_i < 0) exitWith { _zk };
    (zone_namePOS_pairs select _i) select 0
};

DUWS_fnc_opcom_zonesOpenSweep = {
    private _out = [];
    {
        _x params ["", "_zp", "_zs"];
        private _zk = [_zp] call fnc_zone_key;
        if (!([_zk] call fnc_zone_bluforHeld) && {!([_zk] call DUWS_fnc_opcom_siteContested)}) then {
            _out pushBack [_zk, _zs, _zp, _x select 3, [_zp] call DUWS_fnc_opcom_exposure, [_zk] call fnc_zone_tier];
        };
    } forEach zone_meta_array;
    _out
};

DUWS_fnc_opcom_zonesOpen = { ["zonesOpen", DUWS_fnc_opcom_zonesOpenSweep] call DUWS_fnc_opcom_tickCached };

DUWS_fnc_opcom_townLabel = {
    params ["_i"];
    text ((missionNamespace getVariable ["civ_locations", []]) select _i)
};

DUWS_fnc_opcom_townPos = {
    params ["_i"];
    ([[_i] call fnc_town_site_key] call fnc_site_at) getOrDefault ["pos", []]
};
