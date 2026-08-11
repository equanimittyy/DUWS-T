// Locality: any -- pure config read, no globals set. Resolves the real projectile a faction's
// mortar or artillery vehicle fires, so the fake shell-drop strike (client/supports/fnc_arty.sqf)
// throws that faction's own round instead of a hardcoded NATO shell. A faction mod opts in by
// setting blufor_ARTY_X / blufor_MORTAR_X to a vehicle class; left unset, the caller keeps the
// vanilla shell it passes, so no faction file has to change for the default to hold.
//
// Walks the vehicle's hull and turret magazines (turrets nest, so recursively), maps each magazine
// to its ammo, and returns one class of the wanted family: "he" picks the highest-hit non-smoke
// round -- robust across mods, the biggest banger is the frag/HE shell -- and "smoke" picks the
// first smoke round. Returns "" when the class is unknown or carries no matching round.
DUWS_fnc_deriveShell = {
    params ["_veh", ["_want", "he"]];
    if (_veh == "") exitWith { "" };
    private _cfg = configFile >> "CfgVehicles" >> _veh;
    if !(isClass _cfg) exitWith { "" };

    private _mags = +(getArray (_cfg >> "magazines"));
    private _fnc_turrets = {
        params ["_parent"];
        {
            _mags append (getArray (_x >> "magazines"));
            [_x] call _fnc_turrets;
        } forEach ("true" configClasses (_parent >> "Turrets"));
    };
    [_cfg] call _fnc_turrets;

    private _isSmoke = _want == "smoke";
    private _pick = "";
    private _bestHit = -1;
    {
        private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
        if (_ammo != "") then {
            private _ac = configFile >> "CfgAmmo" >> _ammo;
            private _smoke = (_ammo isKindOf ["SmokeShell", configFile >> "CfgAmmo"])
                || {"smoke" in toLower _ammo};
            if (_isSmoke) then {
                if (_smoke && {_pick == ""}) then { _pick = _ammo };
            } else {
                private _h = getNumber (_ac >> "hit");
                if (!_smoke && {_h > _bestHit}) then { _bestHit = _h; _pick = _ammo };
            };
        };
    } forEach _mags;
    _pick
};
