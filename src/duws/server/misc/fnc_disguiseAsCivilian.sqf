// functions\misc\fnc_disguiseAsCivilian.sqf
if (!isServer) exitWith {};

params ["_player"];
if (isNull _player) exitWith {};

// ========== 辅助函数：发送失败提示 ==========
fnc_disguise_hintFail = {
    params ["_player", "_reasonKey"];
    [format [localize "STR_DUWS_T_DISGUISE_FAIL_HINT", localize _reasonKey]] remoteExec ["hint", _player];
};
publicVariable "fnc_disguise_hintFail";

// ========== 平民载具白名单 ==========
private _civilianVehicles = [
    "C_Van_01_fuel_F", "C_Van_01_box_F", "C_Van_01_transport_F",
    "C_Tractor_01_F", "C_Hatchback_01_sport_F", "C_Hatchback_01_F",
    "C_Offroad_01_covered_F", "C_Offroad_01_comms_F", "C_Offroad_01_repair_F",
    "C_Offroad_01_F", "C_Van_02_transport_F", "C_Van_02_medevac_F",
    "C_Van_02_service_F", "C_Van_02_vehicle_F", "C_Offroad_02_unarmed_F",
    "C_Truck_02_fuel_F", "C_Truck_02_box_F", "C_Truck_02_covered_F",
    "C_Truck_02_transport_F"
];

// ========== 冷却检查 ==========
private _lastUse = _player getVariable ["DUWS_disguise_lastUse", -300];
private _cooldownRemaining = 300 - (diag_tickTime - _lastUse);
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_DISGUISE_COOLDOWN_FMT", _minutes, _seconds];
    [_msg] remoteExec ["hint", _player];
};

// ========== 基础条件检查 ==========
private _veh = vehicle _player;
if (_veh != _player) then {
    private _vehType = typeOf _veh;
    if (!(_vehType in _civilianVehicles)) exitWith {
        [_player, "STR_DUWS_T_DISGUISE_IN_VEHICLE"] call fnc_disguise_hintFail;
    };
};

if (CIV_PRESENCE == "NONE") exitWith {};
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_ZOMBIE_MODE"] call fnc_disguise_hintFail;
};

// ========== 钱币和情报检查已移除 ==========
// 原代码在此处检查 _forbiddenItems，现已删除

// ========== 等待平民装备缓存 ==========
private _timeout = diag_tickTime + 30;
waitUntil {
    sleep 0.1;
    (!isNil "DUWS_civUniforms" && !isNil "DUWS_civVests" && !isNil "DUWS_civHeadgear" && !isNil "DUWS_civBackpacks") || diag_tickTime > _timeout
};

if (isNil "DUWS_civUniforms" || isNil "DUWS_civVests" || isNil "DUWS_civHeadgear" || isNil "DUWS_civBackpacks") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_NO_CIV"] call fnc_disguise_hintFail;
};

private _civUniforms = DUWS_civUniforms;
private _civVests = DUWS_civVests;
private _civHeadgear = DUWS_civHeadgear;
private _civBackpacks = DUWS_civBackpacks;

// ========== 检查当前装束 ==========
if (primaryWeapon _player != "" || secondaryWeapon _player != "" || handgunWeapon _player != "") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_WEAPON"] call fnc_disguise_hintFail;
};

private _assignedItems = assignedItems _player;
if ("NVGoggles" in _assignedItems || "NVGoggles_OPFOR" in _assignedItems || "NVGoggles_INDEP" in _assignedItems) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_NVG"] call fnc_disguise_hintFail;
};

private _currentUniform = uniform _player;
if (_currentUniform == "") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_NAKED"] call fnc_disguise_hintFail;
};
if (!(_currentUniform in _civUniforms)) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_UNIFORM"] call fnc_disguise_hintFail;
};

private _currentVest = vest _player;
if (_currentVest != "" && {!(_currentVest in _civVests)}) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_VEST"] call fnc_disguise_hintFail;
};

private _currentHeadgear = headgear _player;
if (_currentHeadgear != "" && {!(_currentHeadgear in _civHeadgear)}) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_HEADGEAR"] call fnc_disguise_hintFail;
};

private _currentBackpack = backpack _player;
if (_currentBackpack != "" && {!(_currentBackpack in _civBackpacks)}) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_BROKEN_BACKPACK"] call fnc_disguise_hintFail;
};

// ========== 检查通过，开启伪装 ==========
_player setVariable ["DUWS_disguise_lastUse", diag_tickTime];
_player setVariable ["DUWS_disguise_startRep", missionNamespace getVariable ["Player_Reputation", 0]];
_player setVariable ["DUWS_disguised", true, true];
_player setCaptive true;
[true] remoteExec ["fnc_disguise_setCaptiveLocal", _player];

_player setVariable ["DUWS_disguise_warningActive", false, true];
_player setVariable ["DUWS_disguise_warningPos", nil, true];
_player setVariable ["DUWS_disguise_paused", false, true];
_player setVariable ["DUWS_disguise_validUniforms", _civUniforms];
_player setVariable ["DUWS_disguise_validVests", _civVests];
_player setVariable ["DUWS_disguise_validHeadgear", _civHeadgear];
_player setVariable ["DUWS_disguise_validBackpacks", _civBackpacks];
_player setVariable ["DUWS_disguise_civilianVehicles", _civilianVehicles];

["weizhuang", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_DISGUISE_ACTIVATED_DESC"]] remoteExec ["BIS_fnc_showNotification", _player];
[localize "STR_DUWS_T_DISGUISE_SUCCESS_HINT"] remoteExec ["hint", _player];

// ========== 启动监控线程 ==========
if (!(_player getVariable ["DUWS_disguise_monitorRunning", false])) then {
    _player setVariable ["DUWS_disguise_monitorRunning", true];
    
    private _firedEH = _player addEventHandler ["FiredMan", {
        params ["_unit"];
        if (_unit getVariable ["DUWS_disguised", false]) then {
            _unit setVariable ["DUWS_disguised", false, true];
            _unit setCaptive false;
            [false] remoteExec ["fnc_disguise_setCaptiveLocal", _unit];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_DISGUISE_BROKEN_THROW"]] remoteExec ["BIS_fnc_showNotification", _unit];
        };
    }];
    _player setVariable ["DUWS_disguise_firedEH", _firedEH];
    
    [_player] spawn {
        params ["_player"];
        
        private _alertDistance = 50 + random 30;
        _player setVariable ["DUWS_disguise_alertDist", _alertDistance];
        
        private _warningKeys = [
            "STR_DUWS_T_DISGUISE_WARNING_1",
            "STR_DUWS_T_DISGUISE_WARNING_2",
            "STR_DUWS_T_DISGUISE_WARNING_3",
            "STR_DUWS_T_DISGUISE_WARNING_4",
            "STR_DUWS_T_DISGUISE_WARNING_5"
        ];
        
        private _fnc_breakDisguise = {
            params ["_reasonKey"];
            if (_player getVariable ["DUWS_disguised", false]) then {
                _player setVariable ["DUWS_disguised", false, true];
                _player setCaptive false;
                [false] remoteExec ["fnc_disguise_setCaptiveLocal", _player];
                ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize _reasonKey]] remoteExec ["BIS_fnc_showNotification", _player];
            };
        };
        
        while {alive _player && {_player getVariable ["DUWS_disguised", false]}} do {
            if (_player getVariable ["DUWS_disguise_paused", false]) then {
                sleep 5;
                continue;
            };
            
            // 1. 武器
            if (primaryWeapon _player != "" || secondaryWeapon _player != "" || handgunWeapon _player != "") exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_WEAPON"] call _fnc_breakDisguise;
            };
            
            // 2. 手持望远镜 ———— 已移除 ————
            
            // 3. 夜视仪
            private _assigned = assignedItems _player;
            if ("NVGoggles" in _assigned || "NVGoggles_OPFOR" in _assigned || "NVGoggles_INDEP" in _assigned) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_NVG"] call _fnc_breakDisguise;
            };
            
            // 4. 光身子
            if (uniform _player == "") exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_NAKED"] call _fnc_breakDisguise;
            };
            
            // 5. 服装合规性
            private _invalidGear = false;
            private _breakReason = "";
            if (!(uniform _player in (_player getVariable ["DUWS_disguise_validUniforms", []]))) then {
                _invalidGear = true; _breakReason = "STR_DUWS_T_DISGUISE_BROKEN_NAKED";
            };
            private _vest = vest _player;
            if (!_invalidGear && _vest != "" && {!(_vest in (_player getVariable ["DUWS_disguise_validVests", []]))}) then {
                _invalidGear = true; _breakReason = "STR_DUWS_T_DISGUISE_BROKEN_NAKED";
            };
            private _headgear = headgear _player;
            if (!_invalidGear && _headgear != "" && {!(_headgear in (_player getVariable ["DUWS_disguise_validHeadgear", []]))}) then {
                _invalidGear = true; _breakReason = "STR_DUWS_T_DISGUISE_BROKEN_NAKED";
            };
            private _backpack = backpack _player;
            if (!_invalidGear && _backpack != "" && {!(_backpack in (_player getVariable ["DUWS_disguise_validBackpacks", []]))}) then {
                _invalidGear = true; _breakReason = "STR_DUWS_T_DISGUISE_BROKEN_NAKED";
            };
            if (_invalidGear) exitWith {
                [_breakReason] call _fnc_breakDisguise;
            };
            
            // 6. 尸体检测
            private _nearCorpses = _player nearObjects ["CAManBase", 20] select { !alive _x };
            if (count _nearCorpses > 0) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_CORPSE"] call _fnc_breakDisguise;
            };
            
            // 7. 战区距离 ———— 已移除 ————
            
            // 8. 距离敌人警告
            private _nearEnemies = _player nearEntities [["CAManBase"], _alertDistance] select { side _x == EAST && alive _x };
            private _warningActive = _player getVariable ["DUWS_disguise_warningActive", false];
            
            if (count _nearEnemies > 0) then {
                if (!_warningActive) then {
                    _player setVariable ["DUWS_disguise_warningActive", true, true];
                    _player setVariable ["DUWS_disguise_warningPos", getPos _player, true];
                    
                    private _warningKey = selectRandom _warningKeys;
                    [localize "STR_DUWS_T_DISGUISE_OPFOR_SPEAKER", localize _warningKey] remoteExec ["BIS_fnc_showSubtitle", _player];
                    [localize "STR_DUWS_T_DISGUISE_WARNING_HINT"] remoteExec ["hint", _player];
                } else {
                    private _warningPos = _player getVariable ["DUWS_disguise_warningPos", [0,0,0]];
                    if (_player distance _warningPos < _alertDistance * 1.5) exitWith {
                        ["STR_DUWS_T_DISGUISE_BROKEN_DISTANCE"] call _fnc_breakDisguise;
                    };
                    _player setVariable ["DUWS_disguise_warningActive", false, true];
                };
            } else {
                if (_warningActive) then {
                    _player setVariable ["DUWS_disguise_warningActive", false, true];
                };
            };
            
            if (!(_player getVariable ["DUWS_disguised", false])) exitWith {};
            
            // 9. 载具
            private _veh = vehicle _player;
            if (_veh != _player) then {
                private _vehType = typeOf _veh;
                private _civVehList = _player getVariable ["DUWS_disguise_civilianVehicles", []];
                if (!(_vehType in _civVehList)) exitWith {
                    ["STR_DUWS_T_DISGUISE_BROKEN_VEHICLE"] call _fnc_breakDisguise;
                };
            };
            
            // 10. 声望下降
            private _currentRep = missionNamespace getVariable ["Player_Reputation", 0];
            if (_currentRep < (_player getVariable ["DUWS_disguise_startRep", 0])) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_REP"] call _fnc_breakDisguise;
            };
            
            // 11. 负声望城镇
            if (_currentRep < 0) then {
                private _locations = missionNamespace getVariable ["civ_locations", []];
                private _radii = missionNamespace getVariable ["civ_radii", []];
                {
                    private _center = getPos _x;
                    private _radius = _radii param [_forEachIndex, 200];
                    if (_player distance _center < _radius) exitWith {
                        ["STR_DUWS_T_DISGUISE_BROKEN_REP_TOWN"] call _fnc_breakDisguise;
                    };
                } forEach _locations;
            };
            
            sleep 5;
        };
        
        // 清理
        if (!isNull _player) then {
            _player setVariable ["DUWS_disguised", false, true];
            if (alive _player) then {
                _player setCaptive false;
                [false] remoteExec ["fnc_disguise_setCaptiveLocal", _player];
            };
            _player setVariable ["DUWS_disguise_paused", false, true];
            _player setVariable ["DUWS_disguise_warningActive", false, true];
            _player setVariable ["DUWS_disguise_monitorRunning", false];
            
            private _eh = _player getVariable ["DUWS_disguise_firedEH", -1];
            if (_eh != -1) then {
                _player removeEventHandler ["FiredMan", _eh];
                _player setVariable ["DUWS_disguise_firedEH", nil];
            };
        };
    };
};