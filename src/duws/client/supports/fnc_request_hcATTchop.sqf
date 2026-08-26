// Locality: client; the event-handler bodies below run on the machine that triggers them,
// not here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:187).
AttChopInUse = true;
[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_hcattrequest"] call fnc_cs), "", name player] remoteExec ["fnc_duws_dialogue", 0];

_grouptype = [];
_spawnPos = getmarkerpos str blu_hq_markername;

switch (VERSION_X) do {
	case "MODERN": {
		_spawnPos = [(_spawnPos select 0)+250, _spawnPos select 1, (_spawnPos select 2)+200];
		_grouptype = [blufor_ATTACK_HELI_X];
	};
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

_leader = leader _group;
_vehicle = vehicle _leader;

// store the current attack heli in a global for event-handler sync
HC_ATTchop_currentVehicle = _vehicle;
HC_ATTchop_active = true;

player hcsetgroup [_group,""];
DUWS_number_attackchopa = DUWS_number_attackchopa + 1;

switch (VERSION_X) do {
	case "MODERN": {
		_group setGroupId [format[localize "STR_DUWS_T_8mtxjfj3",DUWS_number_attackchopa]];
	};
};
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_hcattack"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_longbowpilot";
_message = ([localize "STR_DUWS_T_longbowin"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
hint localize "STR_DUWS_T_rjuehu36";

// State is reset the instant the gunship is lost, not after a cooldown: the support is spent at
// selection and never re-added, so a stale handler must not linger and reset a re-bought gunship's
// tracking. Killed handles a shoot-down; Deleted handles a despawn with the crew still alive.
_vehicle addEventHandler ["Killed", {
    params ["_killedVehicle"];
    if (!HC_ATTchop_active) exitWith {};
    if (_killedVehicle != HC_ATTchop_currentVehicle) exitWith {};
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    AttChopInUse = false;
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_casdownlb"] remoteExec ["fnc_duws_dialogue", 0];
}];

_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_ATTchop_active) exitWith {};
    if (_deletedVehicle != HC_ATTchop_currentVehicle) exitWith {};
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    AttChopInUse = false;
}];

// On-station leash: the gunship holds for a fixed window, then breaks off, flies home and despawns.
// A one-time support that only ever ended by being shot down was permanent once bought; this makes it
// a sortie. Runs on this thread -- nothing follows the handlers, and a shoot-down ends the wait early
// so the leash never fights its own Killed handler for the cleanup.
private _leash = time + (missionNamespace getVariable ["HC_air_station_seconds", 1800]);
waitUntil { sleep 5; time > _leash || !alive _vehicle };
if (alive _vehicle && HC_ATTchop_active) then {
    [localize "STR_DUWS_T_longbowpilot", [localize "STR_DUWS_T_hc_attchop_rtb"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    private _hq = getmarkerpos str blu_hq_markername;
    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
    _group setBehaviour "CARELESS";
    private _wp = _group addWaypoint [_hq, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    // Grace cap so a damaged or blocked aircraft that never reaches home still cleans up.
    private _grace = time + 180;
    waitUntil { sleep 3; !alive _vehicle || _vehicle distance _hq < 400 || time > _grace };
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    AttChopInUse = false;
    [_vehicle, _group] call fnc_support_despawn;
};