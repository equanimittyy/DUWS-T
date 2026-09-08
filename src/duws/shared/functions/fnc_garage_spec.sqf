// Locality: any -- broadcast from server_fnc_init. The depot menu reads the tier table, caps and
// pool usage client-side to fill its readouts and ladder, and the server store/retrieve/buy paths
// read the same globals, so every definition here must resolve identically on every machine. The
// capture/apply pair is the only substantive engine work: a stored vehicle is turned into plain
// serializable data and back, so no object handle ever has to survive the store.

// The capacity ladder as pure caps. Land, air and boat are three independent pools; each level sets
// ABSOLUTE caps for all three (a purchase overwrites the caps, it does not add to them), so the live
// caps are always the highest owned level's row. Base is owned from campaign start and carries no
// flag. The four expansion levels are permanent supports bought from the REQUESTS menu, in order --
// their price, AP cost and tier gate live in the support catalogue (client/supports/fnc_supports_init.sqf),
// beside the radio towers they mirror. Ownership is the catalogue flag named here, which this table
// reads to pick the live caps; nothing else about a level lives in two places.
//   [key, land, air, boat, flag]
DUWS_garage_tiers = [
    ["base",    3,  1,  3, ""],
    ["garage1", 6,  3,  6, "support_garage1_available"],
    ["garage2",10,  5, 10, "support_garage2_available"],
    ["garage3",15,  8, 15, "support_garage3_available"],
    ["garage4",25, 15, 25, "support_garage4_available"]
];

// A stored vehicle's domain, from the same DUWS_fnc_vehKind classifier the price and tier read, so
// no domain tag has to be stored beside the spec -- the class alone decides which pool it fills.
// Planes, helicopters and UAVs are air; a boat is a boat; everything else (tanks, cars, logistics,
// AA, artillery) is land.
DUWS_fnc_vehDomain = {
    params ["_class"];
    private _kind = [_class] call DUWS_fnc_vehKind;
    if (_kind in ["planeArmed", "planeTransport", "heliArmed", "heliTransport", "uav"]) exitWith { "air" };
    if (_kind == "boat") exitWith { "boat" };
    "land"
};

// The live caps as [land, air, boat]: the highest owned level's row. Tiers ascend and each requires
// the one below, so the last row with an owned flag is the highest -- overwrite as we climb.
DUWS_fnc_garageCaps = {
    private _caps = [3, 1, 3];
    {
        _x params ["", "_l", "_a", "_b", "_flag"];
        if (_flag != "" && {missionNamespace getVariable [_flag, false]}) then { _caps = [_l, _a, _b]; };
    } forEach DUWS_garage_tiers;
    _caps
};

// Used count per pool as [land, air, boat], from the stored specs' classes.
DUWS_fnc_garageUsed = {
    private _l = 0; private _a = 0; private _b = 0;
    {
        switch ([_x select 0] call DUWS_fnc_vehDomain) do {
            case "air":  { _a = _a + 1 };
            case "boat": { _b = _b + 1 };
            default      { _l = _l + 1 };
        };
    } forEach (missionNamespace getVariable ["DUWS_garage_stored", []]);
    [_l, _a, _b]
};

// Pool index for a domain, matching the [land, air, boat] order the caps and used arrays use.
DUWS_fnc_garageDomainIndex = {
    params ["_domain"];
    ["land", "air", "boat"] find _domain
};

// One coarse ammo fraction (rounds / capacity, all turrets): setVehicleAmmo restores a single
// fraction to every weapon, so per-magazine detail is pointless. An unarmed hull reads -1. Shared
// by the store path and the depot status readout so both report the same number.
DUWS_fnc_vehAmmoFrac = {
    params ["_veh"];
    private _cur = 0; private _cap = 0;
    {
        _cur = _cur + (_x select 2);
        _cap = _cap + getNumber (configFile >> "CfgMagazines" >> (_x select 0) >> "count");
    } forEach magazinesAllTurrets _veh;
    if (_cap > 0) then { _cur / _cap } else { -1 }
};

// A stored vehicle captured to plain serializable data. Index layout, read back by DUWS_fnc_vehSpecApply:
//   0 class     1 textures (getObjectTextures)     2 pylon magazines (getPylonMagazines, in order)
//   3 hitpoints (getAllHitPointsDamage)            4 overall damage    5 fuel
//   6 cargo [getWeaponCargo, getMagazineCargo, getItemCargo, getBackpackCargo]
//   7 ammo fraction (current rounds / capacity across all turrets), or -1 when the hull is unarmed
// No object reference is kept: the caller deletes the vehicle after this returns.
DUWS_fnc_vehSpecCapture = {
    params ["_veh"];
    [
        typeOf _veh,
        getObjectTextures _veh,
        getPylonMagazines _veh,
        getAllHitPointsDamage _veh,
        damage _veh,
        fuel _veh,
        [getWeaponCargo _veh, getMagazineCargo _veh, getItemCargo _veh, getBackpackCargo _veh],
        [_veh] call DUWS_fnc_vehAmmoFrac
    ]
};

// Applies a captured spec to a freshly created vehicle. Server-side: the vehicle is server-local on
// creation, so setHitPointDamage/setFuel replicate, and the *Global cargo/texture/pylon writes reach
// every client.
DUWS_fnc_vehSpecApply = {
    params ["_veh", "_spec"];
    // Ammo defaults to -1 (skip) so a spec saved before ammo was tracked keeps createVehicle's full load.
    _spec params ["", "_textures", "_pylonMags", "_hitpoints", "_damage", "_fuel", "_cargo", ["_ammo", -1]];

    { _veh setObjectTextureGlobal [_forEachIndex, _x]; } forEach _textures;

    // setPylonLoadout by 1-based index; the turret path defaults to the pylon's configured turret.
    { if (_x != "") then { _veh setPylonLoadout [_forEachIndex + 1, _x, true]; }; } forEach _pylonMags;

    // Overall damage first, then per-hitpoint, so the fine-grained state is not flattened by the
    // overall write. [_damage, false] suppresses the cook-off a live hit would trigger.
    _veh setDamage [_damage, false];
    _hitpoints params ["_hpNames", "", "_hpDmg"];
    {
        if (_x != "") then { _veh setHitPointDamage [_x, _hpDmg select _forEachIndex]; };
    } forEach _hpNames;

    _veh setFuel _fuel;
    if (_ammo >= 0) then { _veh setVehicleAmmo _ammo; };

    _cargo params ["_w", "_m", "_i", "_b"];
    clearWeaponCargoGlobal _veh;
    clearMagazineCargoGlobal _veh;
    clearItemCargoGlobal _veh;
    clearBackpackCargoGlobal _veh;
    // Each channel is [[classes], [counts]]; iterate classes, index the paired counts.
    { _veh addWeaponCargoGlobal   [_x, (_w select 1) select _forEachIndex]; } forEach (_w select 0);
    { _veh addMagazineCargoGlobal [_x, (_m select 1) select _forEachIndex]; } forEach (_m select 0);
    { _veh addItemCargoGlobal     [_x, (_i select 1) select _forEachIndex]; } forEach (_i select 0);
    { _veh addBackpackCargoGlobal [_x, (_b select 1) select _forEachIndex]; } forEach (_b select 0);
};
