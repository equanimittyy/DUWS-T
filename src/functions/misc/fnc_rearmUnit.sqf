// fnc_rearmUnit.sqf
// 功能：给单位的所有武器补充 2 个适配弹匣（参照 fn_addAmmo 逻辑）
// 参数：_unit（单个单位）
// 执行端：服务器
if (!isServer) exitWith {};

params ["_unit"];
if (isNull _unit || {!alive _unit}) exitWith {};

{
    private _weapon = _x;
    if (_weapon == "") then { continue };

    // 获取兼容弹匣列表
    private _compatibleMags = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");
    if (_compatibleMags isEqualTo []) then { continue };

    // 优先使用当前已装配的弹匣类型
    private _currentMag = switch (_forEachIndex) do {
        case 0: { primaryWeaponMagazine _unit };
        case 1: { secondaryWeaponMagazine _unit };
        case 2: { handgunMagazine _unit };
    };

    private _selectedMag = "";
    if (!isNil "_currentMag" && {_currentMag isNotEqualTo []}) then {
        _currentMag = (_currentMag select 0) param [0, ""];
        if (_currentMag != "" && {_currentMag in _compatibleMags}) then {
            // 把当前弹药补满
            private _ammoCount = getNumber (configFile >> "CfgMagazines" >> _currentMag >> "count");
            _unit setAmmo [_weapon, _ammoCount];
            _selectedMag = _currentMag;
        };
    };

    // 若没有当前弹药或当前弹药不兼容，随机选一个
    if (_selectedMag == "") then {
        _selectedMag = selectRandom _compatibleMags;
    };

    // 添加 2 个弹匣
    for "_i" from 1 to 2 do {
        _unit addMagazineGlobal _selectedMag;
    };
} forEach [primaryWeapon _unit, secondaryWeapon _unit, handgunWeapon _unit];