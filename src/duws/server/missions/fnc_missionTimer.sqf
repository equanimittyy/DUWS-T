// Locality: server -- callers remoteExec to target 2.

//if (!Mission_available) exitWith {};

//Mission_available = false;

sleep 360;   // 6 min

if (Mission_available) exitWith {};
Mission_available = true;
publicVariable "Mission_available";
["INFO", "MISSION", "mission slot released, a new side mission can generate"] call fnc_log;
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_missiontimer"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
skiptime 3;
[] remoteExec ["fnc_bottom_right_message", [0,-2] select isDedicated,false];
{deleteVehicle _x} forEach allDeadMen;
sleep 5;
["info",[localize "STR_DUWS_T_zhixian",localize "STR_DUWS_T_6mg3jdt8"]] remoteExec ['BIS_fnc_showNotification',0];