// Site-finder for the raid-safehouse mission: snaps the candidate to the town it sits in and accepts only
// where that town holds a cluster of at least MIN_BUILDINGS door-having, enterable houses. Returns the
// town centre, so the raid sits on the town it works -- the crowd it questions and the reputation a wrong
// raid costs. The cache hides among decoys, so it needs a real block, not a lone house.
//
// Runs client-side in the picker (client/missions/fnc_stratmap.sqf), where the server-only
// fnc_usableBuildings is unavailable -- so it counts enterable buildings inline. The door check is
// load-bearing (the raid locks every candidate and the player breaches by shooting a door, so a doorless
// house cannot play) and runs through the broadcast fnc_house_doors, shared with the thread's gate.
//
// Contract: [_candidatePos] -> [] reject, or [_townCentre] accept.
params ["_pos"];

// TUNABLE. Search the town's own radius, floored so a tight hamlet still spans a fair block; gate on a
// cluster wide enough that ruling decoys out means something (the ask never clears below 3, so the crowd
// can strike at most count - 2). SNAP_RADIUS drops a candidate with no town within reach.
#define MIN_RADIUS 350
#define MIN_BUILDINGS 5
#define SNAP_RADIUS 2500

// Snap to the town the candidate sits in: its centre is the objective, its radius sizes the search.
// duws_town_circles is the client-safe broadcast of server-only civ_locations/civ_radii
// (fnc_civ_init_Tomata) and is index-aligned with it, so the thread resolves the same town.
private _townCentre = [];
private _townRad = 0;
private _bestD = 1e9;
{
    _x params ["_c", "_r"];
    private _d = _c distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _townCentre = _c; _townRad = _r };
} forEach (missionNamespace getVariable ["duws_town_circles", []]);
if (_townCentre isEqualTo [] || {_bestD > SNAP_RADIUS}) exitWith { [] };

private _radius = MIN_RADIUS max _townRad;
private _usable = (nearestTerrainObjects [_townCentre, ["House"], _radius, true]) select {
    !(((_x buildingPos 3) select 0) == 0) && {(count ([_x] call fnc_house_doors)) > 0}
};
if ((count _usable) < MIN_BUILDINGS) exitWith { [] };

[_townCentre]
