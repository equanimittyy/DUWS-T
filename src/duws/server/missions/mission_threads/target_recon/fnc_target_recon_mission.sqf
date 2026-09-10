// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

// Minefield knobs. Depth is fixed shallow: a belt across an approach is wide and a few rows deep, not a
// square, which also keeps the mine count sane.
#define RECON_MINE_CHANCE  0.33
#define RECON_MINE_LENGTH  50     // metres of frontage, laid perpendicular to the line to the zone centre
#define RECON_MINE_SPACING 2.5    // metres between mines; an AP field sows this tight
#define RECON_MINE_DEPTH   3      // rows deep

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // Site the patrol in the deepest cover: sample bearings across the ring, keep the most-treed spot
    // (terrain-object count, engine-cheap); centre is the fallback for a bare ring.
    private _treeKinds = ["TREE", "SMALL TREE", "BUSH"];
    private _spawnPos = _targetpos;
    private _bestTrees = -1;
    for "_i" from 0 to 39 do {
        private _cand = _targetpos getPos [80 + random (_radius - 80), random 360];
        if (surfaceIsWater _cand) then { continue };
        private _n = count (nearestTerrainObjects [_cand, _treeKinds, 25, false]);
        if (_n > _bestTrees) then { _bestTrees = _n; _spawnPos = _cand };
    };

    // Centre and leash are the spawn, not the objective ring, so the team holds the wood it hides in;
    // the 300 m here is the posture radius, not the mission radius.
    private _grp = ["recon", _spawnPos, 300, "closepatrol", _spawnPos] call fnc_spawn_team;
    [_grp] call fnc_mission_claim;

    // Sub-skills forced to 1 so the team spots and shoots at the engine's ceiling, whatever opfor_ai_skill
    // is. The closepatrol waypoints apply_posture laid are SAFE, so override those to STEALTH too, or the
    // first leg walks the team back out of it. The engine still promotes to COMBAT on detecting the player.
    {
        _x setSkill ["aimingAccuracy", 1];
        _x setSkill ["aimingShake", 1];
        _x setSkill ["aimingSpeed", 1];
        _x setSkill ["spotDistance", 1];
        _x setSkill ["spotTime", 1];
        _x setSkill ["general", 1];
    } forEach units _grp;
    _grp setBehaviour "STEALTH";
    { _x setWaypointBehaviour "STEALTH" } forEach (waypoints _grp);

    // AP minefield opposite the patrol (so no mine spawns on the team), a third of the time: a wall at
    // the far ring edge. Skipped near another minefield (<1 km), a road (<100 m), or water. No key, so
    // it is unmanaged and persists past the mission rather than swept with the objective.
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

private _done = { (_this findIf { alive _x }) < 0 };

if (!([17, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 600;
private _site = [_MissionPos, _radius, 17, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["reconpatrol%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_RECON_PATROL_DESC", _mission_name, "kill",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolletsdothis", 8], ["STR_DUWS_T_actionteam", "STR_DUWS_T_reconpatrolcopy", 0]]
] call fnc_mission_present;

[_handles, _done, _mission_name, _taskId, _targetpos, _radius, [_marker],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolend"]] call fnc_mission_watch;
