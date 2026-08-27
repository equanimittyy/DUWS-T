// Locality: server -- callers remoteExec to target 2.
//
// Recon-observe. The player infils to a designated overwatch position, raises binoculars, and holds
// eyes-on an unrevealed OPFOR position (a zone or standalone hardpoint) long enough to scout it;
// success lifts that position's fog of war on the strategic map. The site-finder
// (fnc_recon_observe_site) returns the TARGET position via the shared picker; this thread computes the
// overwatch itself -- terrain and object line-of-sight, on the friendly-facing side, favouring height
// over the target.
//
// Both a zone and a hardpoint are observed where they really stand: the mission builds no stand-in for
// either, so the old bug where a stand-in overlapped the real garrison and a player walked into it is
// gone. A hardpoint's stream ring already covers the 600-800 m overwatch band, so approaching the
// outlook wakes the real emplacement through its own site poller. A zone's ring is tighter and its
// garrison would be asleep out here, so the mission widens the zone's stream radius for its own
// lifetime instead of building a copy.
params ["_MissionPos", "_mission_name"];

// TUNABLE, all here. Standoff band (kept with the finder); observe area; LOS range slack; hold seconds;
// the lead the real zone is woken within of the overwatch, so its garrison is up before the hold begins;
// the clearance the overwatch keeps from other enemy zones and hardpoints; and the most bonus positions a
// scout also reveals.
#define OBS_MIN_DIST    600
#define OBS_MAX_DIST    800
#define OBS_AREA        75
#define OBS_RANGE       900
#define HOLD_TIME       12
#define SPAWN_R         200
#define ZONE_CLEAR      250
#define HP_CLEAR        300
#define BONUS_MAX       2

// Target: the finder returned the target position as _MissionPos, so re-deriving the nearest unrevealed
// OPFOR position to it lands on the same target -- exact, via the shared picker, not the ambiguous
// "nearest to an overwatch". The kind (zone or hardpoint) rides the pick; if captured, cleared or
// revealed since the offer the next nearest resolves, none left aborts. A zone pos is kept, not copied --
// fnc_zone_reveal matches its target by str(pos); an HP reveals by its key.
private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _pick = [_MissionPos] call fnc_recon_observe_pick;
if (_pick isEqualTo []) exitWith {
    [12, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};
private _kind   = _pick select 0;
private _target = _pick select 1;
private _hpKey  = if (_kind isEqualTo "hp") then { _pick select 2 } else { "" };

if (!([12, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};
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
    [12, "STR_DUWS_T_crtzxs0j"] call fnc_mission_abort;
};

// The anchor the 3D marker and hold LOS ride: the real target, which the overwatch was verified to have
// clear line-of-sight to.
private _anchor = _target;

// A zone target's site key and its true stream radius, saved so the mission can hand the radius back on
// end (the widen happens once the layer is pushed, below). Left "" / 0 for a hardpoint, which streams on
// its own ring and is never touched here.
private _zoneSiteKey   = "";
private _zoneOrigRadius = 0;

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

// Nearest named settlement to the scouted target (not the overwatch the player is sent to): the
// overwatch is already map-marked, so the brief names where the enemy is.
private _place = [_target] call fnc_place_name;

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_RECON_OBSERVE_BRIEF", _place]] remoteExec ["fnc_duws_dialogue", 0];

// Wake the REAL zone by widening its stream radius, so the shared poller raises it as the player nears the
// outlook instead of the mission standing up a copy. The ring the poller wakes on is the site radius plus
// the garrison's buffer; pushed to reach the overwatch plus SPAWN_R of lead, the poller raises the zone
// before the player is set and holds it up while they stay (lastSeen stays fresh inside the ring), then
// stows it on the normal grace once they leave. max() never shrinks a zone whose ring already reaches, and
// the raise worker re-confirms against this same radius, so wake and confirm cannot disagree. The site
// record's radius alone moves; the capture triggers keep their own geometry, so the zone captures over its
// true size. Handed back on end below.
if (_kind isEqualTo "zone") then {
    _zoneSiteKey = [_target] call fnc_zone_key;
    private _site = [_zoneSiteKey] call fnc_site_at;
    _zoneOrigRadius = _site getOrDefault ["radius", 0];
    if (_zoneOrigRadius > 0) then {
        private _buffer = ([_zoneSiteKey, "garrison"] call fnc_site_occupant) getOrDefault ["buffer", 400];
        _site set ["radius", (((_overwatch distance2D _target) + SPAWN_R - _buffer) max _zoneOrigRadius)];
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

// Stand the client layer down before scoring: the observe layer gates on this flag, and a cleared JIP key
// stops it reaching a later joiner. The real zone is not torn down here -- it is campaign state the zone
// poller owns; only its widened stream radius is handed back, so from now it streams on its true ring,
// stowing when the player leaves and waking again if they close to assault. A hardpoint target left the
// key "" and never moved.
DUWS_recon_active = false;
publicVariable "DUWS_recon_active";
remoteExec ["", "DUWS_recon_layer_jip"];
if (_zoneSiteKey isNotEqualTo "") then { ([_zoneSiteKey] call fnc_site_at) set ["radius", _zoneOrigRadius] };
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

    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_RECON_OBSERVE_DONE"] remoteExec ["fnc_duws_dialogue", 0];
    // Only when the scout actually picked up extras: the queue plays this behind the confirm above, so
    // the player hears the target marked, then the bonus. Silent when the roll revealed nothing.
    if (_n > 0) then {
        [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_RECON_OBSERVE_BONUS"] remoteExec ["fnc_duws_dialogue", 0];
    };
    [_overwatch, _radius, ""] call fnc_mission_end;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    [_taskID, "FAILED"] call fnc_missionTaskEnd;
    [localize "STR_DUWS_T_RECON_OBSERVE_FAILED", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
    [_overwatch, _radius, ""] call fnc_mission_end;
};
