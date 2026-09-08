// Site-finder for the raid-safehouse mission: accepts a town candidate only where a cluster of at least
// MIN_BUILDINGS door-having, enterable houses sits within reach, and returns it. The raid hides its cache
// among decoys, so it needs a real block to hunt through, not a lone house.
//
// Runs client-side in the picker (client/missions/fnc_stratmap.sqf), where the server-only
// fnc_usableBuildings is unavailable -- so it re-implements that building test as a pure engine query.
// The door check is load-bearing: the raid locks every candidate and the player breaches by shooting a
// door, so a doorless house cannot play.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.
params ["_pos"];

// TUNABLE. Sweep the whole town -- its own radius, floored so a tight hamlet still spans a fair block.
// Must match the thread's radius so finder and thread see the same cluster.
#define MIN_RADIUS 350
// Floor 3 candidates stay uncleared, so the crowd can only ever rule out (count - 2) decoys; below ~5 the
// asking barely narrows anything, so gate the offer on a cluster wide enough to make the deduction matter.
#define MIN_BUILDINGS 5

// Radius from the town this candidate sits in: duws_town_circles is the client-safe broadcast of the
// server-only civ_locations/civ_radii (fnc_civ_init_Tomata), so it is readable inside the picker.
// Nearest circle wins; no towns (civilians off) leaves the MIN_RADIUS floor.
private _townRad = 0;
private _bestD = 1e9;
{
    _x params ["_c", "_r"];
    private _d = _c distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _townRad = _r };
} forEach (missionNamespace getVariable ["duws_town_circles", []]);
private _radius = MIN_RADIUS max _townRad;

private _bldgs = nearestTerrainObjects [_pos, ["House"], _radius, true];
private _pos3 = _bldgs select { !(((_x buildingPos 3) select 0) == 0) };
private _usable = _pos3 select {
    isClass (configFile >> "CfgVehicles" >> typeOf _x >> "AnimationSources" >> "Door_1_rot")
};

["DEBUG", "MISSION", format ["safehouse finder: r=%1 house=%2 pos3=%3 door=%4 need=%5",
    round _radius, count _bldgs, count _pos3, count _usable, MIN_BUILDINGS]] call fnc_log;
// Door-source discovery: dump the object's real animation sources (animationNames is engine-side, so it
// resolves the model + inheritance where the CfgVehicles path missed). Names door detection/lock/breach.
{
    ["DEBUG", "MISSION", format ["safehouse probe: cls=%1 anims=%2", typeOf _x, animationNames _x]] call fnc_log;
} forEach (_pos3 select [0, 3 min count _pos3]);

if ((count _usable) < MIN_BUILDINGS) exitWith { [] };

[_pos]
