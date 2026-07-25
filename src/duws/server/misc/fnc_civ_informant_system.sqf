/*
    fnc_civ_informant_system.sqf
    服务器循环：每30分钟根据声望和硬核模式生成线人
    线人拥有“Talk to Informant”动作（触发 fnc_found_intel）和漫游路点
*/
if (!isServer) exitWith {};

// Civilians off: no populated towns for informants to appear in.
if (CIV_PRESENCE == "NONE") exitWith {};

    // 仅在硬核模式开启时生成线人
    if (!hardcore_mode_enable) then { continue; };
while {true} do {
    sleep 1800; // 30分钟

    private _rep = missionNamespace getVariable ["Player_Reputation", 0];
    if (_rep > 2) then {
        // 声望大于2时才有概率，每点声望增加5%概率，上限50%
        private _chance = (_rep - 2) * 0.05;
        if (_chance > 0.5) then { _chance = 0.5; };

        if (random 1 < _chance) then {
            // 获取所有城镇位置
            private _locations = missionNamespace getVariable ["civ_locations", []];
            if (count _locations == 0) exitWith { diag_log "[CIV] No locations found for informant spawn."; };

            // 获取所有存活玩家
            private _players = allPlayers select { alive _x };
            private _hasPlayers = (count _players > 0);

            // 候选城镇列表
            private _candidateLocations = [];

            if (_hasPlayers) then {
                // 筛选距离任意玩家 ≤ 2000 米的城镇
                {
                    private _pos = getPos _x;
                    private _minDist = 1e10;
                    {
                        private _dist = _pos distance _x;
                        if (_dist < _minDist) then { _minDist = _dist; };
                    } forEach _players;

                    if (_minDist <= 2000) then {
                        _candidateLocations pushBack _x;
                    };
                } forEach _locations;
            };

            // 如果没有符合条件的城镇或没有玩家，则使用所有城镇
            if (!_hasPlayers || count _candidateLocations == 0) then {
                _candidateLocations = _locations;
            };

            // 计算权重（有玩家时按距离加权，无玩家时权重均等）
            private _weights = [];
            private _totalWeight = 0;
            {
                private _pos = getPos _x;
                if (_hasPlayers) then {
                    // 计算到最近玩家的距离
                    private _minDist = 1e10;
                    {
                        private _dist = _pos distance _x;
                        if (_dist < _minDist) then { _minDist = _dist; };
                    } forEach _players;
                    private _weight = 1 / (_minDist + 100); // 距离越近权重越大
                    _weights pushBack _weight;
                    _totalWeight = _totalWeight + _weight;
                } else {
                    _weights pushBack 1;
                    _totalWeight = _totalWeight + 1;
                };
            } forEach _candidateLocations;

            // 按权重随机选择一个城镇
            private _rand = random _totalWeight;
            private _selectedIndex = 0;
            private _cum = 0;
            {
                _cum = _cum + _x;
                if (_rand <= _cum) exitWith { _selectedIndex = _forEachIndex; };
            } forEach _weights;

            private _selectedLoc = _candidateLocations select _selectedIndex;
            private _centerPos = getPos _selectedLoc;

            // 在城镇附近找一个安全位置
            private _spawnPos = [_centerPos, 0, 50, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
            if (_spawnPos isEqualTo [0,0,0]) then { _spawnPos = _centerPos; };

            // 随机选择平民类型（从 civ_array）
            private _civArray = missionNamespace getVariable ["civ_array", ["C_man_p_beggar_F"]];
            private _unitType = selectRandom _civArray;

            // 创建平民组和单位
            private _group = createGroup civilian;
            _group deleteGroupWhenEmpty true;
            private _unit = _group createUnit [_unitType, _spawnPos, [], 0, "NONE"];

            // 获取周围可用建筑用于路点
            private _usableBuildings = [_centerPos, 2, 200] call fnc_usableBuildings;

            // 添加线人对话动作（触发 fnc_found_intel）
            private _code = {[] spawn fnc_found_intel};
            [_unit, "Talk to Informant", "talk", _code] spawn fnc_actionRotary;

            // 添加漫游行为
            if (count _usableBuildings > 0) then {
                [_group, _usableBuildings] spawn fnc_civ_informant_wp_Tomata;
            };

            diag_log format ["[CIV] Informant generated at %1 (rep %2, distance to nearest player %3m)", _centerPos, _rep, _minDist];

            // 30分钟后自动删除线人
            [_unit, _group] spawn {
                params ["_unit", "_group"];
                sleep 1800;
                if (!isNull _unit) then { deleteVehicle _unit; };
                if (!isNull _group) then { deleteGroup _group; };
            };
        };
    };
};