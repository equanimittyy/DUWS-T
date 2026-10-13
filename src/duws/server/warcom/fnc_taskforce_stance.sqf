// Locality: server only (remoteExec target 2). Caller: the stance button in client/dialog/fnc_taskforce_list.sqf.
if (!isServer) exitWith {};
params ["_stance"];
if !(_stance in [0, 1, 2]) exitWith {};
DUWS_taskforce_stance = _stance;
publicVariable "DUWS_taskforce_stance";
private _label = localize (["STR_DUWS_T_TASKFORCE_STANCE_ATTACK", "STR_DUWS_T_TASKFORCE_STANCE_BALANCED", "STR_DUWS_T_TASKFORCE_STANCE_DEFEND"] select _stance);
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_STANCE_SET", _label]] remoteExec ["fnc_duws_dialogue", 0];
