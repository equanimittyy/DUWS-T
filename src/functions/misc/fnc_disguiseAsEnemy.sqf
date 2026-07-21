// fnc_disguiseAsEnemy.sqf (完整修改版 v4 - 禁止连续重复装束)
// 功能：伪装成敌人，自动换上敌方制服，并禁止连续两次使用相同的背心+头盔组合
// 参数: _caller - 执行伪装的玩家
// 执行端: 服务器
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// ========== 冷却检查 ==========
private _lastUse = _caller getVariable ["DUWS_enemyDisguise_lastUse", -600];
private _cooldownRemaining = 600 - (diag_tickTime - _lastUse);
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_ENEMY_DISGUISE_COOLDOWN", _minutes, _seconds];
    [_msg] remoteExec ["hint", _caller];
};

// ========== 等待敌方装备数据 ==========
private _timeout = diag_tickTime + 30;
waitUntil {
    sleep 0.1;
    (!isNil "DUWS_enemyUniforms" && !isNil "DUWS_enemyVests" && !isNil "DUWS_enemyHeadgear" && 
     !isNil "DUWS_enemyPrimaryWeapons") || diag_tickTime > _timeout
};
if (isNil "DUWS_enemyUniforms" || {count DUWS_enemyUniforms == 0}) exitWith {
    [localize "STR_DUWS_T_ENEMY_DISGUISE_NO_ENEMY_DATA"] remoteExec ["hint", _caller];
};

// ========== 基础条件检查（不检查制服） ==========
private _vest = vest _caller;
private _headgear = headgear _caller;
private _primary = primaryWeapon _caller;
private _secondary = secondaryWeapon _caller;
private _handgun = handgunWeapon _caller;
private _backpack = backpack _caller;
private _assigned = assignedItems _caller;
private _hasNVG = false;
{
    if (toLowerANSI _x find "nvg" != -1) then { _hasNVG = true; };
} forEach _assigned;

if (_vest == "") exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_NO_VEST"] remoteExec ["hint", _caller]; };
if (_headgear == "") exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_NO_HEADGEAR"] remoteExec ["hint", _caller]; };
if (_primary == "") exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_NO_PRIMARY"] remoteExec ["hint", _caller]; };

// ========== 重复装束检查（新增）==========
private _lastVest = _caller getVariable ["DUWS_enemyDisguise_lastVest", ""];
private _lastHeadgear = _caller getVariable ["DUWS_enemyDisguise_lastHeadgear", ""];
if (_vest == _lastVest && _headgear == _lastHeadgear) exitWith {
    [localize "STR_DUWS_T_ENEMY_DISGUISE_SAME_GEAR"] remoteExec ["hint", _caller];
};

if (!(_vest in DUWS_enemyVests)) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_VEST"] remoteExec ["hint", _caller]; };
if (!(_headgear in DUWS_enemyHeadgear)) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_HEADGEAR"] remoteExec ["hint", _caller]; };
if (!(_primary in DUWS_enemyPrimaryWeapons)) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_PRIMARY"] remoteExec ["hint", _caller]; };
if (_backpack != "" && !(_backpack in DUWS_enemyBackpacks)) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_BACKPACK"] remoteExec ["hint", _caller]; };
if (_secondary != "" && !(_secondary in DUWS_enemySecondaryWeapons)) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_SECONDARY"] remoteExec ["hint", _caller]; };
if (_handgun != "" && !(_handgun in DUWS_enemyHandguns)) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_HANDGUN"] remoteExec ["hint", _caller]; };
if (_hasNVG) then {
    private _nvgOK = false;
    {
        if (_x in DUWS_enemyNVGs) exitWith { _nvgOK = true; };
    } forEach _assigned;
    if (!_nvgOK) exitWith { [localize "STR_DUWS_T_ENEMY_DISGUISE_WRONG_NVG"] remoteExec ["hint", _caller]; };
};

// ========== 条件通过：通过 Loadout 替换强制换上敌方制服 ==========
private _loadout = getUnitLoadout _caller;
private _selectedUniform = selectRandom DUWS_enemyUniforms;

// Loadout 结构: [primaryWeapon, secondaryWeapon, handgun, uniform, vest, backpack, headgear, facewear, binocular, items, assignedItems]
private _uniformData = _loadout select 3;
if (count _uniformData == 0) then {
    _uniformData = [_selectedUniform, [], []];
} else {
    _uniformData set [0, _selectedUniform];
};
_loadout set [3, _uniformData];

_caller setUnitLoadout _loadout;

_caller setVariable ["DUWS_enemyDisguise_uniform", _selectedUniform];

// ========== 开启伪装 ==========
_caller setVariable ["DUWS_enemyDisguise_lastUse", diag_tickTime];
_caller setVariable ["DUWS_enemyDisguised", true, true];
_caller setCaptive true;
[true] remoteExec ["fnc_disguise_setCaptiveLocal", _caller];
["weizhuang", [localize "STR_DUWS_T_ENEMY_DISGUISE_ACTION", localize "STR_DUWS_T_ENEMY_DISGUISE_ACTIVATED"]] remoteExec ["BIS_fnc_showNotification", _caller];

// 记录本次使用的背心和头盔（新增）
_caller setVariable ["DUWS_enemyDisguise_lastVest", _vest, true];
_caller setVariable ["DUWS_enemyDisguise_lastHeadgear", _headgear, true];

private _startTime = diag_tickTime;
private _duration = 120;

_caller setVariable ["DUWS_enemyDisguise_vest", _vest];
_caller setVariable ["DUWS_enemyDisguise_headgear", _headgear];
_caller setVariable ["DUWS_enemyDisguise_primary", _primary];
_caller setVariable ["DUWS_enemyDisguise_secondary", _secondary];
_caller setVariable ["DUWS_enemyDisguise_handgun", _handgun];
_caller setVariable ["DUWS_enemyDisguise_backpack", _backpack];
_caller setVariable ["DUWS_enemyDisguise_hasNVG", _hasNVG];

private _fixedPhrases = [
    "STR_DUWS_T_ENEMY_DISGUISE_RADIO_1",
    "STR_DUWS_T_ENEMY_DISGUISE_RADIO_2",
    "STR_DUWS_T_ENEMY_DISGUISE_RADIO_3",
    "STR_DUWS_T_ENEMY_DISGUISE_RADIO_4",
    "STR_DUWS_T_ENEMY_DISGUISE_RADIO_5"
];

private _subtitleHandle = [_caller, _startTime, _duration, _fixedPhrases] spawn {
    params ["_caller", "_start", "_dur", "_phrases"];
    private _end = _start + _dur;
    private _idx = 0;
    while {diag_tickTime < _end && alive _caller && (_caller getVariable ["DUWS_enemyDisguised", false])} do {
        sleep 20;
        if (diag_tickTime >= _end) exitWith {};
        if !(_caller getVariable ["DUWS_enemyDisguised", false]) exitWith {};
        private _msgKey = _phrases select (_idx % count _phrases);
        _idx = _idx + 1;
        [localize _msgKey] remoteExec ["systemChat", _caller];
        [localize "STR_DUWS_T_unknown", localize _msgKey] remoteExec ["BIS_fnc_showSubtitle", _caller];
    };
};
_caller setVariable ["DUWS_enemyDisguise_subtitleHandle", _subtitleHandle];

[_caller, _startTime, _duration] spawn {
    params ["_caller", "_start", "_dur"];
    private _end = _start + _dur;
    private _exposed = false;
    private _warningActive = false;
    private _warningStart = 0;
    
    while {diag_tickTime < _end && !_exposed && alive _caller && (_caller getVariable ["DUWS_enemyDisguised", false])} do {
        sleep 0.5;
        
        if (_caller getVariable ["DUWS_enemyDisguise_fired", false]) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_FIRE"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_FIRE"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        
        private _curUniform = uniform _caller;
        private _curVest = vest _caller;
        private _curHeadgear = headgear _caller;
        private _curPrimary = primaryWeapon _caller;
        private _curSecondary = secondaryWeapon _caller;
        private _curHandgun = handgunWeapon _caller;
        private _curBackpack = backpack _caller;
        private _curAssigned = assignedItems _caller;
        private _curNVG = false;
        { if (toLowerANSI _x find "nvg" != -1) then { _curNVG = true; }; } forEach _curAssigned;
        
        if (_curUniform != (_caller getVariable ["DUWS_enemyDisguise_uniform", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curVest != (_caller getVariable ["DUWS_enemyDisguise_vest", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curHeadgear != (_caller getVariable ["DUWS_enemyDisguise_headgear", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curPrimary != (_caller getVariable ["DUWS_enemyDisguise_primary", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_GEAR"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curBackpack != "" && _curBackpack != (_caller getVariable ["DUWS_enemyDisguise_backpack", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_BACKPACK"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_BACKPACK"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curSecondary != "" && _curSecondary != (_caller getVariable ["DUWS_enemyDisguise_secondary", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_SECONDARY"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_SECONDARY"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curHandgun != "" && _curHandgun != (_caller getVariable ["DUWS_enemyDisguise_handgun", ""])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_HANDGUN"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_HANDGUN"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        if (_curNVG != (_caller getVariable ["DUWS_enemyDisguise_hasNVG", false])) exitWith {
            _exposed = true;
            [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_NVG"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_NVG"]] remoteExec ["BIS_fnc_showNotification", _caller];
            sleep 6;
            [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        
        private _nearEnemies = (_caller nearEntities ["CAManBase", 10]) select { side _x == EAST && alive _x };
        if (count _nearEnemies > 0) then {
            if (!_warningActive) then {
                _warningActive = true;
                _warningStart = diag_tickTime;
                [localize "STR_DUWS_T_ENEMY_DISGUISE_WARNING"] remoteExec ["hint", _caller];
            } else {
                if (diag_tickTime - _warningStart >= 5) then {
                    _exposed = true;
                    [localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_DISTANCE"] remoteExec ["hint", _caller];
                    [localize "STR_DUWS_T_unknown", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
                    ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_BROKEN_DISTANCE"]] remoteExec ["BIS_fnc_showNotification", _caller];
                    sleep 6;
                    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_ENEMY_DISGUISE_spotted"] remoteExec ["BIS_fnc_showSubtitle", _caller];
                };
            };
        } else {
            _warningActive = false;
        };
    };
    
    private _subHandle = _caller getVariable ["DUWS_enemyDisguise_subtitleHandle", scriptNull];
    if (!isNull _subHandle) then { terminate _subHandle; };
    
    if (_exposed) then {
        _caller setVariable ["DUWS_enemyDisguised", false, true];
        _caller setCaptive false;
        [false] remoteExec ["fnc_disguise_setCaptiveLocal", _caller];
        private _eh = _caller getVariable ["DUWS_enemyDisguise_firedEH", -1];
        if (_eh != -1) then { _caller removeEventHandler ["Fired", _eh]; };
    } else {
        if (alive _caller && (_caller getVariable ["DUWS_enemyDisguised", false])) then {
            _caller setVariable ["DUWS_enemyDisguised", false, true];
            _caller setCaptive false;
            [false] remoteExec ["fnc_disguise_setCaptiveLocal", _caller];
            [localize "STR_DUWS_T_ENEMY_DISGUISE_EXPIRED"] remoteExec ["hint", _caller];
            ["weizhuangdapo", [localize "STR_DUWS_T_DISGUISE_ACTIVATED", localize "STR_DUWS_T_ENEMY_DISGUISE_EXPIRED"]] remoteExec ["BIS_fnc_showNotification", _caller];
        };
    };
};

_caller setVariable ["DUWS_enemyDisguise_fired", false];
private _firedEH = _caller addEventHandler ["Fired", {
    params ["_unit"];
    if (_unit getVariable ["DUWS_enemyDisguised", false]) then {
        _unit setVariable ["DUWS_enemyDisguise_fired", true, true];
    };
}];
_caller setVariable ["DUWS_enemyDisguise_firedEH", _firedEH];

[localize "STR_DUWS_T_ENEMY_DISGUISE_ACTIVATED"] remoteExec ["hint", _caller];