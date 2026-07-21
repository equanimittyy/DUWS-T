// fnc_addHQOfficerActions.sqf
if (!hasInterface) exitWith {};

params ["_officer"];

if (isNull _officer) exitWith {};

// 防重
if (_officer getVariable ["officer_actions_done", false]) exitWith {};
_officer setVariable ["officer_actions_done", true];

if ((vehiclevarname player) in Request_Players) then {
    _officer addAction [localize "STR_DUWS_T_l0xark5g", fnc_squad_manage, "", 0, true, true, "", "_this == player && {_this distance _target < 3}"];
    _officer addAction [localize "STR_DUWS_T_4jabuvz6", fnc_groupReset, "", 0, true, true, "", "_this == player && {_this distance _target < 3}"];
};

// ========== 新增：可折叠帮助菜单 ==========
// 每个客户端独立管理自己的帮助动作ID列表
_officer setVariable ["help_action_ids", []];
_officer setVariable ["help_menu_expanded", false];

// 添加抽屉动作（始终显示）
private _drawerActionID = _officer addAction [
    localize "STR_DUWS_T_HELP_MENU",  // 需要在stringtable中定义
    {
        params ["_target", "_caller", "_actionId"];
        [_target, _caller] call fnc_toggleHelpActions;
    },
    nil,
    0,
    false,
    true,
    "",
    "_this distance _target < 3"
];
_officer setVariable ["help_drawer_action_id", _drawerActionID];

// 定义切换函数（客户端本地函数）
fnc_toggleHelpActions = {
    params ["_officer", "_caller"];
    
    private _expanded = _officer getVariable ["help_menu_expanded", false];
    private _actionIDs = _officer getVariable ["help_action_ids", []];
    
    if (!_expanded) then {
        // 展开：添加额外帮助动作
        private _newIDs = [];
        
        // 帮助条目1：关于经济系统
        private _id1 = _officer addAction [
            localize "STR_DUWS_T_HELP_ECO",
            {
                hint localize "STR_DUWS_T_HELP_ECO_HINT";
            },
            nil,
            0,
            false,
            true,
            "",
            "_this distance _target < 3"
        ];
        _newIDs pushBack _id1;
        
        // 帮助条目2：关于战区占领
        private _id2 = _officer addAction [
            localize "STR_DUWS_T_HELP_ZONES",
            {
                hint localize "STR_DUWS_T_HELP_ZONES_HINT";
            },
            nil,
            0,
            false,
            true,
            "",
            "_this distance _target < 3"
        ];
        _newIDs pushBack _id2;
        
        // 帮助条目3：关于支援呼叫
        private _id3 = _officer addAction [
            localize "STR_DUWS_T_HELP_SUPPORTS",
            {
                hint localize "STR_DUWS_T_HELP_SUPPORTS_HINT";
            },
            nil,
            0,
            false,
            true,
            "",
            "_this distance _target < 3"
        ];
        _newIDs pushBack _id3;
        
        // 可以继续添加更多...
        
        _officer setVariable ["help_action_ids", _newIDs];
        _officer setVariable ["help_menu_expanded", true];
        
        // 修改抽屉动作文本为“关闭帮助菜单”
        private _drawerID = _officer getVariable ["help_drawer_action_id", -1];
        if (_drawerID != -1) then {
            _officer removeAction _drawerID;
            private _newDrawerID = _officer addAction [
                localize "STR_DUWS_T_HELP_MENU_CLOSE",
                {
                    params ["_target", "_caller", "_actionId"];
                    [_target, _caller] call fnc_toggleHelpActions;
                },
                nil,
                0,
                false,
                true,
                "",
                "_this distance _target < 3"
            ];
            _officer setVariable ["help_drawer_action_id", _newDrawerID];
        };
    } else {
        // 折叠：移除所有额外帮助动作
        {
            _officer removeAction _x;
        } forEach _actionIDs;
        _officer setVariable ["help_action_ids", []];
        _officer setVariable ["help_menu_expanded", false];
        
        // 恢复抽屉动作文本为“帮助菜单”
        private _drawerID = _officer getVariable ["help_drawer_action_id", -1];
        if (_drawerID != -1) then {
            _officer removeAction _drawerID;
            private _newDrawerID = _officer addAction [
                localize "STR_DUWS_T_HELP_MENU",
                {
                    params ["_target", "_caller", "_actionId"];
                    [_target, _caller] call fnc_toggleHelpActions;
                },
                nil,
                0,
                false,
                true,
                "",
                "_this distance _target < 3"
            ];
            _officer setVariable ["help_drawer_action_id", _newDrawerID];
        };
    };
};

// 公开函数以便JIP客户端调用（如果需要在其他地方使用）
publicVariable "fnc_toggleHelpActions";