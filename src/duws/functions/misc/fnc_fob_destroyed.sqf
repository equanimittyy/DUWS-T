if (!isServer) exitWith {};
// BEGIN OF SPAWN "IF FOB DESTROYED"
_fob = _this select 0;
_markername = _this select 1;
_spawnPos = _this select 2;
_fobname = _this select 3;
    
waitUntil {sleep 60;!alive _fob};

// check if it was removed
if (FOB_removed) exitWith {deleteMarker _markername;FOB_removed = false};

deleteMarker _markername;
_spawnPos call BIS_fnc_removeRespawnPosition;

["info2",[localize "STR_DUWS_T_r17nker3",_fobname]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_fobdown"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
{
	if (_x == _fob) then {
		Array_of_FOBS deleteAt _forEachIndex;
		publicVariable "Array_of_FOBS";
	};
} forEach Array_of_FOBS;
{
	if (_x == _fobname) then {
		Array_of_FOBname deleteAt _forEachIndex;
		publicVariable "Array_of_FOBname";
	};
} forEach Array_of_FOBname;

