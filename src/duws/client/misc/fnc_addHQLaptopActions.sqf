// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
/*
    fnc_addHQLaptopActions.sqf
    参数: _laptop - 笔记本电脑对象
    由服务器远程调用，在每个客户端为笔记本电脑添加交互动作
*/
if (!hasInterface) exitWith {};

params ["_laptop"];

if (isNull _laptop) exitWith {};

// 去重：检查是否已添加过动作
if (!isNil {_laptop getVariable "laptop_actions_done"}) exitWith {};
_laptop setVariable ["laptop_actions_done", true];

// 添加招募菜单
_laptop addAction [localize "STR_DUWS_T_vw32hahc", fnc_HQ_Request_Menu, "", 100, true, true, "", "_this == player"];

// 添加显示任务冷却
_laptop addAction [
    localize "STR_DUWS_T_SHOW_MISSION_COOLDOWNS",
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

            private _missionName = switch (_type) do {
                case 0: { localize "STR_DUWS_T_c0" };
                case 1: { localize "STR_DUWS_T_c1" };
                case 2: { localize "STR_DUWS_T_c2" };
                case 3: {
                    switch (VERSION_X) do {
                        case "MODERN":  { localize "STR_DUWS_T_c3" };
                        case "WW2":     { localize "STR_DUWS_T_c3" };
                        case "VIETNAM": { localize "STR_DUWS_T_c3" };
                        default         { localize "STR_DUWS_T_c3" };
                    };
                };
                case 4: { localize "STR_DUWS_T_c4" };
                case 5: { localize "STR_DUWS_T_c5" };
                case 6: { localize "STR_DUWS_T_c6" };
                case 7: { localize "STR_DUWS_T_c7" };
                case 8: {
                    switch (VERSION_X) do {
                        case "MODERN":  { localize "STR_DUWS_T_c8" };
                        case "WW2":     { localize "STR_DUWS_T_c8" };
                        case "VIETNAM": { localize "STR_DUWS_T_c8" };
                        default         { localize "STR_DUWS_T_c8" };
                    };
                };
                case 9: { localize "STR_DUWS_T_c9" };
                case 10: {
                    switch (VERSION_X) do {
                        case "MODERN":  { localize "STR_DUWS_T_c10" };
                        case "VIETNAM": { localize "STR_DUWS_T_c10" };
                        default         { localize "STR_DUWS_T_c10" };
                    };
                };
                case 11: { localize "STR_DUWS_T_c11" };
                case 12: { localize "STR_DUWS_T_c12" };
                case 13: { localize "STR_DUWS_T_c13" };
                case 14: { localize "STR_DUWS_T_c14" };
                case 15: { localize "STR_DUWS_T_c15" };
                case 16: { localize "STR_DUWS_T_c16" };
                default { format [localize "STR_DUWS_T_UNKNOWN_MISSION", _type] };
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
    "",
    0,
    true,
    true,
    "",
    "(vehiclevarname player) == 'player1'"
];

// 添加 FOB 管理
_laptop addAction [localize "STR_DUWS_T_iggpsdqo", fnc_FOBmanager, "", 0, true, true, "", "_this == player"];
