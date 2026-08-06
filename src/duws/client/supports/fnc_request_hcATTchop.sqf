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
HC_ATTchop_killedPending = false;

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

// Killed EH, with a guard against conflicting with the Deleted EH
_vehicle addEventHandler ["Killed", {
    _this spawn {
        params ["_killedVehicle"];
    if (!HC_ATTchop_active) exitWith {};
    if (_killedVehicle != HC_ATTchop_currentVehicle) exitWith {};

    HC_ATTchop_killedPending = true;  // mark Killed as handling so the Deleted EH skips it

    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = localize "STR_DUWS_T_casdownlb";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

    sleep 580;

    // after the sleep, check the Deleted EH didn't already reset it
    if (!HC_ATTchop_active) exitWith {};

    ["hc_ATTchop"] call fnc_support_comm_add;
    AttChopInUse = false;
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    HC_ATTchop_killedPending = false;

    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message1 = ([localize "STR_DUWS_T_casreservelb"] call fnc_cs);
    [_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
    };
}];

// Deleted EH: heli removed directly while its crew survives
_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_ATTchop_active) exitWith {};
    if (_deletedVehicle != HC_ATTchop_currentVehicle) exitWith {};

    // if a Killed EH is already pending, let it handle this and skip
    if (HC_ATTchop_killedPending) exitWith {};

    // re-add the HC menu item now, since the crew is still alive
    ["hc_ATTchop"] call fnc_support_comm_add;
    AttChopInUse = false;
    HC_ATTchop_active = false;
    HC_ATTchop_currentVehicle = nil;
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_casreservelb"] call fnc_cs);  // reuse the "available" hint
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
}];