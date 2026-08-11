// Locality: client; the event-handler bodies below run on the machine that triggers them,
// not here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:198).
CASInUse = true;

_spawnPos = getmarkerpos str blu_hq_markername;
_grouptype = [blufor_MISC_AIR_X];

switch (VERSION_X) do {
	case "MODERN": {
		_vec =[random [-1,0,1], random [-1,0,1], 0];
		_dist = 500;
		_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+800];
	};
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
sleep 1;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle engineOn true;

// store the current CAS jet in a global for event-handler sync
HC_CAS_currentVehicle = _vehicle;
HC_CAS_active = true;

switch (VERSION_X) do {
	case "MODERN": {
		_vehicle flyInHeight 150;
	};
};
_speaker = localize "STR_DUWS_T_koipilot";
_message = ([localize "STR_DUWS_T_koiin"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

player hcsetgroup [_group,""];
DUWS_number_CAS = DUWS_number_CAS + 1;
_group setGroupId [format[localize "STR_DUWS_T_8mtxjfj3",DUWS_number_CAS]];
hint localize "STR_DUWS_T_gu6cbc5f";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// State is reset the instant the jet is lost, not after a cooldown: the support is spent at
// selection and never re-added, so a stale handler must not linger and reset a re-bought jet's
// tracking. Killed handles a shoot-down; Deleted handles a despawn with the crew still alive.
_vehicle addEventHandler ["Killed", {
    params ["_killedVehicle"];
    if (!HC_CAS_active) exitWith {};
    if (_killedVehicle != HC_CAS_currentVehicle) exitWith {};
    HC_CAS_active = false;
    HC_CAS_currentVehicle = nil;
    CASInUse = false;
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_casdownkoi"] remoteExec ["fnc_duws_dialogue", 0];
}];

_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_CAS_active) exitWith {};
    if (_deletedVehicle != HC_CAS_currentVehicle) exitWith {};
    HC_CAS_active = false;
    HC_CAS_currentVehicle = nil;
    CASInUse = false;
}];