
//if (!Mission_available) exitWith {};

//Mission_available = false;

sleep 360;   // 6 min

if (Mission_available) exitWith {};
Mission_available = true;
publicVariable "Mission_available";
_speaker = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_missiontimer";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
skiptime 3;
[] remoteExec ["fnc_bottom_right_message", [0,-2] select isDedicated,true];
{deleteVehicle _x} forEach allDeadMen;
sleep 5;
["info",[localize "STR_DUWS_T_zhixian",localize "STR_DUWS_T_6mg3jdt8"]] remoteExec ['BIS_fnc_showNotification',0];