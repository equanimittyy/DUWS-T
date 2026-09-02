// Locality: any -- broadcast from server_fnc_init. The request menu prices its rows client-side and
// the reader (shared/faction_lib/fnc_faction_rqst_list.sqf) reprices every vehicle through here, so it
// must resolve identically on every machine. Reads only config, so a vehicle prices itself with no
// per-faction data and a modded class is covered the moment it is detected.
//
// One classifier, two consumers: DUWS_fnc_vehKind feeds both the price below and the tier gate
// (DUWS_fnc_vehTier), so a vehicle's price and the rung that unlocks it can never disagree.

// Tuning surface -- calibrated against an in-game {kind, class, CP} dump, not derived.
DUWS_vehp_ARMOR_REF  = 1200;   // config "armor" that scores 1.0
DUWS_vehp_WEAPON_REF = 30;     // weaponScore that scores 1.0
DUWS_vehp_CAP_REF    = 200;    // magazine rounds that score 1.0 (firing capacity)
DUWS_vehp_SEAT_REF   = 14;     // passengers that score 1.0
DUWS_vehp_RATE_PIVOT = 0.1;    // reloadTime giving a full rate bonus; slower guns fall off
DUWS_vehp_RATE_W     = 0.3;    // how much fire-rate lifts a weapon's weight
DUWS_vehp_CAP_W      = 0.3;    // how much magazine capacity lifts it
DUWS_vehp_PYLON_W    = 2;      // per dynamic-loadout hardpoint

// Per kind: [lo, hi, wArmour, wWeapon, wSeats]. The band fixes the category ordering as a hard
// constraint (a car can never reach a tank's band); the weights place the score inside it. Armament
// is the main driver for anything that fights, so an unarmed or lightly-gunned hull sits near its
// band floor however heavily armoured -- armour only spreads it secondarily. Transports lean on
// capacity instead, having little armament to read. Weights sum to 1.
DUWS_vehPriceBands = createHashMapFromArray [
    ["tank",           [34, 46, 0.30, 0.65, 0.05]],
    ["apcIfv",         [24, 32, 0.30, 0.50, 0.20]],
    ["aa",             [28, 32, 0.25, 0.75, 0.00]],
    ["armedCar",       [12, 22, 0.10, 0.85, 0.05]],
    ["heliArmed",      [40, 48, 0.10, 0.80, 0.10]],
    ["planeArmed",     [52, 65, 0.05, 0.95, 0.00]],
    ["heliTransport",  [20, 30, 0.15, 0.15, 0.70]],
    ["planeTransport", [42, 48, 0.10, 0.00, 0.90]],
    ["logi",           [14, 18, 0.10, 0.00, 0.90]],
    ["lightUnarmed",   [ 1,  8, 0.00, 0.00, 1.00]],
    ["arty",           [66, 75, 0.20, 0.80, 0.00]],
    ["boat",           [16, 24, 0.10, 0.70, 0.20]],
    ["uav",            [ 5, 22, 0.00, 1.00, 0.00]],
    ["default",        [10, 10, 0.00, 0.00, 0.00]]
];

// Every weapon a vehicle's turrets carry, walked recursively so nested commander/gunner turrets are
// not missed. Config-only: takes the CfgVehicles entry, not a spawned object.
DUWS_fnc_vehTurretWeapons = {
    params ["_turretsCfg"];
    private _out = [];
    {
        _out append (getArray (_x >> "weapons"));
        _out append ([_x >> "Turrets"] call DUWS_fnc_vehTurretWeapons);
    } forEach ("true" configClasses _turretsCfg);
    _out
};

// A weapon list stripped of the non-combat fittings every vehicle carries (smoke, countermeasures),
// so "armed" and the weapon score both ignore them.
DUWS_fnc_vehWeapons = {
    params ["_cfg"];
    ([_cfg >> "Turrets"] call DUWS_fnc_vehTurretWeapons) select {
        _x != "" && {private _l = toLowerANSI _x; (_l find "smoke" < 0) && (_l find "cmflare" < 0)}
    }
};

// Dynamic-loadout hardpoints from config (planes/attack helis), counted without spawning -- the
// object-only getAllPylonsInfo cannot run on a classname in the menu build.
DUWS_fnc_vehPylonCount = {
    params ["_cfg"];
    count ("true" configClasses (_cfg >> "Components" >> "TransportPylonsComponent" >> "Pylons"))
};

DUWS_fnc_vehArmed = {
    params ["_cfg"];
    (count ([_cfg] call DUWS_fnc_vehWeapons) > 0) || {([_cfg] call DUWS_fnc_vehPylonCount) > 0}
};

// A main tank gun -- a cannon that is not an autocannon -- is what separates an MBT from a tracked
// IFV or APC, since all three are isKindOf "Tank". A seat count cannot: vanilla MBTs carry hull
// riders (the Slammer's transportSoldier is >= 4), so cargo reads them as carriers.
DUWS_fnc_vehHasMainGun = {
    params ["_cfg"];
    private _has = false;
    {
        private _chain = ([configFile >> "CfgWeapons" >> _x, true] call BIS_fnc_returnParents) apply { toLowerANSI _x };
        if (("cannoncore" in _chain) && {(_chain joinString " ") find "autocannon" < 0}) exitWith { _has = true };
    } forEach ([_cfg] call DUWS_fnc_vehWeapons);
    _has
};

// The vehicle's kind, matched in priority order -- the specific signals (artillery, AA radar) are
// tested before the broad isKindOf families they also belong to, so a Cheetah reads as AA not tank.
DUWS_fnc_vehKind = {
    params ["_class"];
    if (_class == "") exitWith { "default" };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (getNumber (_cfg >> "artilleryScanner") == 1) exitWith { "arty" };
    if (getText (_cfg >> "vehicleClass") == "Autonomous") exitWith { "uav" };
    if (getNumber (_cfg >> "radarType") == 2) exitWith { "aa" };   // 2 = ground AA radar; jets are 4
    private _armed = [_cfg] call DUWS_fnc_vehArmed;
    if (_class isKindOf "Plane") exitWith { ["planeTransport", "planeArmed"] select _armed };
    if (_class isKindOf "Helicopter") exitWith {
        private _cargo = getNumber (_cfg >> "transportSoldier");
        ["heliTransport", "heliArmed"] select (_armed && {_cargo < 4})
    };
    // Tracked IFVs and APCs are isKindOf "Tank" too. The main gun tells them apart: an MBT mounts a
    // cannon, an IFV an autocannon, an APC only an MG -- so a cannon is the tank band, anything else
    // the IFV band.
    if (_class isKindOf "Tank") exitWith {
        ["apcIfv", "tank"] select ([_cfg] call DUWS_fnc_vehHasMainGun)
    };
    if (_class isKindOf "Car") exitWith {
        private _isLogi = (getNumber (_cfg >> "transportRepair") != 0)
            || {getNumber (_cfg >> "transportAmmo") != 0}
            || {getNumber (_cfg >> "transportFuel") != 0}
            || {getNumber (_cfg >> "attendant") == 1};
        if (_isLogi) exitWith { "logi" };
        if (_class isKindOf "Wheeled_APC_F" || {getNumber (_cfg >> "armor") > 300}) exitWith { "apcIfv" };
        if (_armed) exitWith { "armedCar" };
        "lightUnarmed"
    };
    if (_class isKindOf "Ship") exitWith { "boat" };
    "default"
};

// Armament strength: each turret weapon weighted by class, then lifted by its fire-rate and its
// magazine capacity, summed so more weapons score higher; plus a flat weight per loadout pylon.
DUWS_fnc_vehWeaponScore = {
    params ["_cfg"];
    private _score = 0;
    {
        private _wc = configFile >> "CfgWeapons" >> _x;
        private _chain = ([_wc, true] call BIS_fnc_returnParents) apply { toLowerANSI _x };
        private _chainStr = _chain joinString " ";
        private _name = toLowerANSI _x;
        private _typeW = switch (true) do {
            case (_chainStr find "autocannon" >= 0): { 7 };
            case ("cannoncore" in _chain): { 10 };
            case ("missilelauncher" in _chain || {"rocketpod" in _chain} || {"launchercore" in _chain}): { 8 };
            case ("gmg_f" in _chain || {_chainStr find "grenadelauncher" >= 0}): { 5 };
            case ("mguncore" in _chain || {"mgun" in _chain} || {_chainStr find "machinegun" >= 0}): {
                // HMG (.50/12.7mm) outweighs a rifle-calibre MG.
                [2, 3] select (["hmg", "127", "50cal", ".50"] findIf { _name find _x >= 0 } >= 0)
            };
            default { 1 };
        };
        private _modes = getArray (_wc >> "modes");
        private _mode = if (_modes isEqualTo []) then { "" } else { _modes select 0 };
        private _reload = if (_mode == "" || {_mode == "this"}) then {
            getNumber (_wc >> "reloadTime")
        } else {
            getNumber (_wc >> _mode >> "reloadTime")
        };
        if (_reload <= 0) then { _reload = DUWS_vehp_RATE_PIVOT };
        private _rateN = ((DUWS_vehp_RATE_PIVOT / _reload) min 1) max 0;
        private _mags = getArray (_wc >> "magazines");
        private _rounds = if (_mags isEqualTo []) then { 0 } else {
            getNumber (configFile >> "CfgMagazines" >> (_mags select 0) >> "count")
        };
        private _capN = ((_rounds / DUWS_vehp_CAP_REF) min 1) max 0;
        _score = _score + _typeW * (1 + DUWS_vehp_RATE_W * _rateN) * (1 + DUWS_vehp_CAP_W * _capN);
    } forEach ([_cfg] call DUWS_fnc_vehWeapons);
    _score + DUWS_vehp_PYLON_W * ([_cfg] call DUWS_fnc_vehPylonCount)
};

// CP price: kind picks the band, the heaviness score (armour + armament + seats, blended by the
// kind's weights) picks the point inside it. Memoised per class -- the config walk runs once per
// class per machine, not per menu open.
DUWS_fnc_vehPrice = {
    params ["_class"];
    if (_class == "") exitWith { 10 };
    private _cache = missionNamespace getVariable ["DUWS_vehPriceCache", createHashMap];
    private _hit = _cache getOrDefault [_class, -1];
    if (_hit >= 0) exitWith { _hit };

    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _kind = [_class] call DUWS_fnc_vehKind;
    (DUWS_vehPriceBands getOrDefault [_kind, [10, 10, 0, 0, 0]]) params ["_lo", "_hi", "_wA", "_wW", "_wS"];

    private _score = if (_kind == "default") then { 0.5 } else {
        private _armorN  = ((getNumber (_cfg >> "armor") / DUWS_vehp_ARMOR_REF) min 1) max 0;
        private _weaponN = ((([_cfg] call DUWS_fnc_vehWeaponScore) / DUWS_vehp_WEAPON_REF) min 1) max 0;
        private _seatsN  = ((getNumber (_cfg >> "transportSoldier") / DUWS_vehp_SEAT_REF) min 1) max 0;
        (((_wA * _armorN) + (_wW * _weaponN) + (_wS * _seatsN)) min 1) max 0
    };
    private _cp = round (_lo + _score * (_hi - _lo));

    _cache set [_class, _cp];
    missionNamespace setVariable ["DUWS_vehPriceCache", _cache];
    _cp
};
