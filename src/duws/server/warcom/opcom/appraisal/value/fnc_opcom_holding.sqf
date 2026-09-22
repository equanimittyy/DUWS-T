// Locality: server, [] call'd at load. A garrison buy's Value at a zone or town: worth x exposure x gain
// (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_townWorth = {
    params ["_i"];
    ((missionNamespace getVariable ["civ_town_ap", []]) param [_i, 0]) * OPCOM_TOWN_WORTH
};

DUWS_fnc_opcom_zoneWorthsSweep = {
    private _out = createHashMap;
    { _out set [[_x select 1] call fnc_zone_key, _x select 3] } forEach zone_meta_array;
    _out
};

DUWS_fnc_opcom_siteWorth = {
    params ["_key"];
    if ((_key select [0, 5]) isEqualTo "town_") exitWith { [parseNumber (_key select [5])] call DUWS_fnc_opcom_townWorth };
    (["zoneWorths", DUWS_fnc_opcom_zoneWorthsSweep] call DUWS_fnc_opcom_tickCached) getOrDefault [_key, 0]
};

// What the holding fields at its own current tier. Measured against the top tier instead, a small zone's refill
// read as a few percent of a zone it will never be, and every buy scored a fraction of what it was worth.
DUWS_opcom_tierForceMemo = createHashMap;

DUWS_fnc_opcom_tierForce = {
    params ["_kind", "_tier"];
    private _key = format ["%1_%2", _kind, _tier];
    private _f = DUWS_opcom_tierForceMemo getOrDefault [_key, -1];
    if (_f < 0) then {
        private _list = if (_kind isEqualTo "zone") then {
            private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
            [[_tier] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition
        } else {
            [_tier] call DUWS_fnc_townSpawnList
        };
        _f = ([_list] call DUWS_fnc_tokenListForce) max 1;
        DUWS_opcom_tierForceMemo set [_key, _f];
    };
    _f
};

// Exposure arrives measured: a holding's is the same for every action on it, so the sweep reads it once.
DUWS_fnc_opcom_holdValue = {
    params ["_worth", "_exposure", "_force", "_kind", "_tier"];
    _worth * _exposure * ((_force / ([_kind, _tier] call DUWS_fnc_opcom_tierForce)) min 1)
};
