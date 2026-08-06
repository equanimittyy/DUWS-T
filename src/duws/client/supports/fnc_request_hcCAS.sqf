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
HC_CAS_killedPending = false;

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

// Killed EH, spawned so it can sleep, with a state guard
_vehicle addEventHandler ["Killed", {
    _this spawn {
        params ["_killedVehicle"];
        if (!HC_CAS_active) exitWith {};
        if (_killedVehicle != HC_CAS_currentVehicle) exitWith {};

        HC_CAS_killedPending = true;  // mark Killed as handling so the Deleted EH skips it

        _speaker = localize "STR_DUWS_T_OVERLORD";
        _message = localize "STR_DUWS_T_casdownkoi";
        [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

        sleep 600;

        // after the sleep, check the Deleted EH didn't already reset it
        if (!HC_CAS_active) exitWith {};

        ["hc_CAS"] call fnc_support_comm_add;
        CASInUse = false;
        HC_CAS_active = false;
        HC_CAS_currentVehicle = nil;
        HC_CAS_killedPending = false;

        _speaker = localize "STR_DUWS_T_OVERLORD";
        _message1 = ([localize "STR_DUWS_T_casreservekoi"] call fnc_cs);
        [_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
    };
}];

// Deleted EH: plane removed directly while its crew survives
_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_CAS_active) exitWith {};
    if (_deletedVehicle != HC_CAS_currentVehicle) exitWith {};

    // if a Killed EH is already pending, let it handle this and skip
    if (HC_CAS_killedPending) exitWith {};

    // re-add the HC menu item now, since the crew is still alive
    ["hc_CAS"] call fnc_support_comm_add;
    CASInUse = false;
    HC_CAS_active = false;
    HC_CAS_currentVehicle = nil;
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_casreservekoi"] call fnc_cs);  // reuse the "available" hint
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
}];