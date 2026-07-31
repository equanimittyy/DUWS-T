// Locality: server -- called by mission threads only, all server-side.

//if (!Mission_available) exitWith {};

//Mission_available = false;

// uiSleep, not sleep: setTimeMultiplier scales sleep, so a host running the campaign clock at
// 8x would get four minutes out of this rather than thirty. The slot lock is paced against the
// player's evening, not the campaign's daylight.
//
// The figure is quoted to the player in STR_DUWS_T_b68ftbvf, the refusal hint the request menu
// shows while this is running. Retune both together.
uiSleep 1800;   // 30 min

if (Mission_available) exitWith {};
Mission_available = true;
publicVariable "Mission_available";
["INFO", "MISSION", "mission slot released, a new side mission can generate"] call fnc_log;
skiptime 3;
[] remoteExec ["fnc_bottom_right_message", [0,-2] select isDedicated,false];
{deleteVehicle _x} forEach allDeadMen;
sleep 5;
["info",[localize "STR_DUWS_T_zhixian",localize "STR_DUWS_T_6mg3jdt8"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated];