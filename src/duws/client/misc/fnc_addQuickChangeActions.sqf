// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
/*
    fnc_addQuickChangeActions.sqf
    参数: _crate - 补给箱对象
    功能: 为补给箱添加快速换装菜单（客户端执行）。
          换装列表来自服务器扫描并广播的 loadouts 数据。
*/
#include "..\..\shared\includes\action_style.hpp"

params ["_crate"];
if (!hasInterface) exitWith {};
if (isNull _crate) exitWith {};

// 等待数据可用（服务器端已扫描并广播）
waitUntil {sleep 0.1; !isNil "blufor_quickChange_loadouts_scanned"};

// 防重：移除可能已存在的动作
private _actionAID = _crate getVariable ["quickChange_actionA", -1];
if (_actionAID != -1) then { _crate removeAction _actionAID; };

_actionAID = _crate addAction [
    ACT_EQUIP("STR_DUWS_T_QUICK_KITS"),
    { [] call fnc_quick_kits_menu; },
    [],
    80,
    true,
    true,
    "",
    "_this distance _target < 3"
];
_crate setVariable ["quickChange_actionA", _actionAID];
