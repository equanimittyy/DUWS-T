// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).

_foundPickupPos = _this select 0;
_size = _this select 1;
_fob_owner = _this select 2;

_fobname = [1] call fnc_random_name;

// create marker on FOB
_markername = format["fob%1%2",round (_foundPickupPos select 0),round (_foundPickupPos select 1)]; // Define marker name
//hint _markername;
_markerstr = createMarker [str(_markername), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "loc_Bunker";
str(_markername) setMarkerColor "ColorBLUFOR";
str(_markername) setMarkerColor "ColorBlue";
str(_markername) setMarkerText format["FOB %1",_fobname];
str(_markername) setMarkerSize [2.5, 2.5];

// The ring showing what a vehicle parked here keeps, same as the HQ carries.
[_foundPickupPos] call fnc_baseRangeMarker;

sleep 5;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_fobcall"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// A FOB is a building and a ring of fortifications appearing out of nothing, and anyone stood on
// that ground sees it pop in around them.
private _fadePlayers = ["OUT", _foundPickupPos] call fnc_baseFade;

// Create the building
_fob = "";
switch (VERSION_X) do {
	case "MODERN": {
		_fob = "Land_Cargo_HQ_V1_F" createVehicle _foundPickupPos;
	};

};
[_fob, format ["FOB_%1", netId _fob]] call fnc_duws_keep;

// FOB ADD ACTION MENU
// Keyed to the FOB so the entry dies with it. The defences and guards entries hang off the same
// FOB and cannot use this form -- an object-keyed id is that object's netId, so the three would
// evict each other; those two suffix a string instead.
[_fob, _fob_owner] remoteExec ["fnc_FOBactions", [0,-2] select isDedicated,_fob];

// Add the fortifications
_refortify = false;
[(getpos _fob), _fob, _refortify] spawn fnc_fortifyFOB;

// Held until the fortification pass has placed its objects -- it creates them before its first
// sleep, so a short wait covers the ring as well as the building. The patrols below are units
// walking in and need no cover.
if (count _fadePlayers > 0) then {
	sleep 2;
	["IN", _fadePlayers] call fnc_baseFade;
};

// create the patrols
[_foundPickupPos, _size] spawn fnc_createpatrolFOB;
[_foundPickupPos, _size] spawn fnc_createpatrolFOB;
[_foundPickupPos, _size] spawn fnc_createpatrolFOB;

[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_26nbk6p8"] remoteExec ["fnc_duws_dialogue", 0];

// create some patrols
[_foundPickupPos, _fob] spawn fnc_guardsFOB;

// No arrival trigger: it existed only to announce a friendly element reaching the FOB, and the
// hardcore reveal fnc_enterlocation still does is keyed on a zone name, which a FOB never has.

// warning trigger when an enemy approaches the camp
enemy_near_fob = format[localize 'STR_DUWS_T_i0w3u54j',_fobname];
_trgWarning = createTrigger["EmptyDetector",_foundPickupPos];
_trgWarning setTriggerArea[300,300,0,false];
_trgWarning setTriggerActivation["EAST","PRESENT",true];
// 使用 format 将 FOB 坐标写入字符串，确保触发时能正确传递位置参数
_trgWarning setTriggerStatements[
    "this", 
    format["[%1, enemy_near_fob] remoteExec ['fnc_duws_dialogue', 0];", str(_foundPickupPos)],
    ""
];
// Filed under the rounded trigger position, which is the only key fnc_FOB_cleanup can rebuild
// from the FOB position it is handed.
missionNamespace setVariable [
    format["trigfob2%1%2",round (_foundPickupPos select 0),round (_foundPickupPos select 1)],
    _trgWarning
];

//ADD THE FOB TO Array_of_FOBS
Array_of_FOBS = Array_of_FOBS + [_fob];
publicVariable "Array_of_FOBS";

Array_of_FOBname = Array_of_FOBname + [_fobname];
publicVariable "Array_of_FOBname";

// getPos _fob, not _foundPickupPos: createVehicle can nudge the building off the requested
// spot, and the removal dialog identifies a FOB by reading getPos back off Array_of_FOBS.
// Storing the request would leave the two describing positions that never quite match.
Array_of_FOBpos = Array_of_FOBpos + [getPos _fob];
publicVariable "Array_of_FOBpos";

["INFO", "SUPPORT", format ["FOB '%1' built at %2, %3 now standing",
	_fobname, _foundPickupPos, count Array_of_FOBS]] call fnc_log;

_spawnPos = [west, _fob] call BIS_fnc_addRespawnPosition;

// spawn loop to detect FOB destroyed
[_fob,_markerstr, _spawnPos, _fobname, getPos _fob] spawn fnc_fob_destroyed;

