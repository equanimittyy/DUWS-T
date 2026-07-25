
_foundPickupPos = _this select 0;
_size = _this select 1;
_fob_owner = _this select 2;
_id = _this select 3;

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

sleep 5;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_fobcall"] call fnc_cs);
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// Create the building
_fob = "";
switch (VERSION_X) do {
	case "MODERN": {
		_fob = "Land_Cargo_HQ_V1_F" createVehicle _foundPickupPos;
	};

};

// FOB ADD ACTION MENU
[_fob, _fob_owner] remoteExec ["fnc_FOBactions", [0,-2] select isDedicated,true];

// Add the fortifications
_refortify = false;
[(getpos _fob), _fob, _refortify, _id] spawn fnc_fortifyFOB;

// create the patrols
[_foundPickupPos, _size] spawn fnc_createpatrolFOB;
[_foundPickupPos, _size] spawn fnc_createpatrolFOB;
[_foundPickupPos, _size] spawn fnc_createpatrolFOB;

[localize "STR_DUWS_T_26nbk6p8"] spawn fnc_sideChat_filter;

// create some patrols
[_foundPickupPos, _fob, _id] spawn fnc_guardsFOB;

// CREATE ZONE NOTIFICATION TRIGGER
_size = 75;
_trg23=createTrigger["EmptyDetector",_foundPickupPos];
_trg23 setTriggerArea[_size,_size,0,false];
_trg23 setTriggerActivation["ANYPLAYER","PRESENT",true];
_trg23 setTriggerStatements["this", format["['FOB %1',%2,'%3','%4',thisList] spawn fnc_enterlocation",_fobname,0,'',''], ""];
// CREATE VARNAME FOR FOB TRIGGER --> use the pos of the trigger
_fobPosName = format["trigfob%1%2",round (_foundPickupPos select 0),round (_foundPickupPos select 1)];
call compile format["%1 = _trg23",_fobPosName];

// warning trigger when an enemy approaches the camp
enemy_near_fob = format[localize 'STR_DUWS_T_i0w3u54j',_fobname];
_trgWarning = createTrigger["EmptyDetector",_foundPickupPos];
_trgWarning setTriggerArea[300,300,0,false];
_trgWarning setTriggerActivation["EAST","PRESENT",true];
// 使用 format 将 FOB 坐标写入字符串，确保触发时能正确传递位置参数
_trgWarning setTriggerStatements[
    "this", 
    format["[%1, enemy_near_fob] remoteExec ['BIS_fnc_showSubtitle', 0];", str(_foundPickupPos)], 
    ""
];
// CREATE VARNAME FOR WARNING TRIGGER --> use the pos of the trigger
_fobPosName2 = format["trigfob2%1%2",round (_foundPickupPos select 0),round (_foundPickupPos select 1)];
call compile format["%1 = _trgWarning",_fobPosName2];

//ADD THE FOB TO Array_of_FOBS
Array_of_FOBS = Array_of_FOBS + [_fob];
publicVariable "Array_of_FOBS";

Array_of_FOBname = Array_of_FOBname + [_fobname];
publicVariable "Array_of_FOBname";

_spawnPos = [west, _fob] call BIS_fnc_addRespawnPosition;

// spawn loop to detect FOB destroyed
[_fob,_markerstr, _spawnPos, _fobname] spawn fnc_fob_destroyed;

