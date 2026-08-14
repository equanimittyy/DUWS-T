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
// and handing the player a live garrison that wanders off the spot it is meant to be scouted at. A
// small mission-owned element materialises when the player reaches the overwatch and stands down when
// they leave -- streaming that exists for this mission and nothing else.
params ["_MissionPos", "_mission_name"];

// TUNABLE, all here. Standoff band (kept in step with the finder); observe area the player holds within;
// LOS range slack over the band; hold seconds; the mission-owned stream ring and its empty grace; the
// garrison raised at the target.
#define OBS_MIN_DIST    600
#define OBS_MAX_DIST    800
#define OBS_AREA        75
#define OBS_RANGE       900
#define HOLD_TIME       12
#define SPAWN_R         200
#define DESPAWN_R       300
#define DESPAWN_GRACE   30
#define GARRISON_TEAMS  2
#define GARRISON_RADIUS 100
#define ANCHOR_CLASS    "Land_TentDome_F"

// Target: the finder handed back a zone position as _MissionPos, so the nearest unrevealed OPFOR-held
// zone to it is that zone (distance ~0) -- an exact re-derivation, not the ambiguous "nearest to an
// overwatch" the finder avoids. If it was captured or revealed between offer and launch the next
// nearest still resolves; with none left there is nothing to scout and the mission aborts. The exact
// stored position is kept, not a copy -- fnc_zone_reveal matches its target by str(pos), so the reveal
// below must hand back the same value the array holds.
private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _target = [];
private _targetName = "";
private _bestD = 1e9;
{
    _x params ["_zn", "_zp", "_revealed"];
    if (!_revealed && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
        private _d = _zp distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _target = _zp; _targetName = _zn };
    };
} forEach _pairs;
if (_target isEqualTo []) exitWith {
    [17, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};

if (!([17, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;

// The fixed thing the player glasses: a tent at the target centre, with a real faction element milling
// around it. The 3D marker rides this position (a vector), so it points true whether or not the element
// is streamed in at the moment.
private _anchor = _target;

// The overwatch the player is sent to. Sample bearings across the friendly-facing arc at 600-800 m and
// keep the one with clear line-of-sight to the target -- terrain (terrainIntersectASL, elevation) and
// structures (lineIntersectsSurfaces) both -- and the greatest height advantage over it. Aimed a little
// above the target's ground so the ray clears the lip of terrain it sits in. The finder confirmed a
// terrain-clear bearing existed at offer time; if object occlusion has since closed every one, abort
// rather than send the player to a spot they cannot scout from.
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

// Objective marker + task on the OVERWATCH, since that is where the player is sent. The task type only
// picks the map icon; "scout" falls back to default on any faction pack that lacks it.
private _radius = OBS_AREA;
private _markername = [_overwatch, _radius] call fnc_missionMarkerData;
private _taskID = format ["recon_%1", round time];
[_taskID, format [localize "STR_DUWS_T_RECON_OBSERVE_TASK", _targetName], _mission_name, _overwatch, "scout"] call fnc_missionTaskCreate;

// Mission-owned observe state. DUWS_recon_active is the broadcast switch every client half gates on and
// the monitor clears at the end; DUWS_recon_done is the win flag the client success report raises.
DUWS_recon_done = false;
DUWS_recon_active = true;
publicVariable "DUWS_recon_active";

// Push the player-facing layer to every client, JIP-keyed so a mid-mission joiner gets it too. Cleared
// on end below, or the key would replay the layer at the next joiner after the mission is gone.
[_overwatch, _anchor, OBS_AREA, OBS_RANGE, HOLD_TIME] remoteExec ["fnc_recon_observe_layer", 0, "DUWS_recon_layer_jip"];

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_RECON_OBSERVE_BRIEF", _targetName]] remoteExec ["fnc_duws_dialogue", 0];

// The mission's own streamer. Raises the observed element when a player reaches the overwatch ring and
// stands it down after they have been clear of it for the grace, so at standoff there is something to
// scout without the global poller ever being asked. Owns its spawns outright -- it does not claim them
// to the mission token, so the end sweep has nothing of its to race -- and deletes them on teardown when
// DUWS_recon_active drops.
private _streamer = [_anchor, _overwatch] spawn {
    params ["_anchor", "_overwatch"];
    private _up = false;
    private _units = [];
    private _tent = objNull;
    private _emptySince = -1;
    while { DUWS_recon_active } do {
        private _present = (allPlayers findIf { alive _x && {(_x distance2D _overwatch) < SPAWN_R} }) >= 0;

        if (_present && !_up) then {
            _tent = createVehicle [ANCHOR_CLASS, _anchor, [], 0, "CAN_COLLIDE"];
            for "_i" from 1 to GARRISON_TEAMS do {
                private _g = ["team", _anchor, GARRISON_RADIUS, "garrison"] call fnc_spawn_team;
                if (!isNull _g) then {
                    // Hold the base and fire from it, but do not abandon it to chase a spotter 800 m off
                    // -- that would turn a scout into a firefight the mission is not built around.
                    _g setCombatMode "YELLOW";
                    { _units pushBack _x } forEach (units _g);
                };
            };
            _up = true;
            _emptySince = -1;
        };

        if (_present) then { _emptySince = -1 };
        if (!_present && _up) then {
            private _far = (allPlayers findIf { alive _x && {(_x distance2D _overwatch) < DESPAWN_R} }) < 0;
            if (_far) then {
                if (_emptySince < 0) then { _emptySince = time };
                if (time - _emptySince > DESPAWN_GRACE) then {
                    { deleteVehicle _x } forEach _units; _units = [];
                    if (!isNull _tent) then { deleteVehicle _tent };
                    _up = false;
                };
            } else { _emptySince = -1 };
        };

        sleep 5;
    };
    { deleteVehicle _x } forEach _units;
    if (!isNull _tent) then { deleteVehicle _tent };
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

// Stand the client layer and the streamer down before scoring: the streamer loops on this flag, and a
// cleared JIP key stops the layer reaching a later joiner.
DUWS_recon_active = false;
publicVariable "DUWS_recon_active";
remoteExec ["", "DUWS_recon_layer_jip"];
[_markername] call fnc_missionMarkerClear;

if (_outcome isEqualTo "WIN") then {
    [_taskID, "SUCCEEDED"] call fnc_missionTaskEnd;
    // The payoff: the scouted zone comes up on the strategic map. Quiet reveal -- the line here is the
    // mission's own, not Overlord's AO-wide zone-spotted broadcast.
    ["ONE", _target, 0, true] call fnc_zone_reveal;
    [localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_RECON_OBSERVE_DONE", _targetName]] remoteExec ["fnc_duws_dialogue", 0];
    [_overwatch, _radius, ""] call fnc_mission_end;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    [_taskID, "FAILED"] call fnc_missionTaskEnd;
    [format [localize "STR_DUWS_T_RECON_OBSERVE_FAILED", _targetName], {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    [_overwatch, _radius, ""] call fnc_mission_end;
};
