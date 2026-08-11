// Locality: client; the event-handler bodies below run on the machine that triggers them,
// not here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:187).
AttChopInUse = true;

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