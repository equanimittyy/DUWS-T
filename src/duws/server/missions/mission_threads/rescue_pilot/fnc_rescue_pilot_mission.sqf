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
// Captive until a rescuer reaches him (dropped below): while the patrols still ring the crash, an un-captived
// prone casualty would just be gunned down off the timer before anyone could arrive.
_pilot setCaptive true;
[_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
removeAllItems _pilot;
_pilot setDamage 0.8;
_pilot disableAI "PATH";
// Halve every incoming hit (protect-informant's clamp) so one round can't finish a man spawned at 0.8 once he
// loses captive; scripted setDamage does not fire HandleDamage, so the 0.8 and the win-state patch still land.
// AIS never enrols a spawned unit, but AIS_noReviveInit guards this handler from being stripped (revive_system.md).
_pilot setVariable ["AIS_noReviveInit", true, true];
_pilot addEventHandler ["HandleDamage", {
    params ["_u", "", "_dmg", "", "", "_hi"];
    private _old = if (_hi < 0) then { damage _u } else { _u getHitIndex _hi };
    _old + ((_dmg - _old) * 0.5)
}];

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
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_pilotkilled"], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};
if (time > _deadline) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    _pilot setDamage 1;
    // _line empty + _notify true: speak the shared "out of time" call, since a missed deadline is exactly that.
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, true] call fnc_mission_finish;
};

// Reached. Start the 10-minute bleedout, reveal the pilot's icons, and send every spawned enemy group onto the
// crash. From here only the bleedout clock, the pilot's death, or arrival at HQ can end the mission.
private _bleedout = time + 600;

// Drop captive now a rescuer is on him: the converging patrols (below) engage the pilot too, not only the crew
// carrying him. The HandleDamage clamp at spawn is what keeps that under-fire window survivable.
_pilot setCaptive false;

// Pilot icons, gated to the timer: DUWS_float_pilot feeds the 3D float (client/missions/fnc_protect_civ_markers.sqf)
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

// Bleedout hint: refresh the minutes-left count every 60 s, mirroring the Protect Informant prep counter.
// Stops the moment the pilot reaches HQ, dies, or the clock expires -- the expiry hint below names the
// cause of death, so this counter never has to draw zero.
[_pilot, _bleedout] spawn {
    params ["_pilot", "_bleedout"];
    while { alive _pilot && { (_pilot distance PosOfBLUHQ) >= 20 } && { time < _bleedout } } do {
        [format [localize "STR_DUWS_T_pilot_bleed_count", ceil (round (_bleedout - time) / 60)]] remoteExec ["hint", [0, -2] select isDedicated];
        private _next = time + 60;
        waitUntil { sleep 1; time >= _next || !(alive _pilot) || (_pilot distance PosOfBLUHQ) < 20 || time >= _bleedout };
    };
};

waitUntil {
    sleep 1;
    (_pilot distance PosOfBLUHQ) < 20 || !(alive _pilot) || time > _bleedout
};

// Bleedout expiry kills him; the death branch below then reports it with the KIA line. The timer's only
// extra is the hint naming the cause.
if (alive _pilot && (_pilot distance PosOfBLUHQ) >= 20 && time > _bleedout) then {
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0, -2] select isDedicated, false];
    _pilot setDamage 1;
};

if (!(alive _pilot)) exitWith {
    call _clearIcons;
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_pilotkilled"], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};

// Win banked here, at winning range: task closed, reward paid, Overlord calls it in -- player is free the
// instant he reaches HQ. His limp to the tent and despawn there run as a background tail (below), off this thread.
call _clearIcons;
// Off whatever holds him -- a player's back or a vehicle -- and every carry hook stripped, so he limps in alone.
CLEANUP_PILOT(_pilot);
if (!isNull attachedTo _pilot) then { detach _pilot; };
if (vehicle _pilot != _pilot) then {
    moveOut _pilot;
    private _outBy = time + 1;
    waitUntil { vehicle _pilot == _pilot || time > _outBy };
};

_pilot setDamage 0.4;
// Force the limp gait no matter his actual HP: overall 0.4 damage walks near-normally, a hurt leg is what
// reads as a wounded man making his own way in. Set after setDamage so it isn't overwritten.
_pilot setHitPointDamage ["HitLegs", 0.6];
[_pilot, ""] remoteExec ["switchMove", 0];
_pilot enableAI "ALL";
_pilot enableAI "PATH";

[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _targetpos, _radius, [_markername2], [], true, "mission_rescue_pilot", false, false] call fnc_mission_finish;

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_pilotend2"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// Pilot's own thanks, keyed 2 s behind Overlord's wrap-up: he is a VOICE speaker and the drain
// empties VOICE before NET, so firing the two together would put his line ahead of the call it
// answers. The gap lets Overlord's line land first.
[_speaker1, _message2] spawn {
    params ["_speaker1", "_message2"];
    sleep 2;
    [_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
};

// Flavor tail: he limps to the tent and despawns (5 min or within 5 m). finish already reopened the mission
// slot, so a later rescue can reclaim currentMissionPilot while he still walks -- clear it only if still ours.
[_pilot] spawn {
    params ["_pilot"];
    private _tent = objectFromNetId (missionNamespace getVariable ["HQ_medTent_netId", ""]);
    if (!isNull _tent) then {
        _pilot doMove (getPosATL _tent);
        private _walkTimeout = time + 300;
        // Re-wound the leg each tick: a player healing him mid-walk would otherwise clear it and drop the limp.
        waitUntil { sleep 1; _pilot setHitPointDamage ["HitLegs", 0.6]; !(alive _pilot) || (_pilot distance _tent < 5) || time > _walkTimeout };
    };
    private _wasCurrent = (missionNamespace getVariable ["currentMissionPilot", objNull]) isEqualTo _pilot;
    deleteVehicle _pilot;
    if (_wasCurrent) then {
        missionNamespace setVariable ["currentMissionPilot", nil];
        publicVariable "currentMissionPilot";
    };
};
