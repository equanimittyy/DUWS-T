// Locality: server -- spawns OPFOR, so only the server may run it.
//
// Mans the guard towers, bunkers and cargo posts already standing on the ground around a zone. These
// are map objects rather than anything the mission places, so this finds what is there and puts men
// in it; a zone with none nearby raises nothing and that is the correct answer.
//
// usage: [_pos, _radius, _searchRadius, _strength] call fnc_garrisonTowers
//
// Returns a group per post rather than one group holding all of them: each post is pinned to its own
// building and a single group spread across a dozen towers would share one leader's orders.
//
// _strength takes towers off the list rather than men out of a tower, for the same reason the house
// pass holds fewer houses -- a tower with one man in it is a tower the player walks past.
params ["_pos", "_radius", ["_searchRadius", 300], ["_strength", 1]];

private _fortificationClasses = [
    "Land_GuardTower_02_F",
    "Land_Cargo_Tower_V2_F",
    "Land_Cargo_Patrol_V2_F",
    "Land_BagBunker_Tower_F",
    "Land_Bunker_01_tall_F"
];

private _found = [];
{ _found append (nearestObjects [_pos, [_x], _searchRadius]) } forEach _fortificationClasses;
private _posts = [];
{ _posts pushBackUnique _x } forEach _found;
if (_posts isEqualTo []) exitWith { [] };
_posts = [_posts, _strength] call fnc_zone_thin;

private _roles = [[
    opfor_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_GL_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_MARK_SOLDIER_X
]] call fnc_opforRoles;

private _groups = [];
{
    private _building = _x;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    if (count _positions == 0) then { continue };

    private _men = [];
    for "_j" from 1 to (2 + floor random 3) do { _men pushBack (selectRandom _roles) };
    private _group = [[0,0,0], EAST, _men, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;

    {
        private _bldPos = _building buildingPos (_forEachIndex % count _positions);
        _x setPosATL _bldPos;
        _x setUnitPos "UP";
        _x setBehaviour "AWARE";
        _x setCombatMode "RED";
        [_x, _building, [_bldPos], "PIN"] spawn fnc_holdBuildingPost;
        [_x] call fnc_addRandomLoot;
    } forEach units _group;

    [_group, "garrison"] call fnc_search_flag_group;
    _groups pushBack _group;
} forEach _posts;

["INFO", "ZONES", format ["manned %1 of %2 posts within %3 m of %4",
    count _groups, count _posts, _searchRadius, _pos]] call fnc_log;

_groups
