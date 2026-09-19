// The class the arsenal lists a weapon under, and so the captured pool's key for it: BIS shows and
// issues a weapon as its BIS_fnc_baseWeapon row (arifle_MX_ACO_pointer_F as arifle_MX_F). configName
// fixes the declared case, which the count overlay's case-sensitive lookups match on.
params ["_cls"];
configName (configFile >> "CfgWeapons" >> ([_cls] call BIS_fnc_baseWeapon))
