// Locality: server only (remoteExec target 2). Caller: the stance button in client/dialog/fnc_taskforce_list.sqf.
if (!isServer) exitWith {};
params ["_stance"];
if !(_stance in [0, 1, 2]) exitWith {};
DUWS_taskforce_stance = _stance;
publicVariable "DUWS_taskforce_stance";
private _line = localize (["STR_DUWS_T_TASKFORCE_STANCE_SET_ATTACK", "STR_DUWS_T_TASKFORCE_STANCE_SET_BALANCED", "STR_DUWS_T_TASKFORCE_STANCE_SET_DEFEND"] select _stance);
[localize "STR_DUWS_T_OVERLORD", _line] remoteExec ["fnc_duws_dialogue", 0];
