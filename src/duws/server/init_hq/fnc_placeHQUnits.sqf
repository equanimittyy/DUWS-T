// Locality: server -- called by init_hq/fnc_BluHQinit.sqf when the base is built and by
// misc/fnc_redeployHQUnits.sqf when the player rebuilds it.
//
// Both paths place the same six unit sets, so both run this. Every anchor is read from the
// HQ_redeploy_* keys rather than taken as an argument: the rebuild has nothing but those keys to
// work from, and passing them at build time would leave the two paths placing units from two
// different sources -- which is how the build and the rebuild drifted apart in the first place.
// The caller populates the anchor keys; the group keys written back here belong to this function.
//
// Safe to call unscheduled-free: both callers are scheduled (the build is spawned, the rebuild
// arrives by remoteExec), so the settle sleep below suspends rather than erroring.

if (!isServer) exitWith {};

// Model-space XY with world-space Z. A building's own modelToWorld Z is unusable on the tower and
// the tent alike, so every offset in this file was measured against getPosWorld and only the
// horizontal pair comes out of model space.
private _anchoredPos = {
    params ["_obj", "_xyModel", "_hOffset"];
    private _xy = _obj modelToWorld [_xyModel select 0, _xyModel select 1, 0];
    [_xy select 0, _xy select 1, (getPosWorld _obj select 2) + _hOffset]
};

// Simulation off across the hard placement, restored on a delay: a unit setPosWorld to an absolute
// Z starts falling before the engine accepts the position, and dies on landing. The tower guards
// wait longer than the rest because their drop is the tallest.
private _placeGuard = {
    params ["_worldPos", "_type", "_dir", "_anim", "_wake"];
    private _grp = [_worldPos, WEST, [_type], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    _unit allowDamage true;
    _unit enableSimulationGlobal false;
    _unit setPosWorld _worldPos;
    _unit setUnitPos "UP";
    _unit disableAI "PATH";
    _unit setDir _dir;
    [_unit, _anim, "FULL"] call BIS_fnc_ambientAnimCombat;
    [_unit, _wake] spawn {
        params ["_u", "_wake"];
        sleep _wake;
        if (!isNull _u && alive _u) then { _u enableSimulationGlobal true; };
    };
    _grp
};

private _hqObj = bluHQ_object;
private _guardTypes = missionNamespace getVariable ["HQ_redeploy_guardTypes", [blufor_SOLDIER_X]];

// 1. Static weapons and their gunners.
//
// Position and heading come off the "HQ Turrets" composition (init_hq/fnc_BluHQinit.sqf), so a gun
// is moved by rearranging the fence in the 3D editor rather than by re-measuring a model-space
// offset by hand. Only the height still rides an anchor: a row's Z is discarded by the prop
// placement, and these sit above the terrain by an amount measured against the anchor's
// getPosWorld for the reason stated at the head of this file.
private _weaponData = missionNamespace getVariable ["HQ_redeploy_weaponData", []];
private _weaponList = [];

{
    _x params ["_class", "_xy", "_dir", "_anchorClass", "_hOffset"];
    // Re-found against what is standing rather than carried as a reference, so a rebuild after the
    // anchor was destroyed still places the gun. No anchor at all falls back to the terrain, which
    // is where a gun with nothing to stand on belongs.
    private _anchor = nearestObject [[_xy select 0, _xy select 1, 0], _anchorClass];
    private _base = if (isNull _anchor) then {
        getTerrainHeightASL [_xy select 0, _xy select 1]
    } else {
        getPosWorld _anchor select 2
    };
    private _worldPos = [_xy select 0, _xy select 1, _base + _hOffset];
    private _obj = createVehicle [_class, _worldPos, [], 0, "CAN_COLLIDE"];
    // Filed under the HQ key on the rebuild as well as the build: an unregistered replacement is
    // not marked persistent, so the cleanup sweep is free to delete a gun the player just paid for.
    [_obj, "HQ"] call fnc_duws_keep;
    _obj enableSimulationGlobal false;
    _obj setPosWorld _worldPos;
    _obj setDir _dir;
    // Rotating displaces the object, so the position is written a second time after it -- the same
    // reason the composition deploy does (misc/fnc_composition_stream_init.sqf).
    _obj setPosWorld _worldPos;
    _weaponList pushBack _obj;
} forEach _weaponData;

sleep 0.5;

if (count _weaponList > 0) then {
    private _unitTypes = [];
    for "_i" from 1 to (count _weaponList) do { _unitTypes pushBack blufor_SOLDIER_X };
    private _spawnPos = PosOfBLUHQ findEmptyPosition [0, 50];
    if (count _spawnPos == 0) then { _spawnPos = PosOfBLUHQ; };
    private _guardGroup = [_spawnPos, WEST, _unitTypes, [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    _guardGroup deleteGroupWhenEmpty true;
    { (units _guardGroup select _forEachIndex) moveInGunner _x; } forEach _weaponList;
    { _x enableSimulationGlobal true; } forEach _weaponList;
    missionNamespace setVariable ["HQ_redeploy_weaponGroup", _guardGroup, true];
    missionNamespace setVariable ["HQ_redeploy_weaponList", _weaponList, true];
};

// 2. Tower guards.
//
// 塔卫放置流程逻辑总结（纯文本）：
//
// 核心问题：Land_GuardTower_02_F只有一个建筑位置，其Z高度不正确。modelToWorld的Z轴也不可用。
// 最终方案是将模型空间XY与世界空间Z结合。
//
// 第一步：在游戏中玩家需要站在塔顶目标位置，打开控制台执行：
// _tower = nearestObject [player, "Land_GuardTower_02_F"];
// _playerPos = getPosWorld player;
// _towerPos = getPosWorld _tower;
// _heightOffset = (_playerPos select 2) - (_towerPos select 2);
// _xyModel = _tower worldToModel _playerPos;
// 系统聊天输出或复制以下值：玩家世界位置、塔世界位置、高度偏移 _heightOffset、
// 模型XY偏移 _xyModel 中的前两个值
//
// 第二步：从输出中记录下关键数据。示例：
// 塔世界位置Z: 10.5261 / 玩家世界位置Z: 12.163 / 高度偏移: 1.6369
// 模型XY: [0.05, 1.47] (仅用前两个值，忽略Z)
//
// 第三步：在脚本中使用这些固定值 -- 即下方 _anchoredPos 的两个参数。
// 这样无论塔被放置在何处、何方向，塔卫都能准确站在玩家当初站立测试的位置。
// 无论如何不要删除这段备注！！
private _towers = missionNamespace getVariable ["HQ_redeploy_towers", []];
private _towerGuards = [];
{
    private _worldPos = [_x, [0.05, 1.47], 1.6369] call _anchoredPos;
    _towerGuards pushBack (
        [_worldPos, blufor_SOLDIER_X, getDir _x, selectRandom ["STAND_IA", "STAND"], 2.5] call _placeGuard
    );
} forEach _towers;
missionNamespace setVariable ["HQ_redeploy_towerGuards", _towerGuards, true];

// 3. The pair at the HQ door.
private _hqGuardsData = missionNamespace getVariable ["HQ_redeploy_hqGuardsData", []];
private _hqGuardsGroups = [];
{
    _x params ["_xyModel", "_hOffset", "_dir", "_anim"];
    private _worldPos = [_hqObj, _xyModel, _hOffset] call _anchoredPos;
    _hqGuardsGroups pushBack ([_worldPos, selectRandom _guardTypes, _dir, _anim, 0.5] call _placeGuard);
} forEach _hqGuardsData;
missionNamespace setVariable ["HQ_redeploy_hqGuardsGroup0", _hqGuardsGroups select 0, true];
missionNamespace setVariable ["HQ_redeploy_hqGuardsGroup1", _hqGuardsGroups select 1, true];

// 4. The pair at the medical tent.
private _medGuardsData = missionNamespace getVariable ["HQ_redeploy_medGuardsData", []];
private _medTent = objectFromNetId (missionNamespace getVariable ["HQ_medTent_netId", ""]);
private _medGuardsGroups = [];
{
    _x params ["_xyModel", "_hOffset", "_anim"];
    private _worldPos = [_medTent, _xyModel, _hOffset] call _anchoredPos;
    _medGuardsGroups pushBack (
        [_worldPos, selectRandom _guardTypes, (getDir _medTent) + 180, _anim, 0.5] call _placeGuard
    );
} forEach _medGuardsData;
missionNamespace setVariable ["HQ_redeploy_medGuardsGroup0", _medGuardsGroups select 0, true];
missionNamespace setVariable ["HQ_redeploy_medGuardsGroup1", _medGuardsGroups select 1, true];

// 5. The sentry in the guard box, standing on its highest building position.
private _guardBoxObj = objectFromNetId (missionNamespace getVariable ["HQ_guardBox_netId", ""]);
if (!isNull _guardBoxObj) then {
    private _bestPos = [0,0,0];
    private _idx = 0;
    while {true} do {
        private _pos = _guardBoxObj buildingPos _idx;
        if (_pos isEqualTo [0,0,0]) exitWith {};
        if ((_pos select 2) > (_bestPos select 2)) then { _bestPos = _pos };
        _idx = _idx + 1;
    };
    if (_bestPos isEqualTo [0,0,0]) then {
        _bestPos = getPosATL _guardBoxObj;
        _bestPos set [2, (_bestPos select 2) + 0.5];
    };
    private _grp = [_bestPos, selectRandom _guardTypes, (getDir _guardBoxObj) + 180, "STAND", 0.5] call _placeGuard;
    missionNamespace setVariable ["HQ_redeploy_guardBoxGroup", _grp, true];
};

// 6. The patrol that walks the towers.
private _patrolSpawnPos = missionNamespace getVariable ["HQ_redeploy_patrolSpawnPos", []];
private _patrolUnits = missionNamespace getVariable ["HQ_redeploy_patrolUnits", []];
if (count _patrolSpawnPos > 0 && count _patrolUnits > 0) then {
    private _patrolGroup = [_patrolSpawnPos, WEST, _patrolUnits, [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    _patrolGroup deleteGroupWhenEmpty true;
    {
        _x allowDamage false;
        _x enableSimulationGlobal false;
        _x setPosWorld _patrolSpawnPos;
    } forEach (units _patrolGroup);
    while {count (waypoints _patrolGroup) > 0} do { deleteWaypoint ((waypoints _patrolGroup) select 0); };
    // The anchors are this base's own towers, stood off far enough not to path into one. The circuit
    // itself is fnc_apply_posture's, shared with the FOB pair, which walks its corners on the same
    // orders and used to carry its own copy of this block.
    [_patrolGroup, "hqpatrol", _patrolSpawnPos, 0, _towers apply { _x getPos [15, getDir _x] }]
        call fnc_apply_posture;
    [_patrolGroup] spawn {
        params ["_grp"];
        sleep 1.5;
        {
            if (!isNull _x && alive _x) then {
                _x enableSimulationGlobal true;
                _x allowDamage true;
            };
        } forEach (units _grp);
    };
    missionNamespace setVariable ["HQ_redeploy_patrolGroup", _patrolGroup, true];
};

// The HQ registers as a frozen site on the same terms as a FOB. It was the one base that never got
// even a sleeper: its garrison stood fully simulated for the whole campaign on the reasoning that
// the player is usually stood in it -- which held when base was where you were, and stopped holding
// with fast travel, an MHQ and FOBs on the map.
//
// Registered after the placement above, so the roster describes what is actually standing. Woken by
// players or by hostiles, like a FOB: a base that cannot be woken by an attacker loses itself while
// nobody is looking.
if (!isNil "PosOfBLUHQ") then {
    ["HQ", PosOfBLUHQ, base_garrison_sleep_range, "freeze"] call fnc_site_register;
    ["HQ", "infantry", WEST, "base"] call fnc_site_occupant_register_profile;
    private _roster = ["HQ", "infantry"] call fnc_site_roster;
    ["HQ", "infantry"] call fnc_site_roster_clear;
    {
        private _grp = missionNamespace getVariable [_x, grpNull];
        if (!isNull _grp) then { _roster append (units _grp) };
    } forEach ["HQ_redeploy_weaponGroup", "HQ_redeploy_hqGuardsGroup0", "HQ_redeploy_hqGuardsGroup1",
        "HQ_redeploy_medGuardsGroup0", "HQ_redeploy_medGuardsGroup1", "HQ_redeploy_guardBoxGroup",
        "HQ_redeploy_patrolGroup"];
    // The tower guards are kept as a list of one-man groups rather than under a single name.
    { if (!isNull _x) then { _roster append (units _x) } }
        forEach (missionNamespace getVariable ["HQ_redeploy_towerGuards", []]);
    ["INFO", "BOOT", format ["HQ registered as a frozen site holding %1 men", count _roster]] call fnc_log;
};
