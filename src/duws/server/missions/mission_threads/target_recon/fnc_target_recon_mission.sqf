// Locality: server -- callers remoteExec to target 2.
// Kill the recon patrol. A single OPFOR special-forces recon team on a close patrol of a treeline is
// the whole objective -- no garrison, no support -- so the win is unambiguous. Borrows the sniper
// hunt's shape (fnc_mission_run, all-dead predicate) but sites its target in cover instead of on an
// overwatch, and seeds the ground rather than the perch.
//
// A third of the time an OPFOR anti-personnel minefield is laid on the ring edge opposite the patrol
// (so its mines never spawn on the team) as a wall across the approach -- its length runs perpendicular
// to the line to the centre. It is skipped where another minefield already sits within 1 km, where a
// road runs within 100 m, or on water; and it is left unmanaged, so it outlives the mission as a
// lasting hazard rather than being torn down with the objective.
params ["_MissionPos", "_mission_name"];

// Minefield knobs. Length is the belt's frontage across the approach; a longer belt is more columns,
// derived from the length so the metres stay real whatever the spacing. Depth is fixed shallow: a belt
// across an approach is wide and a few rows deep, not a square, and it keeps the mine count sane.
#define RECON_MINE_CHANCE  0.33
#define RECON_MINE_LENGTH  50     // metres of frontage, laid perpendicular to the line to the zone centre
#define RECON_MINE_SPACING 2.5    // metres between mines; an AP field sows this tight
#define RECON_MINE_DEPTH   3      // rows deep

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // Site the patrol in the deepest cover the ring offers: sample bearings across the ring and keep
    // the spot with the most trees and bushes around it, so the team opens in a treeline rather than
    // on open ground. Terrain-object count, engine-cheap; the centre is the fallback for a bare ring.
    private _treeKinds = ["TREE", "SMALL TREE", "BUSH"];
    private _spawnPos = _targetpos;
    private _bestTrees = -1;
    for "_i" from 0 to 39 do {
        private _cand = _targetpos getPos [80 + random (_radius - 80), random 360];
        if (surfaceIsWater _cand) then { continue };
        private _n = count (nearestTerrainObjects [_cand, _treeKinds, 25, false]);
        if (_n > _bestTrees) then { _bestTrees = _n; _spawnPos = _cand };
    };

    // One special-forces recon team, close-patrolling its own patch of the treeline. Centre and leash
    // are the spawn, not the whole objective ring, so the team holds the wood it hides in instead of
    // wandering the marker; the 300 m passed here is the posture radius, not the mission radius.
    private _grp = ["recon", _spawnPos, 300, "closepatrol", _spawnPos] call fnc_spawn_team;
    [_grp] call fnc_mission_claim;

    // Anti-personnel minefield opposite the patrol, a third of the time: a wall across the approach at
    // the far ring edge, depth toward the centre so its length lies perpendicular to that radial. Sited
    // opposite the team so no mine spawns on top of it. Skipped where another minefield already sits
    // within 1 km, where a road runs within 100 m (an AP field is not a roadblock), or on water. No
    // key -> unmanaged, so it persists past the mission rather than being swept with the objective.
    if (random 1 < RECON_MINE_CHANCE) then {
        private _fieldPos = _targetpos getPos [_radius * 0.85, (_targetpos getDir _spawnPos) + 180];
        private _clash = DUWS_hardpoints findIf {
            (_x select 2) isEqualTo "MINEFIELD" && {(_x select 1) distance2D _fieldPos < 1000}
        };
        if (_clash < 0 && {!surfaceIsWater _fieldPos} && {(_fieldPos nearRoads 100) isEqualTo []}) then {
            private _cols = 2 max round (RECON_MINE_LENGTH / RECON_MINE_SPACING);
            [_fieldPos, _fieldPos getDir _targetpos, "AP", _cols, RECON_MINE_DEPTH, RECON_MINE_SPACING, -1, ""]
                call fnc_hardpoint_minefield;
        };
    };

    units _grp
};

private _spec = [
    17, 600, "kill", "STR_DUWS_T_RECON_PATROL_DESC", "STR_DUWS_T_c17", "reconpatrol",
    _build,
    { (_this findIf { alive _x }) < 0 },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolletsdothis", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolend"],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolfail"]
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
