if (!isServer) exitWith {};

params ["_player"];
if (isNull _player) exitWith {};

// Refusals take DISGUISE_CANT_*, breaks take DISGUISE_BROKEN_* -- the two read as whole
// sentences from different frames, so a key never serves both paths.
fnc_disguise_hintFail = {
    params ["_player", "_reasonKey"];
    [localize _reasonKey] remoteExec ["hint", _player];
};
publicVariable "fnc_disguise_hintFail";

// Civilian by config, not by the scanned wardrobe: the uniform's linked unit carries side 3
// (TCivilian), so any civilian shirt passes -- including modded clothes and classes no spawned
// local happened to wear. Shared by the activation gate and the maintenance monitor so the two
// agree; if they diverged the disguise would activate then break on the next tick. Server-only
// (the whole file is), so no broadcast.
fnc_disguise_isCivUniform = {
    params ["_uniform"];
    if (_uniform == "") exitWith { false };
    private _unit = getText (configFile >> "CfgWeapons" >> _uniform >> "ItemInfo" >> "uniformClass");
    if (_unit == "") exitWith { false };
    getNumber (configFile >> "CfgVehicles" >> _unit >> "side") == 3
};

// Vests and headgear are CfgWeapons items with no side field, so they cannot be classed civilian
// by config the way the uniform is. An accessory reads civilian when the slot is empty, when a
// local civilian is seen wearing the class (the population scan, mod-adaptive), or when it is on a
// curated allowlist below. Shared by gate and monitor so the two cannot drift.
fnc_disguise_isCivGear = {
    params ["_item", "_scanned", "_whitelist"];
    _item == "" || {_item in _scanned} || {_item in _whitelist}
};

// Curated civilian classes the population scan can miss: gear a player loots but no local NPC
// spawns wearing. Vanilla civilians almost never wear a vest, so the press vest is seeded to keep
// a safety/hi-viz style vest valid; add mod safety-vest classes here. Headgear/backpack lean on
// the scan (civilians do wear caps and civilian packs), so their allowlists start empty.
DUWS_disguise_civVestWhitelist = ["V_Press_F"];
DUWS_disguise_civHeadgearWhitelist = [];
DUWS_disguise_civBackpackWhitelist = [];

private _civilianVehicles = [
    "C_Van_01_fuel_F", "C_Van_01_box_F", "C_Van_01_transport_F",
    "C_Tractor_01_F", "C_Hatchback_01_sport_F", "C_Hatchback_01_F",
    "C_Offroad_01_covered_F", "C_Offroad_01_comms_F", "C_Offroad_01_repair_F",
    "C_Offroad_01_F", "C_Van_02_transport_F", "C_Van_02_medevac_F",
    "C_Van_02_service_F", "C_Van_02_vehicle_F", "C_Offroad_02_unarmed_F",
    "C_Truck_02_fuel_F", "C_Truck_02_box_F", "C_Truck_02_covered_F",
    "C_Truck_02_transport_F"
];

private _lastUse = _player getVariable ["DUWS_disguise_lastUse", -300];
private _cooldownRemaining = 300 - (diag_tickTime - _lastUse);
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_DISGUISE_COOLDOWN_FMT", _minutes, _seconds];
    [_msg] remoteExec ["hint", _player];
};

private _veh = vehicle _player;
if (_veh != _player) then {
    private _vehType = typeOf _veh;
    if (!(_vehType in _civilianVehicles)) exitWith {
        [_player, "STR_DUWS_T_DISGUISE_CANT_VEHICLE"] call fnc_disguise_hintFail;
    };
};

if (CIV_PRESENCE == "NONE") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_NOCIV"] call fnc_disguise_hintFail;
};
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_ZOMBIE"] call fnc_disguise_hintFail;
};

if (primaryWeapon _player != "" || secondaryWeapon _player != "" || handgunWeapon _player != "") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_WEAPON"] call fnc_disguise_hintFail;
};

private _assignedItems = assignedItems _player;
if ("NVGoggles" in _assignedItems || "NVGoggles_OPFOR" in _assignedItems || "NVGoggles_INDEP" in _assignedItems) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_NVG"] call fnc_disguise_hintFail;
};

private _currentUniform = uniform _player;
if (_currentUniform == "") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_NAKED"] call fnc_disguise_hintFail;
};
if !([_currentUniform] call fnc_disguise_isCivUniform) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_UNIFORM"] call fnc_disguise_hintFail;
};

// Accessories must read civilian too, or a military plate carrier or helmet under a civilian
// shirt would still pass.
if !([vest _player, missionNamespace getVariable ["DUWS_civVests", []], DUWS_disguise_civVestWhitelist] call fnc_disguise_isCivGear) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_VEST"] call fnc_disguise_hintFail;
};
if !([headgear _player, missionNamespace getVariable ["DUWS_civHeadgear", []], DUWS_disguise_civHeadgearWhitelist] call fnc_disguise_isCivGear) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_HEADGEAR"] call fnc_disguise_hintFail;
};
if !([backpack _player, missionNamespace getVariable ["DUWS_civBackpacks", []], DUWS_disguise_civBackpackWhitelist] call fnc_disguise_isCivGear) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_BACKPACK"] call fnc_disguise_hintFail;
};

_player setVariable ["DUWS_disguise_lastUse", diag_tickTime];
_player setVariable ["DUWS_disguised", true, true];
_player setCaptive true;
[true] remoteExec ["fnc_disguise_setCaptiveLocal", _player];

_player setVariable ["DUWS_disguise_warningActive", false, true];
_player setVariable ["DUWS_disguise_warningPos", nil, true];
_player setVariable ["DUWS_disguise_paused", false, true];
_player setVariable ["DUWS_disguise_civilianVehicles", _civilianVehicles];

[localize "STR_DUWS_T_DISGUISE_ACTIVATED_DESC"] remoteExec ["hint", _player];
[localize "STR_DUWS_T_DISGUISE_SUCCESS_HINT"] remoteExec ["hint", _player];

if (!(_player getVariable ["DUWS_disguise_monitorRunning", false])) then {
    _player setVariable ["DUWS_disguise_monitorRunning", true];
    
    private _firedEH = _player addEventHandler ["FiredMan", {
        params ["_unit"];
        if (_unit getVariable ["DUWS_disguised", false]) then {
            _unit setVariable ["DUWS_disguised", false, true];
            _unit setCaptive false;
            [false] remoteExec ["fnc_disguise_setCaptiveLocal", _unit];
            [localize "STR_DUWS_T_DISGUISE_BROKEN_THROW"] remoteExec ["hint", _unit];
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
                [localize _reasonKey] remoteExec ["hint", _player];
            };
        };
        
        while {alive _player && {_player getVariable ["DUWS_disguised", false]}} do {
            if (_player getVariable ["DUWS_disguise_paused", false]) then {
                sleep 5;
                continue;
            };
            
            if (primaryWeapon _player != "" || secondaryWeapon _player != "" || handgunWeapon _player != "") exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_WEAPON"] call _fnc_breakDisguise;
            };

            private _assigned = assignedItems _player;
            if ("NVGoggles" in _assigned || "NVGoggles_OPFOR" in _assigned || "NVGoggles_INDEP" in _assigned) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_NVG"] call _fnc_breakDisguise;
            };
            
            if (uniform _player == "") exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_NAKED"] call _fnc_breakDisguise;
            };
            if !([uniform _player] call fnc_disguise_isCivUniform) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_UNIFORM"] call _fnc_breakDisguise;
            };
            if !([vest _player, missionNamespace getVariable ["DUWS_civVests", []], DUWS_disguise_civVestWhitelist] call fnc_disguise_isCivGear) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_VEST"] call _fnc_breakDisguise;
            };
            if !([headgear _player, missionNamespace getVariable ["DUWS_civHeadgear", []], DUWS_disguise_civHeadgearWhitelist] call fnc_disguise_isCivGear) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_HEADGEAR"] call _fnc_breakDisguise;
            };
            if !([backpack _player, missionNamespace getVariable ["DUWS_civBackpacks", []], DUWS_disguise_civBackpackWhitelist] call fnc_disguise_isCivGear) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_BACKPACK"] call _fnc_breakDisguise;
            };
            
            private _nearCorpses = _player nearObjects ["CAManBase", 20] select { !alive _x };
            if (count _nearCorpses > 0) exitWith {
                ["STR_DUWS_T_DISGUISE_BROKEN_CORPSE"] call _fnc_breakDisguise;
            };

            private _nearEnemies = _player nearEntities [["CAManBase"], _alertDistance] select { side _x == EAST && alive _x };
            private _warningActive = _player getVariable ["DUWS_disguise_warningActive", false];
            
            if (count _nearEnemies > 0) then {
                if (!_warningActive) then {
                    _player setVariable ["DUWS_disguise_warningActive", true, true];
                    _player setVariable ["DUWS_disguise_warningPos", getPos _player, true];
                    
                    private _warningKey = selectRandom _warningKeys;
                    [localize "STR_DUWS_T_DISGUISE_OPFOR_SPEAKER", localize _warningKey] remoteExec ["fnc_duws_dialogue", _player];
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
            
            private _veh = vehicle _player;
            if (_veh != _player) then {
                private _vehType = typeOf _veh;
                private _civVehList = _player getVariable ["DUWS_disguise_civilianVehicles", []];
                if (!(_vehType in _civVehList)) exitWith {
                    ["STR_DUWS_T_DISGUISE_BROKEN_VEHICLE"] call _fnc_breakDisguise;
                };
            };
            
            // The OPFOR band, not any negative figure: a town the enemy holds is where a
            // disguise gets you recognised, and with reputation localised a campaign-wide
            // negative says nothing about the ground the player is standing on.
            if (([[getPos _player] call fnc_civ_townAt] call fnc_civ_repAt) <= -10) then {
                ["STR_DUWS_T_DISGUISE_BROKEN_REP_TOWN"] call _fnc_breakDisguise;
            };
            
            sleep 5;
        };
        
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