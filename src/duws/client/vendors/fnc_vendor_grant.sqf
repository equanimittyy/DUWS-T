// Locality: client -- an inventory add takes effect only where the unit is local.
//
// Hands bought gear to the player: each piece into its own empty equipment slot, otherwise into the
// first worn container with room, otherwise at their feet.
params ["_class", "_count"];

// Every fill command replaces what its slot holds, so only an empty slot is filled.
private _fnc_equip = {
    private _slot = call {
        ([_class] call BIS_fnc_itemType) params ["_cat", "_sub"];
        // The engine seats a gun by its config type; BIS_fnc_itemType's subtypes name the gun, not the slot.
        if (_cat isEqualTo "Weapon") exitWith {
            switch (getNumber (configFile >> "CfgWeapons" >> _class >> "type")) do {
                case 1: { [primaryWeapon player, { player addWeapon _class }] };
                case 2: { [handgunWeapon player, { player addWeapon _class }] };
                case 4: { [secondaryWeapon player, { player addWeapon _class }] };
                default { [] };
            }
        };
        // getUnitLoadout's assigned-item order; a UAV terminal takes the GPS slot.
        private _linkedSub = [_sub, "GPS"] select (_sub isEqualTo "UAVTerminal");
        private _linked = ["Map", "GPS", "Radio", "Compass", "Watch", "NVGoggles"] find _linkedSub;
        if (_linked >= 0) exitWith { [(getUnitLoadout player) select 9 select _linked, { player linkItem _class }] };
        switch (_sub) do {
            case "Uniform": { [uniform player, { player addUniform _class }] };
            case "Vest": { [vest player, { player addVest _class }] };
            case "Headgear": { [headgear player, { player addHeadgear _class }] };
            case "Glasses": { [goggles player, { player addGoggles _class }] };
            case "Binocular";
            case "LaserDesignator": { [binocular player, { player addWeapon _class }] };
            default { [] };
        }
    };
    if (_slot isEqualTo [] || {(_slot select 0) isNotEqualTo ""}) exitWith { false };
    // Read back, not assumed: addUniform refuses a uniform the player's side may not wear.
    private _before = getUnitLoadout player;
    call (_slot select 1);
    getUnitLoadout player isNotEqualTo _before
};

private _fnc_take = {
    // A pack never nests inside another container, so it only fits on an empty back.
    if (_class isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) exitWith {
        if (backpack player isEqualTo "") then { player addBackpack _class; true } else { false }
    };
    // Disguised, an empty weapon or kit slot is the cover: a gun worn there breaks it, one in a pack does not.
    if (!(player getVariable ["DUWS_disguised", false]) && {call _fnc_equip}) exitWith { true };
    // The per-container adds take a weapon or a magazine as readily as an item, so every other gear
    // type goes through the one path.
    if (player canAddItemToUniform _class) exitWith { player addItemToUniform _class; true };
    if (player canAddItemToVest _class) exitWith { player addItemToVest _class; true };
    if (player canAddItemToBackpack _class) exitWith { player addItemToBackpack _class; true };
    false
};
private _dropped = 0;
for "_i" from 1 to _count do { if !(call _fnc_take) then { _dropped = _dropped + 1 } };
if (_dropped > 0) then { [[[_class, _dropped]], getPosATL player] remoteExec ["fnc_money_drop", 2] };

private _name = getText (([_class] call fnc_vendor_classCfg) >> "displayName");
private _line = format [localize "STR_DUWS_T_VENDOR_BOUGHT",
    format ["%1 x %2", _count, [_name, _class] select (_name isEqualTo "")]];
hint (if (_dropped == 0) then { _line } else { format ["%1\n\n%2", _line, [[[_class, _dropped]]] call DUWS_fnc_dropped_line] });
