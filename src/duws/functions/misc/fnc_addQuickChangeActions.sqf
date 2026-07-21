/*
    fnc_addQuickChangeActions.sqf
    参数: _crate - 补给箱对象
    功能: 为补给箱添加快速换装动作（客户端执行）
    修改：使用通过扫描获得的 loadouts 数据。
*/
params ["_crate"];
if (!hasInterface) exitWith {};
if (isNull _crate) exitWith {};

// 等待数据可用（服务器端已扫描并广播）
waitUntil {sleep 0.1; !isNil "blufor_quickChange_loadouts_scanned"};

// 移除可能已存在的动作A
private _actionAID = _crate getVariable ["quickChange_actionA", -1];
if (_actionAID != -1) then { _crate removeAction _actionAID; };

// 添加动作A
_actionAID = _crate addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_QUICK_CHANGE"],
    {
        params ["_target", "_caller", "_actionId"];
        private _crate = _target;
        // 获取之前添加的换装动作ID列表并移除
        private _actionIDs = _crate getVariable ["quickChange_actions", []];
        { _crate removeAction _x; } forEach _actionIDs;
        _actionIDs = [];
        // 获取loadout数据
        private _loadouts = missionNamespace getVariable ["blufor_quickChange_loadouts_scanned", []];
        {
            _x params ["_className", "_displayName", "_loadout"];
            private _actionID = _crate addAction [
                format ["<t color='#ffff00'>%1</t>", format [localize "STR_DUWS_T_CHANGE_TO", _displayName]],
                {
                    params ["_target", "_caller", "_actionId", "_arguments"];
                    _arguments params ["_loadout", "_displayName"];
                    _caller setUnitLoadout _loadout;
                    hint format [localize "STR_DUWS_T_CHANGED_TO", _displayName];
                },
                [_loadout, _displayName],
                6,
                true,
                true,
                "",
    "_this distance _target < 3"
            ];
            _actionIDs pushBack _actionID;
        } forEach _loadouts;
        _crate setVariable ["quickChange_actions", _actionIDs];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];
_crate setVariable ["quickChange_actionA", _actionAID];