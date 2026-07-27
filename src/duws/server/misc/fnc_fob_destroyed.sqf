if (!isServer) exitWith {};
// BEGIN OF SPAWN "IF FOB DESTROYED"
_fob = _this select 0;
_markername = _this select 1;
_spawnPos = _this select 2;
_fobname = _this select 3;
// Captured at build time rather than read here: this runs against a destroyed building.
_fobPos = _this select 4;
    
waitUntil {sleep 60;!alive _fob};

// check if it was removed
if (FOB_removed) exitWith {deleteMarker _markername;FOB_removed = false};

deleteMarker _markername;
_spawnPos call BIS_fnc_removeRespawnPosition;

["WARN", "SUPPORT", format ["FOB '%1' destroyed, respawn point withdrawn", _fobname]] call fnc_log;

["info2",[localize "STR_DUWS_T_r17nker3",_fobname]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_fobdown"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
[_fobPos] call fnc_fob_deregister;

