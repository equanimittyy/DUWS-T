// fnc_blackMarketPurchase.sqf
if (!isServer) exitWith {};

params ["_caller", "_amount", "_type"];
if (isNull _caller) exitWith {};

// Read before the spend, because the refusal message quotes what the player actually has.
private _moneyCount = [_caller] call fnc_coins_count;

// A hint, where the purchase below is a card: the refusal answers the one player who clicked and
// the sale is news for the team (docs/info/player_facing_text.md).
if !([_caller, _amount] call fnc_coins_spend) exitWith {
    private _msg = format [localize "STR_DUWS_T_BLACKMARKET_NOT_ENOUGH_MONEY", _amount, _moneyCount];
    [_msg] remoteExec ["hint", _caller];
};

private _itemClass = "";
private _displayName = "";
private _isGoggles = false;
private _isOptic = false;

if (_type == "goggles") then {
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
        // Optics have no dedicated CfgWeapons flag; classify by classname containing "optic".
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

[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_BLACKMARKET_BOUGHT_sent"] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
private _pos = _caller modelToWorld [0, 1.5, 0];
private _holder = objNull;

if (_isGoggles) then {
    private _beforeCount = count (items _caller);
    _caller addItem _itemClass;
    private _afterCount = count (items _caller);
    if (_afterCount <= _beforeCount) then {
        _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
        _holder addItemCargoGlobal [_itemClass, 1];
        [localize "STR_DUWS_T_BLACKMARKET_DROPPED_ON_GROUND"] remoteExec ["hint", _caller];
    };
} else {
    if (_isOptic) then {
        private _beforeCount = count (items _caller);
        _caller addItem _itemClass;
        private _afterCount = count (items _caller);
        if (_afterCount <= _beforeCount) then {
            _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
            _holder addItemCargoGlobal [_itemClass, 1];
            [localize "STR_DUWS_T_BLACKMARKET_DROPPED_ON_GROUND"] remoteExec ["hint", _caller];
        };
    } else {
        private _handgunSlot = handgunWeapon _caller;
        if (_handgunSlot != "") then {
            // handgunWeapon returns "" when the slot is free; non-empty means occupied, so drop instead.
            _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
            _holder addWeaponCargoGlobal [_itemClass, 1];
            private _magazine = getArray (configFile >> "CfgWeapons" >> _itemClass >> "magazines") select 0;
            if (!isNil "_magazine" && {_magazine != ""}) then {
                _holder addMagazineCargoGlobal [_magazine, 1];
            };
            [localize "STR_DUWS_T_BLACKMARKET_DROPPED_ON_GROUND"] remoteExec ["hint", _caller];
        } else {
            private _magazine = getArray (configFile >> "CfgWeapons" >> _itemClass >> "magazines") select 0;
            _caller addWeaponGlobal _itemClass;
            if (!isNil "_magazine" && {_magazine != ""}) then {
                _caller addMagazineGlobal _magazine;
            };
            if (handgunWeapon _caller != _itemClass) then {
                _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
                _holder addWeaponCargoGlobal [_itemClass, 1];
                if (!isNil "_magazine" && {_magazine != ""}) then {
                    _holder addMagazineCargoGlobal [_magazine, 1];
                };
            };
        };
    };
};
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
["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
