/*
    fnc_addFaceChangeAction.sqf
    为补给箱添加“更换皮肤”动作，点击后随机更换玩家面部
    执行端：客户端
    参数：_crate - 补给箱对象
*/
if (!hasInterface) exitWith {};
params ["_crate"];
if (isNull _crate) exitWith {};
if (_crate getVariable ["faceChangeActionAdded", false]) exitWith {};
_crate setVariable ["faceChangeActionAdded", true];

_crate addAction [
    localize "STR_DUWS_T_CHANGE_FACE",
    {
        [getPlayerUID player] remoteExec ["fnc_changeFaceServer", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];