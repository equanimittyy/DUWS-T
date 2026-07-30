["INFO", "SUPPORT", "Starting building destruction with asset protection."] call fnc_log;

// ---------- 1. 收集所有需要保护的对象 ----------
private _protected = [];

// 总部主建筑
if (!isNil "bluHQ_object" && {!isNull bluHQ_object}) then {
    _protected pushBack bluHQ_object;
};
// 军官
if (!isNil "hq_blu1" && {!isNull hq_blu1}) then {
    _protected pushBack hq_blu1;
};
// 移动 HQ（如果存在）
if (!isNil "MHQ1" && {!isNull MHQ1}) then {
    _protected pushBack MHQ1;
};
// 所有已建立的 FOB
if (!isNil "Array_of_FOBS") then {
    {
        if (!isNull _x) then {
            _protected pushBack _x;
        };
    } forEach Array_of_FOBS;
};
// 如果 MHQ 已部署，保护其帐篷和弹药箱
if (!isNil "MHQ_tent" && {!isNull MHQ_tent}) then {
    _protected pushBack MHQ_tent;
};
if (!isNil "MHQ_ammobox" && {!isNull MHQ_ammobox}) then {
    _protected pushBack MHQ_ammobox;
};

["INFO", "SUPPORT", format ["Protected %1 key assets.", count _protected]] call fnc_log;

// ---------- 2. 获取地图中心点（用于全图扫描） ----------
private _center = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
if (_center isEqualTo []) then {
    _center = [worldSize / 2, worldSize / 2, 0];
};

// ---------- 3. 施加随机伤害（跳过保护对象） ----------
private _buildings = nearestObjects [_center, ["Building", "House", "Ruins"], worldSize];
["INFO", "SUPPORT", format ["Found %1 potential buildings.", count _buildings]] call fnc_log;

private _damagedCount = 0;
{
    if (!isNull _x && {!(_x in _protected)}) then {
        _x allowDamage true;
        private _damage = 0.7 + random 0.15; // 0.7 ~ 0.85
        _x setDamage _damage;
        _damagedCount = _damagedCount + 1;
    };
} forEach _buildings;

["INFO", "SUPPORT", format ["Successfully damaged %1 buildings.", _damagedCount]] call fnc_log;
