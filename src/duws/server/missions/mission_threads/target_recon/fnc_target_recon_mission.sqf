// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

#define RECON_MINE_CHANCE  0.33

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    private _spawnPos = [_targetpos, _radius, [["forest", 1]]] call fnc_score_placement;

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

    // AP minefield opposite the patrol (so no mine spawns on the team), a third of the time, at
    // the far ring edge. Skipped near another minefield (<1 km), a road (<100 m), or water. No key, so
    // it is unmanaged and persists past the mission rather than swept with the objective.
    if (random 1 < RECON_MINE_CHANCE) then {
        private _fieldPos = _targetpos getPos [_radius * 0.85, (_targetpos getDir _spawnPos) + 180];
        private _clash = DUWS_hardpoints findIf {
            (_x select 2) isEqualTo "MINEFIELD" && {(_x select 1) distance2D _fieldPos < 1000}
        };
        if (_clash < 0 && {!surfaceIsWater _fieldPos} && {(_fieldPos nearRoads 100) isEqualTo []}) then {
            [_fieldPos, _fieldPos getDir _targetpos, "AP", ""] call fnc_hardpoint_minefield;
        };
    };

    units _grp
};

private _done = { (_this findIf { alive _x }) < 0 };

if (!([17, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 600;
// Trust the offer: the cover search anchors on the offered near-enemy dot.
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

private _taskId = format ["reconpatrol%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_RECON_PATROL_DESC", _mission_name, "kill",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolletsdothis", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_reconpatrolcopy", 0]]
] call fnc_mission_present;

[_handles, _done, _mission_name, _taskId, _targetpos, _radius, [_marker],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_reconpatrolend"]] call fnc_mission_watch;
