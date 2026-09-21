// Locality: client -- an inventory add takes effect only where the unit is local.
//
// Hands one bought gear class to the player: into the first worn container with room, otherwise at
// their feet. The hint mirrors fnc_loot_grant's, so a purchase reads the way a find does.
params ["_class"];

private _taken = call {
    // A pack never nests inside another container, so it only fits on an empty back.
    if (_class isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) exitWith {
        if (backpack player isEqualTo "") then { player addBackpack _class; true } else { false }
    };
    // The per-container adds take a weapon or a magazine as readily as an item, so every other gear
    // type goes through the one path.
    if (player canAddItemToUniform _class) exitWith { player addItemToUniform _class; true };
    if (player canAddItemToVest _class) exitWith { player addItemToVest _class; true };
    if (player canAddItemToBackpack _class) exitWith { player addItemToBackpack _class; true };
    false
};
if (!_taken) then { [[[_class, 1]], getPosATL player] remoteExec ["fnc_money_drop", 2] };

private _name = getText (([_class] call fnc_vendor_classCfg) >> "displayName");
hint format ["%1\n\n%2",
    format [localize "STR_DUWS_T_VENDOR_BOUGHT_ITEM", [_name, _class] select (_name isEqualTo "")],
    if (_taken) then { localize "STR_DUWS_T_LOOT_TAKEN" } else { [[[_class, 1]]] call DUWS_fnc_dropped_line }];
