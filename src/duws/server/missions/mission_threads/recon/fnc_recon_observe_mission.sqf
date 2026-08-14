// Locality: server -- callers remoteExec to target 2.
//
// Recon-observe. The player infils to a designated overwatch position, raises binoculars, and holds
// eyes-on an unrevealed OPFOR zone long enough to scout it; success lifts that zone's fog of war on the
// strategic map. The site-finder (fnc_recon_observe_site) returns the TARGET zone (a re-derivation the
// thread can make exact), and this thread computes the overwatch itself -- terrain and object
// line-of-sight, on the friendly-facing side, favouring height over the target.
//
// The observed force is spawned and streamed by THIS mission alone, never the global site poller: at an
// 800 m standoff the real zone garrison is asleep, and waking it would mean touching shared streaming
// and handing the player a live garrison that wanders off the spot it is meant to be scouted at. When a
// player reaches the overwatch the mission builds the zone's OWN prefab (crewed statics and all), plus a
// couple of representative infantry teams and one roving car -- stand-ins, not the real garrison. It is
// built a little off the zone centre so its zone_<x>_<y> key cannot collide with the real (stowed)
// zone's, and torn down through fnc_mission_end's composition release plus the claimed-unit sweep.
params ["_MissionPos", "_mission_name"];

// TUNABLE, all here. Standoff band (kept in step with the finder); observe area the player holds within;
// LOS range slack over the band; hold seconds; the ring a player must reach to raise the element; the
// representative teams, their patrol radius and the roving car's; the prefab offset off the zone centre
// and the radius its crewed gunners are claimed within.
#define OBS_MIN_DIST    600
#define OBS_MAX_DIST    800
#define OBS_AREA        75
#define OBS_RANGE       900
#define HOLD_TIME       12
#define SPAWN_R         200
#define GARRISON_TEAMS  2
#define GARRISON_RADIUS 100
#define PATROL_RADIUS   150
#define PREFAB_OFFSET   25
#define PREFAB_RADIUS   60

// Target: the finder returned the zone position as _MissionPos, so the nearest unrevealed OPFOR-held
// zone to it is that zone -- an exact re-derivation, not the ambiguous "nearest to an overwatch". If it
// was captured or revealed since the offer the next nearest resolves; none left aborts. The stored pos
// is kept, not a copy -- fnc_zone_reveal matches its target by str(pos).
private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _target = [];
private _bestD = 1e9;
{
    _x params ["", "_zp", "_revealed"];
    if (!_revealed && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
        private _d = _zp distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _target = _zp };
    };
} forEach _pairs;
if (_target isEqualTo []) exitWith {
    [17, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};

if (!([17, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;

// The overwatch. Sample bearings across the friendly-facing arc at 600-800 m and keep the one with
// clear line-of-sight to the target -- terrain (terrainIntersectASL) and structures
// (lineIntersectsSurfaces) both -- and the most height over it. The finder confirmed a terrain-clear
// bearing existed; if object occlusion has since closed every one, abort rather than site a blind spot.
private _tgtASL    = [_target select 0, _target select 1, (getTerrainHeightASL _target) + 5];
private _tgtGround = getTerrainHeightASL _target;
private _fAnchors = +(missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []]);
if (!(isNil "PosOfBLUHQ") && {!(PosOfBLUHQ isEqualTo [])}) then { _fAnchors pushBack PosOfBLUHQ };
if (!(isNil "Array_of_FOBpos")) then { { _fAnchors pushBack _x } forEach Array_of_FOBpos };
private _baseBearing = if (_fAnchors isEqualTo []) then { random 360 } else {
    private _near = _fAnchors select 0; private _nd = 1e9;
    { private _d = _x distance2D _target; if (_d < _nd) then { _nd = _d; _near = _x } } forEach _fAnchors;
    _target getDir _near
};
private _overwatch = [];
private _bestScore = -1e9;
for "_i" from 0 to 17 do {
    private _b = _baseBearing - 90 + (_i * (180 / 17));
    private _r = OBS_MIN_DIST + random (OBS_MAX_DIST - OBS_MIN_DIST);
    private _cand    = _target getPos [_r, _b];
    private _ground  = getTerrainHeightASL _cand;
    private _eyeASL  = [_cand select 0, _cand select 1, _ground + 1.5];
    if (!(terrainIntersectASL [_eyeASL, _tgtASL]) && {(lineIntersectsSurfaces [_eyeASL, _tgtASL]) isEqualTo []}) then {
        private _score = _ground - _tgtGround;   // prefer looking down onto the target
        if (_score > _bestScore) then { _bestScore = _score; _overwatch = _cand };
    };
};
if (_overwatch isEqualTo []) exitWith {
    [17, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};

// The prefab, built a step off the zone centre toward the overwatch. The offset keeps its zone_<x>_<y>
// key (fnc_zone_key rounds the position) distinct from the real zone's, so releasing the recon copy
// cannot retire the live zone; it also sits the structures nearer the player than the centre the
// overwatch was verified to, so LOS only improves. The anchor (3D marker + hold LOS) rides it.
private _prefabPos = _target getPos [PREFAB_OFFSET, _target getDir _overwatch];
private _prefabKey = [_prefabPos] call fnc_zone_key;
private _anchor = _prefabPos;

// The builder for the target zone's own kind. Only the kind's NAME is stored (DUWS_zoneKind_<key>), so
// map it back to a builder through the same weighted set the zone drew from; an unknown or missing kind
// falls to the simple-zone builder rather than nothing.
private _sets = call fnc_zone_prefab_set;
private _builder = (_sets select 1) select 2;
private _kind = missionNamespace getVariable [format ["DUWS_zoneKind_%1", [_target] call fnc_zone_key], ""];
{ if ((_x select 0) == _kind) exitWith { _builder = _x select 2 } } forEach (_sets select 0);

// Objective marker + task on the OVERWATCH, since that is where the player is sent. The task type only
// picks the map icon; "scout" falls back to default on any faction pack that lacks it.
private _radius = OBS_AREA;
private _markername = [_overwatch, _radius] call fnc_missionMarkerData;
private _taskID = format ["recon_%1", round time];
[_taskID, localize "STR_DUWS_T_RECON_OBSERVE_TASK", _mission_name, _overwatch, "scout"] call fnc_missionTaskCreate;

// Mission-owned observe state. DUWS_recon_active is the broadcast switch every client half gates on and
// the monitor clears at the end; DUWS_recon_done is the win flag the client success report raises.
DUWS_recon_done = false;
DUWS_recon_active = true;
publicVariable "DUWS_recon_active";

// Push the player-facing layer to every client, JIP-keyed so a mid-mission joiner gets it too. Cleared
// on end below, or the key would replay the layer at the next joiner after the mission is gone.
[_overwatch, _anchor, OBS_AREA, OBS_RANGE, HOLD_TIME] remoteExec ["fnc_recon_observe_layer", 0, "DUWS_recon_layer_jip"];

[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_RECON_OBSERVE_BRIEF"] remoteExec ["fnc_duws_dialogue", 0];

// The mission's own streamer: waits for a player to reach the overwatch ring, builds the element once
// and exits -- standoff scouting without the global poller. No teardown loop; everything it raises is
// claimed to the token or released by fnc_mission_end's compKey, so the mission's exit collects it.
// Building ~700 m from the target keeps the spawn off the player's magnified view.
[_target, _prefabPos, _builder, _overwatch] spawn {
    params ["_target", "_prefabPos", "_builder", "_overwatch"];
    waitUntil { sleep 3; !DUWS_recon_active || {(allPlayers findIf { alive _x && {(_x distance2D _overwatch) < SPAWN_R} }) >= 0} };
    if (!DUWS_recon_active) exitWith {};   // ended before anyone arrived; nothing built

    // The zone's own prefab -- structures and crewed statics -- filed under _prefabPos's key, which the
    // WIN/fail exit hands to fnc_mission_end to release.
    [_prefabPos] call _builder;

    // The builder crews its statics but leaves the gunners unowned, so claim the EAST men on the prefab
    // to the token -- the sweep then bins them with the composition instead of leaving live gunners on
    // deleted guns. The real zone is streamed out here, so only the recon's own gunners are in reach;
    // done before the teams spawn so this proximity pass catches only them.
    private _gunners = allUnits select { (side _x == EAST) && {isNil {_x getVariable "DUWS_missionOwner"}} && {(_x distance2D _prefabPos) < PREFAB_RADIUS} };
    [_gunners] call fnc_mission_claim;

    // Representative infantry -- a stand-in patrol pair, not the real garrison -- and one car, all on
    // close patrol around the position, all claimed for the sweep. YELLOW so they hold and fire rather
    // than abandon the position to chase an 800 m spotter, which would turn a scout into a firefight the
    // mission is not built around.
    for "_i" from 1 to GARRISON_TEAMS do {
        private _g = ["team", _prefabPos, GARRISON_RADIUS, "closepatrol"] call fnc_spawn_team;
        if (!isNull _g) then { _g setCombatMode "YELLOW"; [units _g] call fnc_mission_claim };
    };
    private _carClass = ["car"] call DUWS_fnc_tokenClass;
    if (_carClass != "") then {
        private _carGrp = [_carClass, _prefabPos, PATROL_RADIUS, "closepatrol"] call fnc_spawn_vehicle;
        if (!isNull _carGrp) then { _carGrp setCombatMode "YELLOW"; [units _carGrp] call fnc_mission_claim };
    };
};

// Win/fail monitor. The client raises DUWS_recon_done on a completed hold; the deadline fails it.
private _deadline = DUWS_curDeadlineAt;
private _outcome = "";
waitUntil {
    sleep 2;
    if (DUWS_recon_done) exitWith { _outcome = "WIN"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
    false
};

// Stand the client layer down before scoring, and release the streamer's approach-wait if nobody ever
// arrived: both gate on this flag. A cleared JIP key stops the layer reaching a later joiner. The
// element itself is torn down by fnc_mission_end below -- the prefab through its compKey, the claimed
// gunners, teams and car through the token sweep.
DUWS_recon_active = false;
publicVariable "DUWS_recon_active";
remoteExec ["", "DUWS_recon_layer_jip"];
[_markername] call fnc_missionMarkerClear;

if (_outcome isEqualTo "WIN") then {
    [_taskID, "SUCCEEDED"] call fnc_missionTaskEnd;
    // The payoff: the scouted zone comes up on the strategic map. Quiet reveal -- the line here is the
    // mission's own, not Overlord's AO-wide zone-spotted broadcast.
    ["ONE", _target, 0, true] call fnc_zone_reveal;
    [localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_RECON_OBSERVE_DONE"] remoteExec ["fnc_duws_dialogue", 0];
    [_overwatch, _radius, _prefabKey] call fnc_mission_end;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    [_taskID, "FAILED"] call fnc_missionTaskEnd;
    [localize "STR_DUWS_T_RECON_OBSERVE_FAILED", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    [_overwatch, _radius, _prefabKey] call fnc_mission_end;
};
