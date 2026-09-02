// Locality: server; the addAction/trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([4, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

// Broadcast to every client (JIP) so the carry actions exist on the carrier's own machine; guarded so a
// second launch skips the re-broadcast.
if (isNil "DUWS_fnc_addCarryAction") then {
    private _carryDefs = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_pilot\fnc_pilot_carry.sqf";
    call _carryDefs;
    [_carryDefs] remoteExec ["call", 0, true];
};

// Enemy patrol composition. Token-based: each foot token raises a team through fnc_spawn_team, each vehicle
// token resolves to a class through DUWS_fnc_tokenClass (which returns "" for a rung the player's Army Power
// has not opened yet -- that is the "if available" on the ifvs).
private _patrolTokens  = ["recon", "recon", "team", "wp_team", "patrol", "patrol"];
private _vehicleTokens = ["car", "car", "ifv", "ifv"];

_radius = 1000;
_deadline = DUWS_curDeadlineAt;
_speaker  = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_pilot_downed";
_message1 = localize "STR_DUWS_T_pilotfound";
_message2 = localize "STR_DUWS_T_pilotend";

private _site = [_MissionPos, _radius, 4, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Heli sits in a random spot inside the zone, kept >300 m from any road so the crash reads as gone-down-in-
// the-wild rather than parked on a verge. Rejection sample; fall back to the zone centre if no clear spot is
// found, rather than fail the mission over terrain.
private _heliPos = _targetpos;
private _tries = 0;
while { _tries < 80 } do {
    _tries = _tries + 1;
    private _p = [_randomPos, 0, _radius, 10, 0, 0.3, 0] call BIS_fnc_findSafePos;
    if (_p isEqualTo [] || {surfaceIsWater _p}) then { continue };
    if (count (_p nearRoads 300) > 0) then { continue };
    _heliPos = _p;
    _tries = 80;
};

// The task name finish reads back; the marker follows the pilot once the bleedout timer starts (below).
private _VARtaskgeneratedName = format ["rescue%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

sleep 1;

// Downed attack heli + its wood-smoke column beacon. Smoke is built per client and JIP-tied to the wreck
// object (the same DUWS_fnc_campSmoke the patrol camp stands on its campfire): a #particlesource carries no
// config, so its emitter is set locally on each machine.
_choppa = objNull;
switch (VERSION_X) do {
    case "MODERN": {
        _choppa = "Land_Wreck_Heli_Attack_01_F" createVehicle _heliPos;
        [_choppa, "mission_rescue_pilot"] call fnc_duws_keep;
        [_choppa] remoteExec ["DUWS_fnc_campSmoke", [0, -2] select isDedicated, _choppa];
    };
};

private _group = [[_heliPos select 0, (_heliPos select 1) + 2], WEST, [blufor_HELI_PILOT_X]] call BIS_fnc_spawnGroup;
_pilot = units _group select 0;
_group deleteGroupWhenEmpty true;
// Captive the whole mission: the threat is the bleedout clock and the enemy converging on the crew who carry
// him, not the pilot being shot -- an unarmed casualty enemies keep gunning down would just be noise on the timer.
_pilot setCaptive true;
[_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
removeAllItems _pilot;
_pilot setDamage 0.8;
_pilot disableAI "PATH";

_pilot addEventHandler ["Killed", {
    params ["_unit", "_killer"];
    private _carrier = _unit getVariable ["carrier", objNull];
    if (!isNull _carrier) then {
        [_carrier] remoteExec ["DUWS_fnc_clearCarrierActions", 0];
    };
    [_unit] remoteExec ["DUWS_fnc_removeCarryAction", 0];
}];

missionNamespace setVariable ["currentMissionPilot", _pilot];
publicVariable "currentMissionPilot";

[_pilot] call DUWS_fnc_addCarryAction;

// Enemy patrols ringed around the crash so no patrol's circuit reaches the 300 m exclusion: a sub-centre sits
// _footRing/_vehRing out from the heli and fnc_apply_posture walks widepatrol within radius*0.9 of it, so the
// nearest a leg comes to the pilot is (ring - 0.9*_patrolArgR). Collected as _enemyGroups so the whole set can
// be re-tasked onto the crash the moment the player reaches him (below). A path in transit between two clear
// legs can still clip the bubble -- AI pathing is free -- but no patrol is stationed or circuits inside it.
private _enemyGroups = [];
private _patrolArgR = 200;
private _footRing = 550;
private _vehRing  = 650;

{
    private _ang = 360 * _forEachIndex / (count _patrolTokens);
    private _sub = [_heliPos, _footRing, _ang] call BIS_fnc_relPos;
    private _grp = [_x, _sub, _patrolArgR, "widepatrol"] call fnc_spawn_team;
    if (!isNull _grp) then {
        [_grp] call fnc_mission_claim;
        _enemyGroups pushBack _grp;
    };
    sleep 1;
} forEach _patrolTokens;

{
    private _class = [_x] call DUWS_fnc_tokenClass;
    if (_class != "") then {
        private _ang = 45 + (360 * _forEachIndex / (count _vehicleTokens));
        private _sub = [_heliPos, _vehRing, _ang] call BIS_fnc_relPos;
        private _grp = [_class, _sub, _patrolArgR, "widepatrol"] call fnc_spawn_vehicle;
        if (!isNull _grp) then {
            [_grp] call fnc_mission_claim;
            _enemyGroups pushBack _grp;
        };
        sleep 1;
    };
} forEach _vehicleTokens;

// Zone marker + brief. No pilot icon yet -- he is only pinpointed once the timer is running (below).
_markername2 = [_randomPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_njsu8ofz", _mission_name, "help",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_pilotletsdothis", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_pilotcopy", 0]]
] call fnc_mission_present;

#define CLEANUP_PILOT(pilot) \
    [pilot] call DUWS_fnc_cleanupPilotActions; \
    [pilot] remoteExec ["DUWS_fnc_cleanupPilotActions", 0];

// Reach the pilot: a west player within 30 m. The mission deadline only gates this leg -- once the player is on
// him the bleedout timer takes over and the deadline no longer applies.
waitUntil {
    sleep 1;
    ({ side _x == west && { alive _x } && { _x distance _pilot < 30 } } count allPlayers > 0)
    || !(alive _pilot) || time > _deadline
};

if (!(alive _pilot)) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0, -2] select isDedicated, false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};
if (time > _deadline) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    _pilot setDamage 1;
    [{hint localize "STR_DUWS_T_fxysw123"}] remoteExec ["BIS_fnc_Spawn", [0, -2] select isDedicated, false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};

// Reached. Start the 10-minute bleedout, reveal the pilot's icons, and send every spawned enemy group onto the
// crash. From here only the bleedout clock, the pilot's death, or arrival at HQ can end the mission.
private _bleedout = time + 600;

// Pilot icons, gated to the timer: DUWS_float_pilot feeds the 3D float (client/misc/fnc_protect_civ_markers.sqf)
// and the map marker tracks his position. Both cleared by _clearIcons at every exit below.
DUWS_float_pilot = _pilot; publicVariable "DUWS_float_pilot";
private _trackMarker = format ["rescuepilot_trk_%1", missionNamespace getVariable ["DUWS_mission_token", 0]];
createMarker [_trackMarker, getPosATL _pilot];
_trackMarker setMarkerShape "ICON";
_trackMarker setMarkerType "mil_warning";
_trackMarker setMarkerColor "ColorBlue";
_trackMarker setMarkerText "Pilot";
[_pilot, _trackMarker] spawn {
    params ["_pilot", "_mk"];
    while { !isNull _pilot && { alive _pilot } && { markerType _mk != "" } } do {
        _mk setMarkerPos (getPosATL _pilot);
        sleep 5;
    };
};
private _clearIcons = {
    DUWS_float_pilot = objNull; publicVariable "DUWS_float_pilot";
    deleteMarker _trackMarker;
};

// Converge: retask the patrols from their circuits onto the crash. SAD searches out from the wreck the player
// just left, so they sweep his line of retreat rather than sitting on empty legs.
{
    private _g = _x;
    if (!isNull _g && { { alive _x } count units _g > 0 }) then {
        while { count waypoints _g > 0 } do { deleteWaypoint [_g, 0]; };
        _g setBehaviour "AWARE";
        _g setCombatMode "RED";
        _g setSpeedMode "FULL";
        private _wp = _g addWaypoint [_heliPos, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointSpeed "FULL";
        private _cyc = _g addWaypoint [_heliPos, 50];
        _cyc setWaypointType "CYCLE";
    };
} forEach _enemyGroups;

[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

waitUntil {
    sleep 1;
    (_pilot distance PosOfBLUHQ) < 50 || !(alive _pilot) || time > _bleedout
};

if (!(alive _pilot)) exitWith {
    call _clearIcons;
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0, -2] select isDedicated, false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};
if ((_pilot distance PosOfBLUHQ) >= 50 && time > _bleedout) exitWith {
    call _clearIcons;
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    _pilot setDamage 1;
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0, -2] select isDedicated, false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, true] call fnc_mission_finish;
};

// Won: pilot at HQ. Off the player's back, patched enough to walk, then he makes his own way into the medical
// tent and despawns there. Timeout-guarded so a stuck path still ends the walk and the mission.
call _clearIcons;
if (!isNull attachedTo _pilot) then {
    detach _pilot;
    CLEANUP_PILOT(_pilot);
};

_pilot setDamage 0.4;
[_pilot, ""] remoteExec ["switchMove", 0];
_pilot enableAI "ALL";
_pilot enableAI "PATH";
private _tent = objectFromNetId (missionNamespace getVariable ["HQ_medTent_netId", ""]);
if (!isNull _tent) then {
    _pilot doMove (getPosATL _tent);
    private _walkTimeout = time + 30;
    waitUntil { sleep 1; !(alive _pilot) || (_pilot distance _tent < 3) || time > _walkTimeout };
};

[_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
deleteVehicle _pilot;
missionNamespace setVariable ["currentMissionPilot", nil];
publicVariable "currentMissionPilot";
sleep 5;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_pilotend2"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _targetpos, _radius, [_markername2], [], true, "mission_rescue_pilot", false, false] call fnc_mission_finish;

// Guaranteed and called, not spawned into a client function: intel_payout began `if (!hasInterface)
// exitWith {}`, so spawning it from this server thread evaporated the reward on a dedicated server. The
// mission site stands in for the earner's position -- a server thread has no one player to ask.
if (hardcore_mode_enable) then { [_heliPos] call fnc_intel_payout };
