// Resolve the arsenal display-row base weapon(s) for a class list, so the friendly set can hold the
// rows the arsenal actually shows. The arsenal collapses a preset weapon to its base row two ways:
// the config `baseWeapon` when set (arifle_MX_ACO_pointer_F -> arifle_MX_F), else -- when that is
// empty, as on the skin-variant DMR/LRR presets -- the first public (scope 2) parent in the
// inheritance chain (srifle_DMR_02_camo_AMS_LP_F -> srifle_DMR_02_camo_F). Cover both or those base
// rows, which the player is issued but never appear in a loadout verbatim, read as an empty pool
// ([0]) in Hybrid. Non-weapons contribute nothing.
params ["_classes"];

private _bases = [];
{
    private _cfg = configFile >> "CfgWeapons" >> _x;
    if (isClass _cfg) then {
        private _b = getText (_cfg >> "baseWeapon");
        if (_b != "") then { _bases pushBackUnique _b; };
        private _cur = inheritsFrom _cfg;
        while { !isNull _cur && {getNumber (_cur >> "scope") != 2} } do { _cur = inheritsFrom _cur; };
        if (!isNull _cur && {configName _cur != _x}) then { _bases pushBackUnique (configName _cur); };
    };
} forEach _classes;

_bases
