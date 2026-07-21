if (!hasInterface) exitWith {};
params ["_depot", "_trgNetId"];
if (isNull _depot) exitWith {};

// 防重添加
if (_depot getVariable ["repair_actions_done", false]) exitWith {};
_depot setVariable ["repair_actions_done", true, true];

private _trg = objectFromNetId _trgNetId;
if (isNull _trg) exitWith { diag_log "[REPAIR] Trigger null on client"; };

// 1. 修理
_depot addAction [
    localize "STR_DUWS_T_repair_vehicle",
    { params ["_t", "_c", "_i", "_trg"]; [_c, _trg] remoteExec ["fnc_veh_repair_action", 2]; },
    _trg, 6, true, true, "",
    "_this distance _target < 8"
];

// 2. 载具状态检查
_depot addAction [
    localize "STR_DUWS_T_check_vehicle_status",
    { params ["_t", "_c", "_i", "_trg"]; [_c, netId _trg] remoteExec ["fnc_veh_repair_check_status", 2]; },
    _trg, 5, true, true, "",
    "_this distance _target < 8"
];

// 3. 调整载具外观/挂件（刷新列表版）
_depot addAction [
    localize "STR_DUWS_T_vehicle_appearance",
    {
        params ["_t", "_c", "_i", "_trg"];
        private _vehicles = _trg nearEntities [["Car", "Tank", "Air", "Ship"], 5];
        private _veh = _vehicles param [0, objNull];
        if (isNull _veh) exitWith {
            hint localize "STR_DUWS_T_vehicle_garage_no_vehicle";
        };

        disableSerialization;
        private _display = createDialog ["RscDisplayEmpty", false];
        private _listbox = _display ctrlCreate ["RscListBox", 1500];
        _listbox ctrlSetPosition [0.3, 0.22, 0.4, 0.4];
        _listbox ctrlCommit 0;

        // 涂装列表（不会变，不用刷新）
        private _textures = ("true" configClasses (configFile >> "CfgVehicles" >> typeOf _veh >> "TextureSources")) apply {configName _x};
        { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;

        // 只有 source == "user" 的动画源
        private _animations = ("true" configClasses (configFile >> "CfgVehicles" >> typeOf _veh >> "AnimationSources")) select {
            getText (_x >> "source") == "user"
        } apply {configName _x};

        // 填充动画源并刷新列表的函数
        private _fnc_refreshAnimList = {
            lbClear _listbox;
            // 重新加涂装
            { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;
            // 重新加动画源状态
            {
                private _state = _veh animationSourcePhase _x;
                private _label = if (_state > 0) then { format ["%1 (ON)", _x] } else { format ["%1 (OFF)", _x] };
                _listbox lbAdd _label;
            } forEach _animations;
            lbSetCurSel [1500, 0];
        };

        // 初始填充
        call _fnc_refreshAnimList;

        _display setVariable ["garage_veh", _veh];
        _display setVariable ["garage_animList", _animations];
        _display setVariable ["garage_textureList", _textures];

        // Apply 按钮（不关闭，刷新列表）
        private _applyBtn = _display ctrlCreate ["RscButton", 1600];
        _applyBtn ctrlSetText "Apply";
        _applyBtn ctrlSetPosition [0.35, 0.67, 0.1, 0.05];
        _applyBtn ctrlCommit 0;
        _applyBtn ctrlAddEventHandler ["ButtonClick", {
            private _parent = ctrlParent (_this select 0);
            private _veh = _parent getVariable ["garage_veh", objNull];
            if (isNull _veh) exitWith {};
            private _idx = lbCurSel 1500;
            private _text = lbText [1500, _idx];
            if (_text find "Texture:" != -1) then {
                private _texName = (_text splitString ": ") select 1;
                [_veh, _texName] call BIS_fnc_initVehicle;
            } else {
                private _animName = (_text splitString " (") select 0;
                private _state = _veh animationSourcePhase _animName;
                _veh animateSource [_animName, if (_state > 0) then {0} else {1}, true];
            };
            // 刷新列表以显示新的 ON/OFF 状态
            private _animations = _parent getVariable ["garage_animList", []];
            private _textures = _parent getVariable ["garage_textureList", []];
            private _listbox = _parent displayCtrl 1500;
            lbClear _listbox;
            { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;
            {
                private _state = _veh animationSourcePhase _x;
                private _label = if (_state > 0) then { format ["%1 (ON)", _x] } else { format ["%1 (OFF)", _x] };
                _listbox lbAdd _label;
            } forEach _animations;
            lbSetCurSel [1500, 0];
        }];

        // Close 按钮
        private _closeBtn = _display ctrlCreate ["RscButton", 1601];
        _closeBtn ctrlSetText "Close";
        _closeBtn ctrlSetPosition [0.55, 0.67, 0.1, 0.05];
        _closeBtn ctrlCommit 0;
        _closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
    },
    _trg,
    6,
    true,
    true,
    "",
    "_this distance _target < 8"
];

// 4. 调整载具挂架 (Pylons) 消耗5CP版
_depot addAction [
    localize "STR_DUWS_T_vehicle_pylons",
    {
        params ["_t", "_c", "_i", "_trg"];
        private _vehicles = _trg nearEntities [["Air"], 5];
        private _veh = _vehicles param [0, objNull];
        if (isNull _veh) exitWith {
            hint localize "STR_DUWS_T_vehicle_garage_no_vehicle";
        };

        disableSerialization;
        private _display = createDialog ["RscDisplayEmpty", false];
// ---- 挂架费用提示（带背景）----
private _txtHint = _display ctrlCreate ["RscText", 1000];
_txtHint ctrlSetPosition [0.2, 0.15, 0.6, 0.04];
_txtHint ctrlSetText (localize "STR_DUWS_T_PYLON_COST_HINT");
_txtHint ctrlSetBackgroundColor [0, 0, 0, 0.3];   // 淡黑色半透明背景
_txtHint ctrlCommit 0;
        private _lbPylons = _display ctrlCreate ["RscListBox", 1500];
        _lbPylons ctrlSetPosition [0.2, 0.2, 0.25, 0.5];
        _lbPylons ctrlCommit 0;

        private _lbCompatible = _display ctrlCreate ["RscListBox", 1501];
        _lbCompatible ctrlSetPosition [0.5, 0.2, 0.3, 0.5];
        _lbCompatible ctrlCommit 0;

        _display setVariable ["garage_veh", _veh];

        private _pylonNamesRaw = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "pylonTopCover");
        private _pylonNames = if (_pylonNamesRaw != "") then { _pylonNamesRaw splitString ";" } else { [] };

        // ---- 辅助函数：获取挂架的 turret 路径（默认使用载具本体 []）----
        private _fnc_getPylonTurret = {
            params ["_veh", "_pylonIndex"];
            private _pylonConfig = configFile >> "CfgVehicles" >> typeOf _veh >> "Components" >> "TransportPylonsComponent" >> "Pylons" >> format ["Pylon%1", _pylonIndex];
            if (isClass _pylonConfig) then {
                private _turret = getArray (_pylonConfig >> "turret");
                if (count _turret == 0) then { [] } else { _turret };
            } else {
                []
            };
        };

        // ---- 核心刷新函数（左侧列表 + 右侧兼容）----
        private _fnc_refreshAll = {
            private _veh = _display getVariable "garage_veh";
            if (isNull _veh) exitWith {};

            private _leftIdx = lbCurSel _lbPylons;
            private _rightIdx = lbCurSel _lbCompatible;
            if (_leftIdx < 0) then { _leftIdx = 0 };

            private _pylonMags = getPylonMagazines _veh;
            lbClear _lbPylons;
            {
                private _idx = _forEachIndex;
                private _pylonName = if (count _pylonNames > _idx) then { _pylonNames select _idx } else { format ["Pylon %1", _idx + 1] };
                private _mag = _x;
                private _displayName = if (_mag != "") then {
                    getText (configFile >> "CfgMagazines" >> _mag >> "displayName")
                } else {
                    localize "STR_DUWS_T_empty"
                };
                _lbPylons lbAdd format ["%1: %2", _pylonName, _displayName];
            } forEach _pylonMags;

            if (_leftIdx >= lbSize _lbPylons) then { _leftIdx = 0 };
            lbSetCurSel [1500, _leftIdx];

            // 刷新右侧兼容列表（使用 1-based pylon index）
            private _pylonIndex = _leftIdx + 1;
            private _compatibleMags = _veh getCompatiblePylonMagazines _pylonIndex;
            private _flat = [];
            {
                if (_x isEqualType "") then {
                    if (_x != "") then { _flat pushBack _x };
                } else {
                    if (_x isEqualType []) then {
                        { if (_x != "") then { _flat pushBack _x } } forEach _x;
                    };
                };
            } forEach _compatibleMags;

            lbClear _lbCompatible;
            _lbCompatible lbAdd localize "STR_DUWS_T_empty";
            if (count _flat == 0) then {
                _lbCompatible lbAdd localize "STR_DUWS_T_no_weapons_available";
            } else {
                { _lbCompatible lbAdd getText (configFile >> "CfgMagazines" >> _x >> "displayName") } forEach _flat;
            };

            if (_rightIdx < 0 || _rightIdx >= lbSize _lbCompatible) then { _rightIdx = 0 };
            lbSetCurSel [1501, _rightIdx];
        };

        _display setVariable ["refreshFn", _fnc_refreshAll];

        // 左侧选中事件
        _lbPylons ctrlAddEventHandler ["LBSelChanged", {
            params ["_ctrl", "_newIdx"];
            private _display = ctrlParent _ctrl;
            private _veh = _display getVariable "garage_veh";
            if (isNull _veh) exitWith {};
            private _lbCompatible = _display displayCtrl 1501;
            lbClear _lbCompatible;

            private _pylonIndex = _newIdx + 1;
            private _compatibleMags = _veh getCompatiblePylonMagazines _pylonIndex;
            private _flat = [];
            {
                if (_x isEqualType "") then {
                    if (_x != "") then { _flat pushBack _x };
                } else {
                    if (_x isEqualType []) then {
                        { if (_x != "") then { _flat pushBack _x } } forEach _x;
                    };
                };
            } forEach _compatibleMags;

            _lbCompatible lbAdd localize "STR_DUWS_T_empty";
            if (count _flat == 0) then {
                _lbCompatible lbAdd localize "STR_DUWS_T_no_weapons_available";
            } else {
                { _lbCompatible lbAdd getText (configFile >> "CfgMagazines" >> _x >> "displayName") } forEach _flat;
            };
            lbSetCurSel [1501, 0];
        }];

        // 初始填充
        call _fnc_refreshAll;

        // ----- Mount 按钮 -----
        private _mountBtn = _display ctrlCreate ["RscButton", 1600];
        _mountBtn ctrlSetText "Mount";
        _mountBtn ctrlSetPosition [0.6, 0.75, 0.1, 0.05];
        _mountBtn ctrlCommit 0;
        _mountBtn ctrlAddEventHandler ["ButtonClick", {
            private _display = ctrlParent (_this select 0);
            private _veh = _display getVariable "garage_veh";
            if (isNull _veh) exitWith {};
            private _pylonIdx = lbCurSel 1500;
            private _magIdx = lbCurSel 1501;
            if (_pylonIdx < 0 || _magIdx < 0) exitWith { hint "Select pylon and weapon" };

            private _pylonIndex = _pylonIdx + 1;
            private _compatibleMags = _veh getCompatiblePylonMagazines _pylonIndex;
            private _flat = [];
            {
                if (_x isEqualType "") then {
                    if (_x != "") then { _flat pushBack _x };
                } else {
                    if (_x isEqualType []) then {
                        { if (_x != "") then { _flat pushBack _x } } forEach _x;
                    };
                };
            } forEach _compatibleMags;

            private _selectedMag = if (_magIdx == 0) then { "" } else { _flat select (_magIdx - 1) };
            private _turret = [_veh, _pylonIndex] call _fnc_getPylonTurret;

            // 调用服务器函数（扣 CP 并设置挂架）
            [netId _veh, _pylonIndex, _selectedMag, _turret, getPlayerUID player] remoteExec ["fnc_pylon_set_with_cost", 2];

            // 等待服务器完成，然后刷新界面
            (_this select 0) spawn {
                params ["_ctrl"];
                uiSleep 0.1;
                private _display = ctrlParent _ctrl;
                if (!isNull _display) then {
                    private _veh = _display getVariable ["garage_veh", objNull];
                    if (isNull _veh) exitWith {};
                    private _lbPylons = _display displayCtrl 1500;
                    private _pylonNamesRaw = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "pylonTopCover");
                    private _pylonNames = if (_pylonNamesRaw != "") then { _pylonNamesRaw splitString ";" } else { [] };
                    private _pylonMags = getPylonMagazines _veh;
                    lbClear _lbPylons;
                    {
                        private _pylonName = if (count _pylonNames > _forEachIndex) then { _pylonNames select _forEachIndex } else { format ["Pylon %1", _forEachIndex + 1] };
                        private _displayName = if (_x != "") then {
                            getText (configFile >> "CfgMagazines" >> _x >> "displayName")
                        } else {
                            localize "STR_DUWS_T_empty"
                        };
                        _lbPylons lbAdd format ["%1: %2", _pylonName, _displayName];
                    } forEach _pylonMags;
                    lbSetCurSel [1500, 0];

                    // 刷新右侧列表（pylon 1）
                    private _compatibleMags = _veh getCompatiblePylonMagazines 1;
                    private _flat = [];
                    {
                        if (_x isEqualType "") then {
                            if (_x != "") then { _flat pushBack _x };
                        } else {
                            if (_x isEqualType []) then {
                                { if (_x != "") then { _flat pushBack _x } } forEach _x;
                            };
                        };
                    } forEach _compatibleMags;
                    private _lbCompatible = _display displayCtrl 1501;
                    lbClear _lbCompatible;
                    _lbCompatible lbAdd localize "STR_DUWS_T_empty";
                    if (count _flat == 0) then {
                        _lbCompatible lbAdd localize "STR_DUWS_T_no_weapons_available";
                    } else {
                        { _lbCompatible lbAdd getText (configFile >> "CfgMagazines" >> _x >> "displayName") } forEach _flat;
                    };
                    lbSetCurSel [1501, 0];
                };
            };
        }];

        // ----- Close 按钮 -----
        private _closeBtn = _display ctrlCreate ["RscButton", 1602];
        _closeBtn ctrlSetText "Close";
        _closeBtn ctrlSetPosition [0.35, 0.85, 0.3, 0.05];
        _closeBtn ctrlCommit 0;
        _closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
    },
    _trg,
    6,
    true,
    true,
    "",
    "_this distance _target < 8"
];