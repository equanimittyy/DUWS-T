// Locality: server -- run from a client, hideObjectGlobal hides on that machine alone.

params ["_pos", ["_radius", 35]];

// The engine answers damage to a hidden building with a fresh visible one, so without this register
// and handler a single blast re-pops the buildings through whatever was built on top.
if (isNil "DUWS_terrain_hidden") then {
    DUWS_terrain_hidden = [];
    addMissionEventHandler ["BuildingChanged", {
        params ["_old", "_new"];
        private _i = DUWS_terrain_hidden find _old;
        if (_i < 0) exitWith {};
        _new hideObjectGlobal true;
        DUWS_terrain_hidden set [_i, _new];
    }];
};

private _structures = nearestTerrainObjects [
    _pos,
    ["BUILDING", "HOUSE", "CHURCH", "CHAPEL", "RUIN", "WALL", "FENCE", "FUELSTATION", "VIEW-TOWER", "WATERTOWER", "BUNKER", "HIDE"],
    _radius,
    false
];
{
    _x hideObjectGlobal true;
    DUWS_terrain_hidden pushBackUnique _x;
} forEach _structures;

["INFO", "TERRAIN", format ["Cleared %1 structures within %2 m of %3", count _structures, _radius, _pos]] call fnc_log;
