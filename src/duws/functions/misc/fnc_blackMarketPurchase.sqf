// fnc_blackMarketPurchase.sqf
if (!isServer) exitWith {};

params ["_caller", "_amount", "_type"];
if (isNull _caller) exitWith {};

private _moneyClass = "Money_roll";
private _allInventory = itemsWithMagazines _caller;
private _moneyCount = { _x == _moneyClass } count _allInventory;

if (_moneyCount < _amount) exitWith {
    private _msg = format [localize "STR_DUWS_T_BLACKMARKET_NOT_ENOUGH_MONEY", _amount, _moneyCount];
    ["info", [localize "STR_DUWS_T_BLACKMARKET_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", _caller];
};

// 扣除纸币
private _removed = 0;
private _itemsList = items _caller;
{
    if (_x == _moneyClass && _removed < _amount) then {
        _caller removeItem _moneyClass;
        _removed = _removed + 1;
    };
} forEach _itemsList;
if (_removed < _amount) then {
    private _magsList = magazines _caller;
    {
        if (_x == _moneyClass && _removed < _amount) then {
            _caller removeMagazineGlobal _moneyClass;
            _removed = _removed + 1;
        };
    } forEach _magsList;
};

// ========== 生成随机物品 ==========
private _itemClass = "";
private _displayName = "";
private _isGoggles = false;
private _isOptic = false;

if (_type == "goggles") then {
    // 随机护目镜
    private _allGoggles = [];
    {
        if (getNumber (_x >> "scope") == 2) then {
            _allGoggles pushBack (configName _x);
        };
    } forEach ("true" configClasses (configFile >> "CfgGlasses"));
    if (count _allGoggles == 0) then { _allGoggles = ["G_Aviator"]; };
    _itemClass = selectRandom _allGoggles;
    _displayName = getText (configFile >> "CfgGlasses" >> _itemClass >> "displayName");
    _isGoggles = true;
} else {
    if (_type == "optic") then {
        // 随机瞄具：只要类名中包含 "optic"（不区分大小写）即视为瞄具
        private _allOptics = [];
        {
            private _itemName = configName _x;
            if (toLower _itemName find "optic" != -1) then {
                _allOptics pushBack _itemName;
            };
        } forEach ("true" configClasses (configFile >> "CfgWeapons"));
        if (count _allOptics == 0) then { _allOptics = ["optic_ACO_grn_smg"]; };
        _itemClass = selectRandom _allOptics;
        _displayName = getText (configFile >> "CfgWeapons" >> _itemClass >> "displayName");
        _isOptic = true;
    } else {
        // 随机手枪
        private _allPistols = [];
        {
            if (getNumber (_x >> "scope") == 2 && getNumber (_x >> "type") == 2) then {
                _allPistols pushBack (configName _x);
            };
        } forEach ("true" configClasses (configFile >> "CfgWeapons"));
        if (count _allPistols == 0) then { _allPistols = ["hgun_P07_F"]; };
        _itemClass = selectRandom _allPistols;
        _displayName = getText (configFile >> "CfgWeapons" >> _itemClass >> "displayName");
        _isGoggles = false;
    };
};

[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_BLACKMARKET_BOUGHT_sent"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 5;
// ========== 尝试添加到库存/装备，若失败则掉落在地面 ==========
private _pos = _caller modelToWorld [0, 1.5, 0];
private _holder = objNull;
private _addedToInventory = false;

if (_isGoggles) then {
    // 护目镜作为物品处理
    private _beforeCount = count (items _caller);
    _caller addItem _itemClass;
    private _afterCount = count (items _caller);
    if (_afterCount > _beforeCount) then {
        _addedToInventory = true;
    } else {
        _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
        _holder addItemCargoGlobal [_itemClass, 1];
        [localize "STR_DUWS_T_BLACKMARKET_DROPPED_ON_GROUND"] remoteExec ["hint", _caller];
    };
} else {
    if (_isOptic) then {
        // 瞄具作为物品处理（与护目镜相同）
        private _beforeCount = count (items _caller);
        _caller addItem _itemClass;
        private _afterCount = count (items _caller);
        if (_afterCount > _beforeCount) then {
            _addedToInventory = true;
        } else {
            _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
            _holder addItemCargoGlobal [_itemClass, 1];
            [localize "STR_DUWS_T_BLACKMARKET_DROPPED_ON_GROUND"] remoteExec ["hint", _caller];
        };
    } else {
        // 手枪处理
        private _handgunSlot = handgunWeapon _caller;
        if (_handgunSlot != "") then {
            // 副武器栏已满，直接掉落
            _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
            _holder addWeaponCargoGlobal [_itemClass, 1];
            private _magazine = getArray (configFile >> "CfgWeapons" >> _itemClass >> "magazines") select 0;
            if (!isNil "_magazine" && {_magazine != ""}) then {
                _holder addMagazineCargoGlobal [_magazine, 1];
            };
            _addedToInventory = false;
            [localize "STR_DUWS_T_BLACKMARKET_DROPPED_ON_GROUND"] remoteExec ["hint", _caller];
        } else {
            // 副武器栏空闲，尝试添加
            private _magazine = getArray (configFile >> "CfgWeapons" >> _itemClass >> "magazines") select 0;
            _caller addWeaponGlobal _itemClass;
            if (!isNil "_magazine" && {_magazine != ""}) then {
                _caller addMagazineGlobal _magazine;
            };
            if (handgunWeapon _caller == _itemClass) then {
                _addedToInventory = true;
            } else {
                _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
                _holder addWeaponCargoGlobal [_itemClass, 1];
                if (!isNil "_magazine" && {_magazine != ""}) then {
                    _holder addMagazineCargoGlobal [_magazine, 1];
                };
                _addedToInventory = false;
            };
        };
    };
};
// ========== 广播通知所有玩家 ==========
private _title = localize "STR_DUWS_T_BLACKMARKET_TITLE";
private _desc = "";
if (_type == "goggles") then {
    _desc = format [localize "STR_DUWS_T_BLACKMARKET_BOUGHT_GOGGLES", name _caller, _displayName];
} else {
    if (_type == "optic") then {
        _desc = format [localize "STR_DUWS_T_BLACKMARKET_BOUGHT_OPTIC", name _caller, _displayName];
    } else {
        _desc = format [localize "STR_DUWS_T_BLACKMARKET_BOUGHT_PISTOL", name _caller, _displayName];
    };
};
["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", 0];
