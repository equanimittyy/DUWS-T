if (!isServer) exitWith {};

params ["_unit"];
if (isNull _unit || {!alive _unit}) exitWith {};

{
    private _weapon = _x;
    if (_weapon == "") then { continue };

    private _compatibleMags = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");
    if (_compatibleMags isEqualTo []) then { continue };

    // Prefer the magazine already loaded before falling back to a random compatible one.
    private _currentMag = switch (_forEachIndex) do {
        case 0: { primaryWeaponMagazine _unit };
        case 1: { secondaryWeaponMagazine _unit };
        case 2: { handgunMagazine _unit };
    };

    private _selectedMag = "";
    if (!isNil "_currentMag" && {_currentMag isNotEqualTo []}) then {
        _currentMag = (_currentMag select 0) param [0, ""];
        if (_currentMag != "" && {_currentMag in _compatibleMags}) then {
            private _ammoCount = getNumber (configFile >> "CfgMagazines" >> _currentMag >> "count");
            _unit setAmmo [_weapon, _ammoCount];
            _selectedMag = _currentMag;
        };
    };

    if (_selectedMag == "") then {
        _selectedMag = selectRandom _compatibleMags;
    };

    for "_i" from 1 to 2 do {
        _unit addMagazineGlobal _selectedMag;
    };
} forEach [primaryWeapon _unit, secondaryWeapon _unit, handgunWeapon _unit];