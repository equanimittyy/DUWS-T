// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
/*
    fnc_civ_init_Tomata.sqf
    功能: 初始化平民系统，为每个城镇创建触发器，计算初始人口，添加地图标记
    执行端: 服务器
    Invoked from fnc_init_OPFOR_WARCOM once zone build-out finishes: the towns come from
    fnc_civ_selectTowns, which ranks map towns against the HQ and the enemy zones, so this
    cannot run before zone placement.
*/
if (!isServer) exitWith {};

if (!isNil "civ_init_done") exitWith { ["WARN", "CIV", "Already initialized, skipping."] call fnc_log; };
civ_init_done = true;
["INFO", "CIV", "Initializing civilian system (persistent population with map icons)"] call fnc_log;

// The parameter is the parting map banner: "" clears it, anything else stays up until the
// map closes. The caller publishes mission_init_complete once this returns, so an abort here
// still releases the campaign start.
private _fnc_finish = {
    params [["_prompt", ""]];
    [_prompt] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    ["INFO", "CIV", "Civilian system initialized."] call fnc_log;
};

// 读取平民阵营单位. Runs before any abort below: PMC/partisan hiring uses civ_array as a
// body pool even when no town is ever registered.
["INFO", "CIV", format ["CIV_PRESENCE = %1", CIV_PRESENCE]] call fnc_log;
[] call fnc_civ_setup_array;
["INFO", "CIV", format ["civ_array loaded, count: %1", count civ_array]] call fnc_log;

// Banner first: the caller cleared the map before handing over, and selection cannot ping its
// own progress until it has enumerated the map's towns.
["Placing civilians...<br/>surveying towns"] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
([] call fnc_civ_selectTowns) params [["_queue", []], ["_spare", []]];

// The base composition spans about 30 m; the rest is margin for its guards, patrols and
// spawn points. Enemy zones are deliberately not gated -- a contested town is the point --
// but a civilian area sitting over the player's own base is not.
private _HQ_RADIUS = 100;
private _hq = missionNamespace getVariable ["PosOfBLUHQ", []];
private _hqPos = if (count _hq >= 2) then { [_hq select 0, _hq select 1, 0] } else { [] };

// ========== 第一阶段：计算每个位置的半径、人口 ==========
private _kept = [];
private _radii = [];
private _pops = [];
private _done = 0;

// A queue, not a forEach: an HQ overlap can only be judged once the radius is known here, and
// rejecting a town pushes its replacement back on for the same treatment.
while { count _queue > 0 } do {
    // The count rides along from selection: it is the heaviest engine call in this pass.
    (_queue deleteAt 0) params ["_loc", "_buildingCount"];
    private _pos = getPos _loc;
    private _locationName = if (text _loc != "") then { text _loc } else { format ["Unnamed%1", _done] };
    _done = _done + 1;

    [format ["Placing civilians...<br/>town %1 of %2", _done, _done + count _queue]]
        remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

    // 区域半径：每个建筑10米，最小100米，最大500米
    private _radius = (_buildingCount * 10) min 500 max 100;
    private _hqDist = if (count _hqPos > 0) then { _pos distance2D _hqPos } else { -1 };

    // Areas, not centres: a civilian disc that merely reaches the HQ's still spawns civilians
    // inside the base. The radius formula lives here, not in selection, so the test cannot run
    // before this point -- drop the town and take the next stand-in selection handed over.
    if (_hqDist >= 0 && { _hqDist < _radius + _HQ_RADIUS }) then {
        ["INFO", "CIV", format ["Skipping %1: area (r=%2) overlaps the BLUFOR HQ at %3m", _locationName, _radius, round _hqDist]] call fnc_log;
        if (count _spare > 0) then { _queue pushBack (_spare deleteAt 0) };
    } else {
        // 人口计算：按建筑数×2，上限280
        private _initialPop = (_buildingCount * 2) min 280;
        // 为每个城镇生成独立的最低人口（6~12 随机整数）
        private _minPop = 6 + floor random 7;
        _initialPop = _initialPop max _minPop;

        if (CIV_PRESENCE == "RAVAGE") then {
            _initialPop = round (_initialPop * 2.0) min 280;
            ["INFO", "CIV", format ["RAVAGE mode: adjusted pop to %1", _initialPop]] call fnc_log;
        };

        _initialPop = _initialPop max 1;

        _kept pushBack _loc;
        _radii pushBack _radius;
        _pops pushBack _initialPop;

        ["INFO", "CIV", format ["Location %1: buildings=%2, initialPop=%3, radius=%4", _locationName, _buildingCount, _initialPop, _radius]] call fnc_log;
    };
};

private _locations = _kept;

// Warn on the map banner rather than by hint or notification: the map is still open at this
// point, and the engine draws both of those underneath it.
if (count _locations == 0) exitWith {
    ["ERROR", "CIV", "No civilian towns registered. Civilian population is disabled for this campaign."] call fnc_log;
    [format ["%1<br/>%2", localize "STR_DUWS_T_CIV_NO_TOWNS_TITLE", localize "STR_DUWS_T_CIV_NO_TOWNS"]] call _fnc_finish;
};

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

// The losers are dropped from the registry only. These are the map's own Locations now, and
// deleteLocation would remove them from the engine for the rest of the mission -- side
// mission siting (fnc_findSafeMissionPos) and the player's location readout both read them
// back out of nearestLocations.
private _newLocations = [];
private _newRadii = [];
private _newPops = [];
for "_i" from 0 to (_count - 1) do {
    if (!(_i in _toDelete)) then {
        _newLocations pushBack (_locations select _i);
        _newRadii pushBack (_radii select _i);
        _newPops pushBack (_pops select _i);
    };
};

_locations = _newLocations;
_radii = _newRadii;
_pops = _newPops;
missionNamespace setVariable ["civ_locations", _locations];
missionNamespace setVariable ["civ_radii", _radii];
["INFO", "CIV", format ["After overlap cleanup: %1 locations remaining.", count _locations]] call fnc_log;

// ========== 第三阶段：为保留的城镇创建触发器、地图标记，并存储人口变量 ==========
{
    private _locIndex = _forEachIndex;
    private _pos = getPos _x;
    private _radius = _radii select _locIndex;
    private _initialPop = _pops select _locIndex;
    private _locationName = if (text _x != "") then { text _x } else { format ["Unnamed%1", _locIndex] };

    missionNamespace setVariable [format ["civ_pop_%1", _locIndex], _initialPop];

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

    ["INFO", "CIV", format ["Created markers for location %1 (%2) pop %3", _locIndex, _locationName, _initialPop]] call fnc_log;
} forEach _locations;

// No start-up delay: this function now runs after zone build-out rather than alongside a
// map-wide scan, so there is nothing left for the spawns to wait out.
missionNamespace setVariable ["civ_spawn_enabled_time", time, true];

[] call fnc_civ_rep_economy;

call _fnc_finish;
