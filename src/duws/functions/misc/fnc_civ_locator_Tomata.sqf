// Locality: server -- inherited from misc/fnc_civ_init_Tomata.sqf.
/*
    fnc_civ_locator_Tomata.sqf
    功能：获取地图上所有适合平民生成的城镇位置（无距离限制）
    返回：位置数组（Location 对象）
    执行端：服务器
*/

// 计算地图中心点（用于全图搜索）
private _center = [worldSize / 2, worldSize / 2, 0];
private _radius = worldSize * 1.5; // 足够覆盖整个地图

// 获取所有主要城镇类型的位置
private _allLocations = nearestLocations [
    _center,
    ["NameCityCapital", "NameCity", "NameVillage", "Name"], // 城镇类型
    _radius
];

// 可选：从 CfgWorlds 中筛选其他特殊地点（如工厂、军事设施等）
private _specialLocations = [];
private _namesConfig = configFile >> "CfgWorlds" >> worldName >> "Names";
for "_i" from 0 to (count _namesConfig - 1) do {
    private _entry = _namesConfig select _i;
    private _name = toUpper getText (_entry >> "name");
    private _type = getText (_entry >> "type");
    private _position = getArray (_entry >> "position");
    
    // 筛选感兴趣的类型：战略点、军事设施、工业区等
    if (_type in ["NameLocal", "NameMarine", "Strategic", "StrongPointArea"]) then {
        // 可进一步按关键词过滤（如 FACTORY, AIRFIELD 等）
        if (["FACTORY", "AIRFIELD", "MILITARY"] findIf { _x in _name } != -1) then {
            private _loc = nearestLocation [_position, _type];
            _specialLocations pushBack _loc;
        };
    };
};

// 合并并去重（nearestLocations 已保证唯一，但特殊地点可能重复）
private _result = _allLocations + _specialLocations;
_result = _result arrayIntersect _result; // 去重

// 返回结果
_result