// Locality: server, [] call'd at load. A radio tower's Value: the town worth it newly covers, less the covered worth
// it overlaps, x defend (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_towerReach = {
    params ["_at", "_towns", "_others"];
    private _sum = 0;
    {
        _x params ["_pos", "_worth", "_covered"];
        if ((_pos distance2D _at) <= AOI_TOWER_REACH) then {
            _sum = _sum + _worth * ([1, -OPCOM_TOWER_OVERLAP] select (_covered
                || {(_others findIf { (_x distance2D _pos) <= AOI_TOWER_REACH }) >= 0}));
        };
    } forEach _towns;
    _sum max 0
};

// -> [pos, worth, covered] per town.
DUWS_fnc_opcom_towerTowns = {
    private _towns = [];
    {
        private _pos = [_forEachIndex] call DUWS_fnc_opcom_townPos;
        _towns pushBack [_pos, [_forEachIndex] call DUWS_fnc_opcom_townWorth, [_pos] call fnc_aoi_opfor_covers];
    } forEach (missionNamespace getVariable ["civ_town_rep", []]);
    _towns
};

DUWS_fnc_opcom_towerValue = {
    params ["_at"];
    ([_at, call DUWS_fnc_opcom_towerTowns, ["RADIO"] call DUWS_fnc_opcom_assetsOf] call DUWS_fnc_opcom_towerReach)
        * ([_at] call DUWS_fnc_opcom_defend)
};
