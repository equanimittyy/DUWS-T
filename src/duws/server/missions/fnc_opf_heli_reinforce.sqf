// fnc_opf_heli_reinforce.sqf
// 通用函数：监控区域（支线任务或战区）内敌军数量，当剩余 ≤ 初始1/4时触发直升机运兵增援。
// 参数：[ _center, _radius, _initialCountVar, _triggeredVar, _taskID (可选), _isZone (可选) ]
//   _isZone = true 时，直升机离开后不自动删除（保留自然消失）
// 执行端：服务器

if (!isServer) exitWith {};

params ["_center", "_radius", "_initialCountVar", "_triggeredVar", ["_taskID", ""], ["_isZone", false]];

private _initialCount = missionNamespace getVariable [_initialCountVar, -1];
if (_initialCount < 0) exitWith { ["WARN", "ZONES", format ["Initial count not set (%1)", _initialCountVar]] call fnc_log; };

// 初始敌军少于20则直接退出
if (_initialCount < 20) exitWith {
    ["INFO", "ZONES", format ["Initial enemy count (%1) < 20, reinforcement disabled.", _initialCount]] call fnc_log;
};

private _threshold = floor (_initialCount / 4);
if (missionNamespace getVariable [_triggeredVar, false]) exitWith {};

// 持续监控，同时检查 _triggeredVar 是否被外部设置为 true（如战区清理、任务结束）
waitUntil {
    sleep 5;
    if (missionNamespace getVariable [_triggeredVar, false]) exitWith { true };
    private _aliveEnemies = (allUnits select {
        side _x == EAST &&
        alive _x &&
        _x distance _center < _radius
    });
    (count _aliveEnemies <= _threshold)
};

// 再次检查是否被外部停止
if (missionNamespace getVariable [_triggeredVar, false]) exitWith {};

missionNamespace setVariable [_triggeredVar, true, true];
["INFO", "WARCOM", format ["heli reinforcement launched for %1 (defenders fell to %2 or fewer of %3)",
	_center, _threshold, _initialCount]] call fnc_log;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_HELIQRF1"] remoteExec ["fnc_duws_dialogue", 0];

[_center, _taskID, _isZone] spawn {
    params ["_center", "_taskID", "_isZone"];
    
    private _direction = random 360;
    if (!isNil "WARCOM_zones_controled_by_OPFOR") then {
        private _opfZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
        if (count _opfZones > 0) then {
            private _randomZone = selectRandom _opfZones;
            _direction = _center getDir _randomZone;
        };
    };
    
    private _dist = 1000 + random 1000;
    private _spawnPos = _center getPos [_dist, _direction];
    _spawnPos set [2, 150];
    private _flyoverPos = _center;
    private _exitPos = _center getPos [_dist, _direction + 180];
    
    private _heliType = missionNamespace getVariable ["opfor_TRANS_HELI_X", "I_Heli_light_03_unarmed_F"];
    
    private _heliGroup = [_spawnPos, EAST, [_heliType], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    private _heli = vehicle (leader _heliGroup);
    _heliGroup deleteGroupWhenEmpty true;
    
    _heli setVehicleAmmo 1;
    _heli engineOn true;
    _heli flyInHeight 150;
    _heli allowDamage true;
    
    private _wp1 = _heliGroup addWaypoint [_flyoverPos, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "CARELESS";
    _wp1 setWaypointSpeed "FULL";
    
    private _wp2 = _heliGroup addWaypoint [_exitPos, 0];
    _wp2 setWaypointType "MOVE";
    _wp2 setWaypointBehaviour "CARELESS";
    _wp2 setWaypointSpeed "FULL";
    
    private _opfAP = missionNamespace getVariable ["WARCOM_opfor_ap", 100];
    private _baseCount = 12;
    private _maxCount = 20;
    private _apFactor = (_opfAP / 200) min 1.0;
    private _troopCount = floor (_baseCount + (_maxCount - _baseCount) * _apFactor);
    _troopCount = _troopCount min _maxCount;
    
    private _possibleTypes = [
        opfor_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_GL_SOLDIER_X,
        opfor_LAT_SOLDIER_X,
        opfor_MARK_SOLDIER_X,
        opfor_SL_SOLDIER_X,
        opfor_TL_SOLDIER_X
    ] select { !isNil "_x" && {_x != ""} };
    if (count _possibleTypes == 0) then { _possibleTypes = ["O_Soldier_F"] };
    
    waitUntil { sleep 10; (!alive _heli) || (_heli distance _flyoverPos < 300) };
    
    if (!alive _heli) exitWith {
        ["INFO", "ZONES", "Helicopter destroyed before drop."] call fnc_log;
    };
    
    private _unitTypes = [];
    for "_i" from 1 to _troopCount do {
        _unitTypes pushBack (selectRandom _possibleTypes);
    };
    
    private _dropGroup = [_flyoverPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _dropGroup deleteGroupWhenEmpty true;
    _dropGroup setCombatMode "RED";
    _dropGroup setBehaviour "COMBAT";
    
    private _dropRadius = 200;
    private _troopsSpawned = 0;
    
    {
        private _unit = _x;
        private _safeRadius = if (isNil "_dropRadius") then { 200 } else { _dropRadius max 1 };
        
        private _posX = (_flyoverPos select 0) + (random _safeRadius) - (random _safeRadius);
        private _posY = (_flyoverPos select 1) + (random _safeRadius) - (random _safeRadius);
        private _posZ = (_flyoverPos select 2) + 50;
        
        if (isNil "_posX" || {isNil "_posY"} || {isNil "_posZ"}) then {
            _unit setPos _flyoverPos;
        } else {
            _unit setPos [_posX, _posY, _posZ];
        };
        
        private _chute = createVehicle ["Steerable_Parachute_F", getPos _unit, [], 0, "FLY"];
        _unit moveInDriver _chute;
        _unit allowDamage true;
        _troopsSpawned = _troopsSpawned + 1;
        sleep 0.5;
        if (!alive _heli) exitWith {};
    } forEach (units _dropGroup);
    
    [_dropGroup, _flyoverPos] spawn {
        params ["_group", "_center"];
        waitUntil { sleep 2; { (getPos _x) select 2 < 2 } count (units _group) == count (units _group) };
        
        private _wp1 = _group addWaypoint [_center getPos [random 150, random 360], 50];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointBehaviour "COMBAT";
        _wp1 setWaypointSpeed "FULL";
        _wp1 setWaypointCompletionRadius 30;
        
        private _wp2 = _group addWaypoint [_center getPos [random 200, random 360], 50];
        _wp2 setWaypointType "SAD";
        _wp2 setWaypointBehaviour "COMBAT";
        _wp2 setWaypointSpeed "FULL";
        _wp2 setWaypointCompletionRadius 50;
    };
    
    waitUntil { sleep 2; (!alive _heli) || (_heli distance _exitPos < 200) };
    
    if (alive _heli) then {
        sleep 30;
        { deleteVehicle _x } forEach units _heliGroup;
        deleteVehicle _heli;
    };
    
    ["INFO", "ZONES", format ["Reinforcement completed. Troops dropped: %1 (isZone=%2)", _troopsSpawned, _isZone]] call fnc_log;
};