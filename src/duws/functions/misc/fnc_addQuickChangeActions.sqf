/*
    fnc_addQuickChangeActions.sqf
    参数: _crate - 补给箱对象
    功能: 为补给箱添加快速换装菜单（客户端执行）。
          换装列表来自服务器扫描并广播的 loadouts 数据。
*/
params ["_crate"];
if (!hasInterface) exitWith {};
if (isNull _crate) exitWith {};

// 等待数据可用（服务器端已扫描并广播）
waitUntil {sleep 0.1; !isNil "blufor_quickChange_loadouts_scanned"};

// 防重：移除可能已存在的动作
private _actionAID = _crate getVariable ["quickChange_actionA", -1];
if (_actionAID != -1) then { _crate removeAction _actionAID; };

_actionAID = _crate addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_QUICK_KITS"],
    {
        private _loadouts = missionNamespace getVariable ["blufor_quickChange_loadouts_scanned", []];
        private _entries = _loadouts apply {
            _x params ["_className", "_displayName", "_loadout"];
            [
                format [localize "STR_DUWS_T_CHANGE_TO", _displayName],
                {
                    params ["_loadout", "_displayName"];
                    player setUnitLoadout _loadout;
                    hint format [localize "STR_DUWS_T_CHANGED_TO", _displayName];
                },
                [_loadout, _displayName]
            ]
        };
        [localize "STR_DUWS_T_QUICK_KITS", _entries] call fnc_open_action_menu;
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];
_crate setVariable ["quickChange_actionA", _actionAID];
