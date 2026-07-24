/*
    fnc_civ_init_Tomata.sqf
    功能: 初始化平民系统，为每个城镇创建触发器，计算初始人口，添加地图标记
    执行端: 服务器
    修改: 触发器使用统一处理函数 fnc_civ_handler，通过 "spawn"/"cleanup" 参数区分
*/
if (!isServer) exitWith {};

if (!isNil "civ_init_done") exitWith { diag_log "[CIV] Already initialized, skipping."; };
civ_init_done = true;
diag_log "[CIV] Initializing civilian system (persistent population with map icons)";

// 等待 CIV_PRESENCE 确定（环境菜单选择后才会同步）
waitUntil { sleep 0.1; !isNil "CIV_PRESENCE" };

// 获取城镇位置（地图预定义）
private _locations = [] call fnc_civ_locator_Tomata;
diag_log format ["[CIV] fnc_civ_locator_Tomata returned %1 locations", count _locations];
_locations = _locations select { (getPos _x) distance2D [0,0] > 100 };
diag_log format ["[CIV] After filtering near origin, remaining %1 locations", count _locations];

private _dynamicLocs = [_locations, 3, true, 800, 100, 50, 100] call fnc_civ_detectClusters;
diag_log format ["[CIV] Dynamic detection returned %1 clusters", count _dynamicLocs];
_locations append _dynamicLocs;
diag_log format ["[CIV] Total locations after adding dynamics: %1", count _locations];

missionNamespace setVariable ["civ_locations", _locations];
private _staticCount = count _locations - count _dynamicLocs;
private _dynamicCount = count _dynamicLocs;
diag_log format ["[CIV] Total locations: %1 (static: %2, dynamic: %3)", count _locations, _staticCount, _dynamicCount];

// 读取平民阵营单位
if (isNil "CIV_PRESENCE") then { CIV_PRESENCE = "NONE"; };
diag_log format ["[CIV] CIV_PRESENCE = %1", CIV_PRESENCE];
[] call fnc_civ_setup_array;
diag_log format ["[CIV] civ_array loaded, count: %1", count civ_array];

// ========== 第一阶段：计算每个位置的半径、人口并临时存储 ==========
private _radii = [];
private _pops = [];
private _maxs = [];

{
    private _locIndex = _forEachIndex;
    private _pos = getPos _x;
    private _locationName = if (text _x != "") then { text _x } else { format ["Unnamed%1", _locIndex] };
    
    // 获取建筑数量：如果是动态区域，直接使用存储的数值，否则重新计算
    private _buildingCount = _x getVariable ["buildingCount", 0];
    if (_buildingCount == 0) then {
        private _usableBuildings = [_pos, 2, 350] call fnc_usableBuildings;
        _buildingCount = count _usableBuildings;
    };
    
    // 区域半径：每个建筑10米，最小100米，最大500米
    private _radius = (_buildingCount * 10) min 500 max 100;
    _radii pushBack _radius;
    
    // 人口计算：无论静态动态，均按建筑数×2，上限280
    _initialPop = (_buildingCount * 2) min 280;
    // 为每个城镇生成独立的最低人口（6~12 随机整数）
    private _minPop = 6 + floor random 7;  // 取值范围 6.12
    _initialPop = _initialPop max _minPop; // 确保人口不低于该随机最小值
    
    if (CIV_PRESENCE == "RAVAGE") then {
        _initialPop = round (_initialPop * 2.0) min 280;
        diag_log format ["[CIV] RAVAGE mode: adjusted pop to %1", _initialPop];
    };
    
    // 确保至少1人
    _initialPop = _initialPop max 1;
    
    _pops pushBack _initialPop;
    _maxs pushBack _buildingCount;
    
    diag_log format ["[CIV] Location %1: %2, buildings=%3, initialPop=%4, radius=%5", _locIndex, _locationName, _buildingCount, _initialPop, _radius];
} forEach _locations;

// ========== 第二阶段：重叠检测，优化距离过近且较小的城镇 ==========
private _count = count _locations;
private _toDelete = [];
private _minRadius = 50;

for "_i" from 0 to (_count - 1) do {
    if (_i in _toDelete) then { continue };
    for "_j" from (_i + 1) to (_count - 1) do {
        if (_j in _toDelete) then { continue };
        private _pos1 = getPos (_locations select _i);
        private _pos2 = getPos (_locations select _j);
        private _dist = _pos1 distance _pos2;
        private _rad1 = _radii select _i;
        private _rad2 = _radii select _j;
        private _radSum = _rad1 + _rad2;
        if (_dist < _radSum * 1.05) then {
            if (_rad1 <= _rad2) then {
                private _newRad = _rad1;
                while { _newRad > _minRadius && { _dist < (_newRad + _rad2) * 1.05 } } do {
                    _newRad = _newRad - 5;
                };
                if (_dist < (_newRad + _rad2) * 1.05) then {
                    _toDelete pushBack _i;
                } else {
                    _radii set [_i, _newRad];
                };
            } else {
                private _newRad = _rad2;
                while { _newRad > _minRadius && { _dist < (_rad1 + _newRad) * 1.05 } } do {
                    _newRad = _newRad - 5;
                };
                if (_dist < (_rad1 + _newRad) * 1.05) then {
                    _toDelete pushBack _j;
                } else {
                    _radii set [_j, _newRad];
                };
            };
        };
    };
};

_toDelete = _toDelete arrayIntersect _toDelete;

private _newLocations = [];
private _newRadii = [];
private _newPops = [];
private _newMaxs = [];
for "_i" from 0 to (_count - 1) do {
    if (!(_i in _toDelete)) then {
        _newLocations pushBack (_locations select _i);
        _newRadii pushBack (_radii select _i);
        _newPops pushBack (_pops select _i);
        _newMaxs pushBack (_maxs select _i);
    };
};

// 删除被淘汰的 Location 对象（避免残留）
{ deleteLocation (_locations select _x); } forEach _toDelete;

_locations = _newLocations;
_radii = _newRadii;
missionNamespace setVariable ["civ_locations", _locations];
missionNamespace setVariable ["civ_radii", _radii];
diag_log format ["[CIV] After overlap cleanup: %1 locations remaining.", count _locations];

// ========== 第三阶段：为保留的城镇创建触发器、地图标记，并存储人口变量 ==========
{
    private _locIndex = _forEachIndex;
    private _pos = getPos _x;
    private _radius = _radii select _locIndex;
    private _initialPop = _newPops select _locIndex;
    private _buildingCount = _newMaxs select _locIndex;
    private _locationName = if (text _x != "") then { text _x } else { format ["Unnamed%1", _locIndex] };
    
    // 存储人口和最大建筑数（用于后续生成和清理）
    missionNamespace setVariable [format ["civ_pop_%1", _locIndex], _initialPop];
    missionNamespace setVariable [format ["civ_max_%1", _locIndex], _buildingCount];
    
    // 创建触发器
    private _trg = createTrigger ["EmptyDetector", _pos];
    _trg setTriggerArea [_radius, _radius, 0, false, 80];
    _trg setTriggerActivation ["ANYPLAYER", "PRESENT", true];
    
    // 根据 CIV_PRESENCE 选择处理函数
    private _handlerFunc = "fnc_civ_handler";
    if (CIV_PRESENCE == "WBK") then {
    _handlerFunc = "fnc_civ_handler_wbk";
    };
    _trg setTriggerStatements [
    "this",
    format ["[%1, 'spawn'] spawn %2", _locIndex, _handlerFunc],
    format ["[%1, 'cleanup'] spawn %2", _locIndex, _handlerFunc]
    ];
    
    // 创建区域标记（半透明椭圆）
    private _markerName = format ["civ_area_%1", _locIndex];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerShape "ELLIPSE";
    _marker setMarkerBrush "SolidBorder";
    _marker setMarkerColor "#(0.5,0,0.5,0.3)";
    _marker setMarkerSize [_radius, _radius];
    
    // 创建人口图标（位于区域下方）
    private _iconPos = [(_pos select 0), (_pos select 1) - 80];
    private _iconName = format ["civ_icon_%1", _locIndex];
    private _icon = createMarker [_iconName, _iconPos];
    _icon setMarkerShape "ICON";
    _icon setMarkerType "loc_tourism";
    _icon setMarkerColor "ColorBlack";
    _icon setMarkerSize [1.2, 1.2];
    _icon setMarkerText format ["%1", _initialPop];
    
    diag_log format ["[CIV] Created markers for location %1 (%2) pop %3", _locIndex, _locationName, _initialPop];
} forEach _locations;

// 声誉恢复线程（保持不变）
[] spawn {
    diag_log "[CIV] Reputation recovery thread started";
    while {true} do {
        waitUntil {sleep 10; CIV_deaths > 0};
        private _rep = Player_Reputation;
        private _civdeaths = CIV_deaths;
        private _resetTimer = false;
        for "_i" from 1 to 6 do {
            sleep 150;
            if (CIV_deaths > _civdeaths) exitWith {_resetTimer = true};
        };
        if (!_resetTimer) then {
            if (_rep == Player_Reputation) then {
                if (Player_Reputation == 1) exitWith {};
                Player_Reputation = Player_Reputation + 1;
                publicVariable "Player_Reputation";
                ["repup",[localize "STR_DUWS_T_rqwho9bq",format[localize "STR_DUWS_T_0pluxey2",Player_Reputation]]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated,false];
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_repup"] remoteExec ["BIS_fnc_showSubtitle", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
                diag_log format ["[CIV] Reputation increased to %1", Player_Reputation];
            };
        };
    };
};

// 平民系统初始化完成，设置全局启用时间（120秒后）
missionNamespace setVariable ["civ_spawn_enabled_time", time + 120, true];
diag_log format ["[CIV] Civilian system initialized. Spawns will be enabled at %1 (in %2 seconds)", time + 120, 120];

diag_log "[CIV] Civilian system initialized.";
// ========== 声望奖励循环（每15分钟） ==========
[] spawn {
    waitUntil { sleep 1; !isNil "Player_Reputation" };
    sleep 180; // 开局延迟3分钟
    while {true} do {
        sleep 900; // 15分钟
        private _rep = Player_Reputation;
        if (_rep > 0) then {
            private _cpReward = ceil(_rep / 2);
            [_cpReward] remoteExec ["fnc_cp_adjust", 2];
            // CP 提醒（使用 cpaddedciv 格式，显示获得的 CP）
            ["CPaddedciv", [_cpReward]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
            [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_cpcivbonus"] remoteExec ["BIS_fnc_showSubtitle", 0];
            [] remoteExec ["fnc_broadcastRadioChatter", 0];
        };
    };
};
// ==============================================