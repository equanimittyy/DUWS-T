// Locality: server -- callers remoteExec to target 2.
//
// Recon-observe. The player infils to a designated overwatch position, raises binoculars, and holds
// eyes-on an unrevealed OPFOR position -- a zone or a standalone hardpoint -- long enough to scout it;
// success lifts that position's fog of war on the strategic map. The site-finder (fnc_recon_observe_site)
// returns the TARGET position (a re-derivation the thread makes exact through the shared picker), and this
// thread computes the overwatch itself -- terrain and object line-of-sight, on the friendly-facing side,
// favouring height over the target.
//
// A zone and a hardpoint are observed differently, because their streaming ranges differ. A zone's
// garrison is asleep at the 600-800 m overwatch band (its stream ring is tighter), so waking it would mean
// touching shared streaming and handing the player a live garrison that wanders off the spot it is meant
// to be scouted at; instead the mission builds its OWN stand-in when a player reaches the overwatch -- the
// zone's prefab (crewed statics and all) plus a couple of representative infantry teams and one roving
// car, built a little off the centre so its zone_<x>_<y> key cannot collide with the real (stowed) zone's,
// and torn down through fnc_mission_end's composition release plus the claimed-unit sweep. A hardpoint's
// stream ring (800-1000 m) already covers that band, so approaching the overwatch wakes the REAL
// emplacement through its own streamer: the mission builds nothing for it, observes the real gun coming
// up, and reveals it on success.
params ["_MissionPos", "_mission_name"];

// TUNABLE, all here. Standoff band (kept with the finder); observe area; LOS range slack; hold seconds;
// approach ring; representative teams, their patrol radius and the car's; prefab offset and gunner-claim
// radius; the clearance the overwatch keeps from other enemy zones and hardpoints; and the most bonus
// positions a scout also reveals.
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
#define ZONE_CLEAR      250
#define HP_CLEAR        300
#define BONUS_MAX       2

// Target: the finder returned the target position as _MissionPos, so re-deriving the nearest unrevealed
// OPFOR position to it lands on that same target -- an exact re-derivation through the shared picker, not
// the ambiguous "nearest to an overwatch". The kind (a zone or a standalone hardpoint) rides the pick. If
// it was captured, cleared or revealed since the offer the next nearest resolves; none left aborts. A zone
// pos is kept, not a copy -- fnc_zone_reveal matches its target by str(pos); an HP reveals by its key.
private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _pick = [_MissionPos] call fnc_recon_observe_pick;
if (_pick isEqualTo []) exitWith {
    [17, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};
private _kind   = _pick select 0;
private _target = _pick select 1;
private _hpKey  = if (_kind isEqualTo "hp") then { _pick select 2 } else { "" };

if (!([17, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;

// The overwatch. Sample bearings across the friendly-facing arc at 600-800 m and keep the highest one
// with clear line-of-sight to the target -- terrain (terrainIntersectASL) and structures
// (lineIntersectsSurfaces) both -- that also stands clear of every OTHER enemy zone and hardpoint, so
// the player never observes from on top of one. Nothing left after that filter aborts the mission.
private _tgtASL    = [_target select 0, _target select 1, (getTerrainHeightASL _target) + 5];
private _tgtGround = getTerrainHeightASL _target;

// Enemy ground the overwatch must stand clear of: every OPFOR zone but the target (each by its own
// radius plus a margin), and every standing enemy hardpoint. The target is watched from the band, not
// avoided. DUWS_hardpoints rows are all opfor -- a captured or fallen one is deleted, not re-sided.
private _avoidZones = (missionNamespace getVariable ["zone_meta_array", []]) select {
    private _zp = _x select 1;
    (_zp distance2D _target > 1) && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}
};
// The target HP itself is watched, not avoided; _hpKey is "" for a zone target so none is dropped.
private _hps = (missionNamespace getVariable ["DUWS_hardpoints", []]) select { (_x select 0) != _hpKey };
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
    if (
        !(terrainIntersectASL [_eyeASL, _tgtASL])
        && {(lineIntersectsSurfaces [_eyeASL, _tgtASL]) isEqualTo []}
        && {[_eyeASL, _tgtASL] call fnc_recon_observe_foliageClear}
        && {(_avoidZones findIf { _cand distance2D (_x select 1) < ((_x select 2) + ZONE_CLEAR) }) < 0}
        && {(_hps findIf { _cand distance2D (_x select 1) < HP_CLEAR }) < 0}
    ) then {
        private _score = _ground - _tgtGround;   // prefer looking down onto the target
        if (_score > _bestScore) then { _bestScore = _score; _overwatch = _cand };
    };
};
if (_overwatch isEqualTo []) exitWith {
    [17, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};

// The anchor the 3D marker and the hold LOS ride. An HP is observed where it really stands. A zone's
// stand-in is built a step off the centre toward the overwatch, and the anchor rides that: the offset
// keeps its zone_<x>_<y> key (fnc_zone_key rounds the position) distinct from the real zone's, so
// releasing the recon copy cannot retire the live zone, and it sits the structures nearer the player than
// the centre the overwatch was verified to, so LOS only improves. An HP builds nothing, so it needs no
// prefab key and no builder.
private _anchor    = _target;
private _prefabPos = _target;
private _prefabKey = "";
private _builder   = {};
if (_kind isEqualTo "zone") then {
    _prefabPos = _target getPos [PREFAB_OFFSET, _target getDir _overwatch];
    _prefabKey = [_prefabPos] call fnc_zone_key;
    _anchor    = _prefabPos;
    // The builder for the zone's own kind. Only the kind's NAME is stored (DUWS_zoneKind_<key>), so map
    // it back through the same weighted set the zone drew from; an unknown or missing kind falls to the
    // simple-zone builder rather than nothing.
    private _sets = call fnc_zone_prefab_set;
    _builder = (_sets select 1) select 2;
    private _kindName = missionNamespace getVariable [format ["DUWS_zoneKind_%1", [_target] call fnc_zone_key], ""];
    { if ((_x select 0) == _kindName) exitWith { _builder = _x select 2 } } forEach (_sets select 0);
};

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

// A zone's own streamer: waits for a player to reach the overwatch ring, builds the stand-in once and
// exits -- standoff scouting without the global poller. No teardown loop; everything it raises is claimed
// to the token or released by fnc_mission_end's compKey, so the mission's exit collects it. Building
// ~700 m from the target keeps the spawn off the player's magnified view. An HP builds nothing here: its
// real emplacement wakes through its own site poller when the player reaches the overwatch (inside its
// stream ring), and doubling that garrison is exactly what must not happen.
if (_kind isEqualTo "zone") then {
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
    // The payoff: the scouted position comes up on the strategic map. Quiet reveal -- the line here is the
    // mission's own, not the reveal's AO-wide broadcast. An HP reveals by its key, a zone by pos.
    if (_kind isEqualTo "hp") then { ["ONE", _hpKey, 0, true] call fnc_hardpoint_reveal }
    else { ["ONE", _target, 0, true] call fnc_zone_reveal };

    // Bonus intel: the scout also picks up rand(0-2) of the nearest unrevealed positions -- the target's
    // own hardpoints (now discoverable), standalone or already-revealed-zone hardpoints, and unrevealed
    // enemy zones -- ranked by distance to the target. Quiet, like the target reveal; the markers appear.
    private _targetKey = [_target] call fnc_zone_key;
    private _revealedKeys = [_targetKey];
    { _x params ["", "_zp2", "_rev2"]; if (_rev2) then { _revealedKeys pushBack ([_zp2] call fnc_zone_key) } } forEach _pairs;
    private _extra = [];
    {
        _x params ["", "_zp", "_rev"];
        if (!_rev && {_zp distance2D _target > 1} && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
            _extra pushBack ["zone", _zp, _zp distance2D _target];
        };
    } forEach _pairs;
    {
        if (!(_x select 5) && {((_x select 4) isEqualTo "") || {(_x select 4) in _revealedKeys}}) then {
            _extra pushBack ["hp", _x select 0, (_x select 1) distance2D _target];
        };
    } forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);
    private _idx = [];
    { _idx pushBack [_x select 2, _forEachIndex] } forEach _extra;
    _idx sort true;
    private _n = (floor (random (BONUS_MAX + 1))) min (count _idx);
    for "_k" from 0 to (_n - 1) do {
        (_extra select ((_idx select _k) select 1)) params ["_kind", "_ref"];
        if (_kind isEqualTo "zone") then { ["ONE", _ref, 0, true] call fnc_zone_reveal }
        else { ["ONE", _ref, 0, true] call fnc_hardpoint_reveal };
    };

    [localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_RECON_OBSERVE_DONE"] remoteExec ["fnc_duws_dialogue", 0];
    [_overwatch, _radius, _prefabKey] call fnc_mission_end;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    [_taskID, "FAILED"] call fnc_missionTaskEnd;
    [localize "STR_DUWS_T_RECON_OBSERVE_FAILED", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    [_overwatch, _radius, _prefabKey] call fnc_mission_end;
};
