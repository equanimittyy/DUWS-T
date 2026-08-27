// Locality: server; the composition, spawns and monitor all run on the server. Callers remoteExec to 2.
//
// A cluster of 1-3 enemy recon camps spread across a 1 km zone, each hidden in treeline and betrayed by
// its campfire smoke. Each camp holds a close-patrol team (the objective) and seeds a roaming patrol that
// circuits between all the camps. Win when every camp team is dead; the roaming patrols are ambience, not
// part of the win. Each camp's table may hold 0-3 lootable intel items.

params ["_MissionPos", "_mission_name"];
if (!([18, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 1000;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_PATROLCAMP_BRIEF";

private _site = [_MissionPos, _radius, 18] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse spans the whole 1 km zone on purpose -- it names the
// area, not the camps; the campfire smoke is what the player homes in on for the final approach.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _taskId = format ["patrolcamp%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_taskId, localize "STR_DUWS_T_DESTROY_PATROL_CAMP_DESC", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;

[localize "STR_DUWS_T_c17", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

// Camp centres: 1-3, spread across the zone with a minimum separation so the smoke columns read as
// distinct objectives rather than one blob. The site-finder already placed the zone anchor in treeline;
// per-camp treeline biasing is left to a later pass -- for now they seat on any clear land in the ring.
private _campCount = 1 + floor random 3;
private _campCentres = [];
private _tries = 0;
while { count _campCentres < _campCount && _tries < 60 } do {
    _tries = _tries + 1;
    private _p = [_randomPos, 120, _radius - 120, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_p isEqualTo [] || {surfaceIsWater _p}) then { continue };
    if (_campCentres findIf { (_x distance2D _p) < 250 } >= 0) then { continue };
    _campCentres pushBack _p;
};
if (_campCentres isEqualTo []) then { _campCentres = [_targetpos]; };

private _campTeamUnits = [];
{
    private _campPos = _x;
    private _cx = _campPos select 0;
    private _cy = _campPos select 1;

    // A stub composition -- a burning campfire, three tents, a camping table -- laid out to be re-authored
    // in Eden. Rows are [class, offX, offY, offZ, dir, isWeapon], offsets from the camp centre; offZ unused
    // (props seat on terrain). Left simulated (no hardening): the campfire's fire and smoke are a particle
    // effect that enableSimulation false would suppress, and the smoke is the whole point of the beacon.
    // --DUWS-COMPOSITION BEGIN name="Mission: Patrol Camp" schema=A--
    private _staticsArray = [
        ["Land_Campfire_burning_F", 0,   0,    0, 0,   false],
        ["Land_TentDome_F",        -3,   2,    0, 45,  false],
        ["Land_TentDome_F",         3,   2,    0, -45, false],
        ["Land_TentDome_F",         0,  -3.5,  0, 180, false],
        ["Land_CampingTable_F",     1.5, 0.5,  0, 0,   false]
    ];
    // --DUWS-COMPOSITION END--
    private _props = [_staticsArray, [_cx, _cy], "mission_patrol_camp", [0, [], []]] call fnc_composition_place;

    // Intel on the table: three independent 1-in-3 rolls, so a camp holds 0-3 items. Seated like the laptop
    // objective (sabotage_laptop) -- freeze the table into a static, level surface and rest each item
    // base-flush on its measured top -- with one difference the loot requires: the item is left GLOBALLY
    // simulated, not frozen. A frozen ground holder cannot be looted; simulated (the state fnc_search_dropItems
    // leaves its drops in) it stays lootable and CP-bearing, and the frozen table under it is a solid surface
    // it settles onto rather than sliding off. Only the table is frozen; the campfire stays simulated so it
    // keeps burning. Items drawn from the shared document pool.
    private _tableIdx = _staticsArray findIf { (_x select 0) isEqualTo "Land_CampingTable_F" };
    private _table = if (_tableIdx >= 0) then { _props param [_tableIdx, objNull] } else { objNull };
    if (!isNull _table) then {
        // Settle onto terrain before freezing, as the laptop's tables settle onto the floor.
        sleep 1;
        _table setVectorUp [0, 0, 1];
        _table enableSimulationGlobal false;
        _table allowDamage false;
        private _tPos = getPosATL _table;
        private _topZ = (_tPos select 2) + (boundingBoxReal _table select 1 select 2);
        for "_i" from 0 to 2 do {
            if (random 1 < (1/3)) then {
                private _cls = DUWS_intelDocuments selectRandomWeighted DUWS_intelDocumentWeights;
                private _item = createVehicle [_cls, _tPos, [], 0, "CAN_COLLIDE"];
                private _base = (boundingBoxReal _item select 0) select 2;
                _item setPosATL [(_tPos select 0) + (0.25 * (_i - 1)), _tPos select 1, _topZ + 0.05 - _base];
                // Global, not local: the item must fall the last finger onto the table and be lootable on
                // every client, so the settle cannot be a server-only simulation the clients never see.
                _item enableSimulationGlobal true;
                [_item, "mission_patrol_camp"] call fnc_duws_keep;
            };
        };
    };

    // The camp's guard team: close patrol centred on this camp. This is the objective -- all camp teams
    // dead wins the mission.
    private _team = ["team", _campPos, 180, "closepatrol"] call fnc_spawn_team;
    if (!isNull _team) then {
        [_team] call fnc_mission_claim;
        _campTeamUnits append (units _team);
    };
} forEach _campCentres;

// No guard team stood up: with nothing to kill the win check would pass on the first poll. Tear the
// camp down and end rather than hand the player a mission that completes itself. fnc_mission_end sweeps
// the keyed composition and patrols; the task fails and no reward is paid.
if (_campTeamUnits isEqualTo []) exitWith {
    ["ERROR", "MISSION", "patrol camp: no camp team raised; ending without reward"] call fnc_log;
    [_markername2] call fnc_missionMarkerClear;
    [_taskId, "FAILED"] call fnc_missionTaskEnd;
    [_targetpos, _radius, "mission_patrol_camp"] call fnc_mission_end;
};

// One roaming patrol per camp, all walking the same circuit through every camp centre (hqpatrol anchors).
// fnc_spawn_team cannot thread the anchors, so raise each posture "none" at its camp, then order it here.
// Ambience: not claimed against the win, but claimed for cleanup so the sweep bins them with the camps.
{
    private _patrol = ["patrol", _x, _radius, "none", _x] call fnc_spawn_team;
    if (!isNull _patrol) then {
        [_patrol, "hqpatrol", _randomPos, _radius, _campCentres] call fnc_apply_posture;
        [_patrol] call fnc_mission_claim;
    };
} forEach _campCentres;

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_PATROLCAMP_COPY"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];

waitUntil {
    sleep 5;
    ({alive _x} count _campTeamUnits) == 0 || time > _deadline
};

if (time > _deadline && {({alive _x} count _campTeamUnits) > 0}) exitWith {
    [_taskId, _markername2, "mission_patrol_camp", _targetpos, _radius] call fnc_mission_deadline_fail;
};

[_markername2] call fnc_missionMarkerClear;
[_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos, _radius, "mission_patrol_camp"] call fnc_mission_end;
