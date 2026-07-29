// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
#include "..\includes\action_style.hpp"

_fob = _this select 0;
_fob_owner = _this select 1;
// 防重
if (_fob getVariable ["FOB_actions_done", false]) exitWith {};
_fob setVariable ["FOB_actions_done", true];
if ((vehiclevarname player) in Squad_Leaders) then {
    _fob addaction [ACT_PRIMARY_MENU("STR_DUWS_T_vw32hahc"),fnc_FOB_Request_Menu, [], 100, true, true, "", "_this == player"];
    _fob addaction [ACT_PRIMARY_MENU("STR_DUWS_T_l0xark5g"),fnc_squad_manage, [], 100, true, true, "", "_this == player"];
};
    
_fob addaction [ACT_PRIMARY_MENU("STR_DUWS_T_iggpsdqo"),fnc_FOBmanager, [], 100, true, true, "", "_this == player"];
    
if (support_armory_available) then {
    _fob addaction [ACT_EQUIP("STR_DUWS_T_160jkc3a"),fnc_duws_Arsenal, [], 80, true, true, "", "_this == player"];
};

if (support_halo_available) then {
    _fob addAction [ACT_MOVE("STR_DUWS_T_foldimok"), fnc_ghst_halo, [false,600,70], 70, true, true, "","_this == player"];
    if ((vehiclevarname player) in Squad_Leaders) then {
        _fob addAction [ACT_MOVE("STR_DUWS_T_u6btu73i"), fnc_ghst_halo, [true,600,70], 70, true, true, "","_this == player"];
        _fob addAction [ACT_MOVE("STR_DUWS_T_halo_ai_only"), fnc_ghst_halo, [true,600,70,true], 70, true, true, "","_this == player"];
    };  
};

if ((vehiclevarname player) in game_master) then {
    // 给全局治愈功能添加10分钟（600秒）冷却时间 + 多人联机强制同步
    _fob addaction [
        ACT_AID("STR_DUWS_T_9eiwr3bt"),  // 本地化菜单名称
        {  // 重构匿名函数，添加冷却校验+联机同步逻辑
            // 1. 定义核心变量
            private _coolDownVar = "GM_Heal_LastUsedTime";  // 全局冷却记录变量名
            private _coolDownSeconds = 600;  // 10分钟=600秒
            private _currentTime = time;  // 获取当前游戏时间（秒）
            private _lastUsedTime = MissionNamespace getVariable [_coolDownVar, 0];  // 获取本地已记录的上次使用时间
            
            // 2. 冷却时间校验
            if (_currentTime - _lastUsedTime >= _coolDownSeconds) then {
                // 3. 满足条件，执行全局治愈逻辑
                [] remoteExec ["fnc_rest_heal", 2];
                
                // 4. 更新当前端的全局冷却记录变量（先赋值，再同步）
                MissionNamespace setVariable [_coolDownVar, _currentTime];
                
                // 5. 强制同步该变量到所有联机端
                publicVariable _coolDownVar;
                _speakeracteam = localize "STR_DUWS_T_actionteam";
                _message = ([localize "STR_DUWS_T_restsuccess"] call fnc_cs);
                [_speakeracteam, _message] remoteExec ["fnc_duws_dialogue", 0];
            } else {
                _speaker = localize "STR_DUWS_T_OVERLORD";
                _message1 = localize "STR_DUWS_T_restcooldown";
                [_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
                hint (localize "STR_DUWS_T_restcooldownhint");
            };
        },
        "",         
        60,         
        true, true, "", "_this == player"
    ];
};

[_fob,[ACT_AID("STR_DUWS_T_xfgokhbc"),fnc_AI_rearm,[], 60, false, false, "", "_this distance _target < 12"]] remoteExec ["addAction", [0,-2] select isDedicated, _fob];
// === 显示所有任务冷却（仅限 player1） ===
_fob addaction [
    ACT_UTIL("STR_DUWS_T_SHOW_MISSION_COOLDOWNS"),
    {
        private _lines = [];
        private _missionTypes = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
        private _version = VERSION_X;
        private _currentTime = diag_tickTime;

        {
            private _type = _x;
            private _cooldownVar = missionNamespace getVariable [format ["mission_cooldown_%1", _type], 0];
            private _remaining = 0;
            if (_cooldownVar > _currentTime) then {
                _remaining = _cooldownVar - _currentTime;
            };
            private _minutes = floor (_remaining / 60);
            private _seconds = _remaining % 60;

            // 根据任务类型获取本地化名称
            private _missionName = "";
            switch (_type) do {
                case 0: { _missionName = localize "STR_DUWS_T_c0"; };
                case 1: { _missionName = localize "STR_DUWS_T_c1"; };
                case 2: { _missionName = localize "STR_DUWS_T_c2"; };
                case 3: {
                    switch (_version) do {
                        case "MODERN":  { _missionName = localize "STR_DUWS_T_c3"; };
                        default         { _missionName = localize "STR_DUWS_T_c3"; };
                    };
                };
                case 4: { _missionName = localize "STR_DUWS_T_c4"; };
                case 5: { _missionName = localize "STR_DUWS_T_c5"; };
                case 6: { _missionName = localize "STR_DUWS_T_c6"; };
                case 7: { _missionName = localize "STR_DUWS_T_c7"; };
                case 8: {
                    switch (_version) do {
                        case "MODERN":  { _missionName = localize "STR_DUWS_T_c8"; };
                        default         { _missionName = localize "STR_DUWS_T_c8"; };
                    };
                };
                case 9: { _missionName = localize "STR_DUWS_T_c9"; };
                case 10: {
                    switch (_version) do {
                        case "MODERN":  { _missionName = localize "STR_DUWS_T_c10"; };
                        default         { _missionName = localize "STR_DUWS_T_c10"; };
                    };
                };
                case 11: { _missionName = localize "STR_DUWS_T_c11"; };
                case 12: { _missionName = localize "STR_DUWS_T_c12"; };
                case 13: { _missionName = localize "STR_DUWS_T_c13"; };
                case 14: { _missionName = localize "STR_DUWS_T_c14"; };
                case 15: { _missionName = localize "STR_DUWS_T_c15"; };
                case 16: { _missionName = localize "STR_DUWS_T_c16"; };
                default { _missionName = format [localize "STR_DUWS_T_UNKNOWN_MISSION", _type]; };
            };

            private _line = if (_remaining <= 0) then {
                format ["%1: %2", _missionName, localize "STR_DUWS_T_COOLDOWN_READY"]
            } else {
                format ["%1: %2min%3sec", _missionName, _minutes, _seconds]
            };
            _lines pushBack _line;
        } forEach _missionTypes;

        hint (_lines joinString "\n");
    },
    [],
    20,
    true,
    true,
    "",
    "(vehiclevarname player) == 'player1'"  // 仅 player1 可见
];

waitUntil {sleep 600;!alive blu_officer_object};
removeAllActions _fob;