// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
// fnc_createZone.sqf
//  _generatezonescript = ["",_points_zone,_zone_radius,_MissionPos,_fortified,true,_i] spawn fnc_createzone
//  Name of the place,pts,radius,position,fortified,prefab,zone#
//

_name = _this select 0; //name
_points = _this select 1;
_size = _this select 2;
_zonePos = _this select 3;  //position
_fortified = _this select 4;
_prefab = _this select 5;
_zone_num = _this select 6;
// Named here rather than by the locator that sited it: the manual placer's map-click body runs on
// the clicking client, and the allocator is server-side. An empty name asks for the next one, which
// is what both locators pass -- the zone number survives only as an index for the arrays below.
if (_name == "") then { _name = [] call fnc_zone_name };
// Zone visibility
_visible = true;
if (hardcore_mode_enable) then {_visible = false};


amount_zones_created = amount_zones_created + 1;
publicVariable "amount_zones_created";
zones_created = true; // Tell that at least 1 zone is created
publicVariable "zones_created";

// Add the zone to the array of zones (need for manual placement of zones and WARCOM)
if (isNil ("Array_of_OPFOR_zones")) then {Array_of_OPFOR_zones = [];};
Array_of_OPFOR_zones = Array_of_OPFOR_zones + [_zonePos];
// Add the zone name, position, and visibility(hardcore) to zone_namePOS_pairs 
zone_namePOS_pairs = zone_namePOS_pairs + [[_name,_zonePos,_visible]];
publicVariable "zone_namePOS_pairs";
// Everything needed to rebuild this zone through this same function: radius and points reach the
// triggers only as compiled strings, so nothing outside can read them. Must stay above the prefab
// block, which reassigns _fortified and _prefab to the chosen decoration. The name is re-derived
// from the zone number on rebuild, not stored -- it is localised at creation.
zone_meta_array = zone_meta_array + [[_zone_num,_zonePos,_size,_points,_fortified,_prefab]];
publicVariable "zone_meta_array";

// Add zone to the spawn/despawn array [number, blufor_close, noDespawn]
zone_spawn_array = zone_spawn_array + [[_zone_num,false,false]];

["INFO", "ZONES", format ["zone %1 registered at %2, worth %3, size %4, fortified=%5, prefab=%6",
	_zone_num, _zonePos, _points, _size, _fortified, _prefab]] call fnc_log;

// CREATE MARKER (ICON)
_markername = format["%1%2",round(_zonePos select 0),round(_zonePos select 1)]; // Define marker name
_markerstr = createMarker [str(_markername),_zonePos];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "o_inf";
str(_markername) setMarkerColor "ColorRed";
str(_markername) setMarkerText _name;
str(_markername) setMarkerSize [0, 0];
if (hardcore_mode_enable) then {
	str(_markername) setMarkerAlpha 0; 
} else {	
	str(_markername) setMarkerAlpha 1; 
};

// CREATE MARKER (ELLIPSE ZONE)
_markername2 = format["%1%2ellipse",round(_zonePos select 0),round(_zonePos select 1)];
_markerstr2 = createMarker [str(_markername2),_zonePos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
str(_markername2) setMarkerColor "ColorRed";
str(_markername2) setMarkerSize [_size, _size];
if (hardcore_mode_enable) then {
	str(_markername2) setMarkerAlpha 0; 
} else {	
	str(_markername2) setMarkerAlpha 0.3; 
};

// ========== 清理战区中心周围的障碍物 ==========
// Registered once for the whole campaign, on the first zone that clears ground. A terrain object
// cannot be deleted, so the pass below hides it instead -- and the engine swaps a hidden building
// for a fresh, visible one the moment its damage state changes, which is a grenade landing
// anywhere near the zone. The replacement is hidden in its turn and takes the old one's place in
// the register, so a house that is damaged twice does not come back on the second hit.
if (isNil "DUWS_zone_hidden") then {
    DUWS_zone_hidden = [];
    addMissionEventHandler ["BuildingChanged", {
        params ["_old", "_new"];
        private _i = DUWS_zone_hidden find _old;
        if (_i < 0) exitWith {};
        _new hideObjectGlobal true;
        DUWS_zone_hidden set [_i, _new];
    }];
};

if (_prefab) then {
    private _clearRadius = 35;
    private _allObjects = nearestObjects [_zonePos, [], _clearRadius];
    private _deletedCount = 0;
    private _hiddenCount = 0;
    {
        if (!isPlayer _x &&
            !(_x isKindOf "Man") &&
            !(_x isKindOf "Land_HelipadEmpty_F") &&
            !(_x isKindOf "FlagPole_F") &&
            !(_x isEqualTo bluHQ_object) &&
            !(_x in Array_of_FOBS)) then
        {
            deleteVehicle _x;
            if (isNull _x) then {
                _deletedCount = _deletedCount + 1;
            } else {
                _x hideObjectGlobal true;
                DUWS_zone_hidden pushBack _x;
                _hiddenCount = _hiddenCount + 1;
            };
        };
    } forEach _allObjects;
    if (_deletedCount > 0 || _hiddenCount > 0) then {
        ["INFO", "ZONES", format ["Cleared %1 objects at zone center %2 (%3 deleted, %4 hidden)",
            _deletedCount + _hiddenCount, _zonePos, _deletedCount, _hiddenCount]] call fnc_log;
    };
    sleep 0.5;
};

// CREATE PREFAB
if (_prefab) then {
	_array_of_prefabs = [];

	switch (VERSION_X) do {
		case "MODERN": {
			_array_of_prefabs = [
				["Vehicle Refit",true,fnc_modern_vehfittingstation,0.1],
				["Storage Bunker",true,fnc_modern_StorageBunker,0.12],
				["Comm Station",true,fnc_modern_CommStation,0.14],
				["Recon Outpost",true,fnc_modern_reconOutpost,0.1],
				["Outpost",true,fnc_modern_outpost1,0.1],
				["Outpost",true,fnc_modern_Outpost2,0.1],
                ["Field Hospital", true, fnc_modern_FieldHospital, 0.2]
			];
		};
	};
	_amount_of_prefabs = count _array_of_prefabs;
	_indexedAmount = _amount_of_prefabs - 1;
	_dice = round random _indexedAmount;

	_prefab_array = selectRandomWeighted [
		(_array_of_prefabs select 0),((_array_of_prefabs select 0) select 3),	
		(_array_of_prefabs select 1),((_array_of_prefabs select 1) select 3),	
		(_array_of_prefabs select 2),((_array_of_prefabs select 2) select 3),	
		(_array_of_prefabs select 3),((_array_of_prefabs select 3) select 3),	
		(_array_of_prefabs select 4),((_array_of_prefabs select 4) select 3),	
		(_array_of_prefabs select 5),((_array_of_prefabs select 5) select 3),
		(_array_of_prefabs select 6),((_array_of_prefabs select 6) select 3)
	];
	 
	// The composition's kind, not the zone's name -- it used to overwrite the name, which is why a
	// capture reported "Comm Station" while the map called the same ground Zone 4. It stays a
	// subtitle on the marker, where what is built there is worth knowing before travelling to it.
	_prefabName = _prefab_array select 0;
	_fortified = _prefab_array select 1;
	_path = _prefab_array select 2;

	[_zonePos] spawn _path;
	str(_markername) setMarkerText format["%1 (%2)", _name, _prefabName];

} else {
	switch (VERSION_X) do {
		case "MODERN": {
			_prefab = ["Outpost",true,fnc_modern_simple_zone];
		};
	};
	_prefabName = _prefab select 0;
	_fortified = _prefab select 1;
	_path = _prefab select 2;

	[_zonePos] spawn _path;
	str(_markername) setMarkerText format["%1 (%2)", _name, _prefabName];
};

// ========== 随机放置 3-4 个工事建筑，并记录到全局数组 ==========
private _fortificationClasses = [
    "Land_GuardTower_02_F",
    "Land_Cargo_Tower_V2_F",
    "Land_Cargo_Patrol_V2_F",
    "Land_BagBunker_Tower_F",
    "Land_Bunker_01_tall_F"
];
private _fortificationCount = 3 + floor random 2; // 3-4 个
private _radius = _size * 0.7; // 在战区半径70%范围内放置
private _zoneFortifications = []; // 存储放置的建筑对象
for "_i" from 1 to _fortificationCount do {
    private _angle = random 360;
    private _dist = random _radius;
    private _candidatePos = _zonePos getPos [_dist, _angle];
    private _safePos = [0,0,0];
    private _waterCheck = true;
    private _attempts = 0;
    
    // 循环直到找到非水域位置（最多10次）
    while {_waterCheck && _attempts < 10} do {
        _angle = random 360;
        _dist = random _radius;
        _candidatePos = _zonePos getPos [_dist, _angle];
        _safePos = [_candidatePos, 0, 50, 5, 0, 0.5, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        if (_safePos isEqualTo [0,0,0]) then { _safePos = _candidatePos; };
        // 检查是否在水面上
        if (!surfaceIsWater _safePos) then {
            _waterCheck = false;
        };
        _attempts = _attempts + 1;
    };
    // 如果最终位置仍在水面，跳过该建筑
    if (surfaceIsWater _safePos) then {
        ["WARN", "ZONES", format ["Skipping fortification due to water at %1", _safePos]] call fnc_log;
        continue;
    };
    
    private _nearRoad = [_safePos, 10] call BIS_fnc_nearestRoad;
    if (!isNull _nearRoad) then {
        _safePos = [_safePos getPos [15, _angle], 0, 10, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_safePos isEqualTo [0,0,0]) then { continue };
        if (surfaceIsWater _safePos) then { continue };
    };
    private _nearObjs = nearestObjects [_safePos, [], 8];
    if (count _nearObjs > 0) then { continue };
    private _fortClass = selectRandom _fortificationClasses;
    private _fort = createVehicle [_fortClass, _safePos, [], 0, "CAN_COLLIDE"];
    _fort setDir (random 360);
    _fort setVectorUp [0,0,1];
    _fort allowDamage true;
    // Filed under the zone like the prefab is. These stood outside the bucket model until now,
    // surviving only because a building is invisible to the sweep -- which is the same reason
    // their ruins were never collected either.
    [_fort, format ["zone_%1_%2", round (_zonePos select 0), round (_zonePos select 1)]] call fnc_duws_keep;
    _zoneFortifications pushBack _fort;
    ["INFO", "ZONES", format ["Placed fortification %1 at %2 for zone %3", _fortClass, _safePos, _zone_num]] call fnc_log;
};
missionNamespace setVariable [format ["ZoneFortifications_%1", _zone_num], _zoneFortifications];
// ================================================

// No QRF listener. A hidden object sat here carrying a FiredNear handler, so the first shot fired
// anywhere in the zone spawned up to four infantry waves at a distant OPFOR zone and walked them in
// -- reinforcement the player could neither see coming nor interdict. Tasking OPFOR reserves is the
// commander's job, and the plan for it is docs/opfor_commander_plan.md.

// CREATE ZONE NOTIFICATION TRIGGER
_trg2=createTrigger["EmptyDetector",_zonePos];
_trg2 setTriggerArea[_size,_size,0,false];
_trg2 setTriggerActivation["ANYPLAYER","PRESENT",true];
_trg2 setTriggerStatements["this", format["['%1',%2,'%3','%4',thislist] spawn fnc_enterlocation;",_name,_zonePos,_markername,_markername2], ""];
// The handle is not filed anywhere. Nothing deletes this trigger -- a zone lives for the
// campaign and its notification fires whoever owns the ground -- so there is no reader to keep
// one for. The capture trigger beside it is filed, under trigger_<x>_<y>, because fnc_captured
// and fnc_blufor_cap rewrite it on every ownership change.

// Enemy contact on ground the player holds, the same report the HQ and every FOB already make.
// Only that direction: walking into enemy ground is something the player chose and can see, so it
// announces nothing, while a counter-attack on a zone they took is news they cannot be present for.
// Server-local, so the dialogue is raised once no matter how the engine treats a global trigger's
// statement -- a question fnc_captured.sqf:15 records as unproven rather than answered.
private _trgEnemy = createTrigger ["EmptyDetector", _zonePos, false];
_trgEnemy setTriggerArea [_size, _size, 0, false];
_trgEnemy setTriggerActivation ["EAST", "PRESENT", true];
// Carried on the trigger, not formatted into the statement string, so this position never becomes
// text and back.
_trgEnemy setVariable ["DUWS_zonePos", _zonePos];
_trgEnemy setVariable ["DUWS_zoneName", _name];
// Tested as BLUFOR-held rather than not-OPFOR-held, so a zone in neither list stays quiet.
//
// The distance test below is an identity lookup -- "which zone is this" -- not a proximity check.
// Whether enemies are here is already answered by the trigger area above; this only asks whether
// the entry in the ownership list is *this* zone. It cannot use `==` or `in`, because the entry on
// the other side has been through text: the capture trigger formats its position into a statement
// string (`%5` below), so what fnc_zone_control_set files was parsed back out of characters and
// need not equal the array this zone was built from. The metre is float slop, not a game distance
// -- it could be 0.5 or 5 and mean the same thing, and it must not be folded in with the real
// radii the streaming checks use.
_trgEnemy setTriggerStatements [
    "this && {private _p = thisTrigger getVariable ['DUWS_zonePos', []];
        (WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _p) < 1 }) >= 0}",
    "[thisTrigger getVariable ['DUWS_zoneName', ''], thisList] call fnc_enemy_contact;",
    ""
];
// Same debounce as the HQ's: OPFOR crossing the boundary on patrol would otherwise re-report on
// every pass.
_trgEnemy setTriggerTimeout [10, 10, 10, true];

_spawnPos = _zonePos;

// The key everything about this zone files under: its stowed composition, its streaming thread, its
// garrison peak and the flag on every unit it spawns. Derived once here through the shared helper
// rather than spelled out per caller, so the readers cannot drift apart.
private _zoneKey = [_zonePos] call fnc_zone_key;

// Rolled before anything spawns, because both spawn paths read it to size themselves. A rebuild
// through this same function keeps the tier it already has -- the roll refuses to run twice.
private _zoneTier = [_zoneKey] call fnc_zone_tier_roll;
["INFO", "ZONES", format ["%1 is tier %2, fielding %3 of its band", _zoneKey, _zoneTier,
	DUWS_zoneTierForce select (_zoneTier - 1)]] call fnc_log;

// Build-out ends here: markers, prefab, fortifications and triggers are all placed. What
// follows is OPFOR spawning and then a permanent despawn monitor, so this is the last point
// at which this function can report completion -- it never returns.
zones_buildout_done = zones_buildout_done + 1;
publicVariable "zones_buildout_done";

_index = zone_spawn_array find [_zone_num,false,false];
_opfor_spawn = (zone_spawn_array select _index) select 1;

sleep 60;
[_spawnPos,_size,_index] spawn fnc_spawnWait;

// ✅ 修复：将占领触发器和旗杆创建代码移到 while 循环之前，确保它们能够执行

// CREATE ZONE CAPTURABLE TRIGGER
// Server-local, unlike the notification trigger above it: the capture condition reads the zone's
// garrison peak, which is a server-side global, so a client evaluating it would answer for state it
// cannot see. It also settles the locality question fnc_captured.sqf records as unproven.
_trg = createTrigger ["EmptyDetector", _zonePos, false];
_trg setTriggerArea [_size, _size, 0, false];
// PRESENT rather than SEIZED on the BLUFOR direction. SEIZED demands the whole area be empty of
// OPFOR, which made a capture a sweep of every last patrol out to the zone radius; the condition
// asks instead whether the garrison is beaten and the objective itself is clear, and what is left
// in the ring withdraws once the zone flips (fnc_spawnWait.sqf).
_trg setTriggerActivation ["WEST", "PRESENT", true];
// Carried on the trigger rather than formatted into the condition, so this position never becomes
// text and back -- the same reason the enemy-contact trigger above carries its own. Both ride the
// trigger through every ownership change, so the handlers that re-arm it move only the activation
// and the statement.
_trg setVariable ["DUWS_zonePos", _zonePos];
_trg setVariable ["DUWS_zoneKey", _zoneKey];
// Seventh argument is the zone's opening CP bounty; _points stays its permanent worth. The
// two travel together for the rest of the campaign, round the capture handlers and back here.
_trg setTriggerStatements ["this && {[thisTrigger] call fnc_zone_capture_ready}", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_captured", _name, _points, _markername, _markername2, _zonePos, _size, round(_points * zone_cp_capture)], ""];
_trg setTriggerTimeout [30, 40, 50, true];

// 存储触发器变量（统一使用 floor abs 避免负号）
private _trgVarName = format["trigger_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
missionNamespace setVariable [_trgVarName, _trg];
_trg setVariable ["isZoneCaptureTrigger", true];

// IF MODERN or SIMPLE ZONES, CREATE ZONE FLAG WITH RANDOM OFFSET AND STORE VARIABLE
if (VERSION_X == "MODERN" || simple_zones_enable) then {
    // 随机偏移距离：15 到 25 米
    private _offsetDist = 15 + random 10;
    // 随机方向
    private _offsetDir = random 360;
    // 计算偏移后的位置
    private _flagPos = _zonePos getPos [_offsetDist, _offsetDir];
    
    // 确保旗杆不悬空（使用安全位置查找）
    private _safePos = [_flagPos, 0, 3, 1, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0,0]) then { _safePos = _flagPos };
    _safePos set [2, 0];
    
    private _flg = "FlagPole_F" createVehicle _safePos;
    private _flagVarName = format["flag_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
    missionNamespace setVariable [_flagVarName, _flg];
    _flg setFlagTexture "\A3\Data_F\Flags\flag_red_CO.paa";
};

// ✅ 战区重生/清理循环（必须在最后，因为它是无限循环）
while {true} do {
	if (_opfor_spawn == true) then {
		_opfor_spawn = false;
		(zone_spawn_array select _index) set [1,false];
		// Read, not bumped: fnc_spawnWait opens the cycle when it deploys the composition, because
		// the turret crews it raises there are garrison and a roster emptied here would drop them.
		// Both threads below are handed the key and append what they raise; the capture test counts
		// that roster, so anything spawned here and not appended is invisible to it. The generation
		// carried into the band is what stops a band still placing from a previous cycle publishing
		// a garrison peak over the top of this one.
		private _gen = [_zoneKey] call fnc_zone_gen;
		[_spawnPos, _zoneKey] spawn fnc_createopfortified;
		sleep 2;
		[_spawnPos,_size,_zoneKey,_gen] spawn fnc_zone_spawn;
	};
	// Waits for the next spawn signal from fnc_spawnWait. Slot 2 of the entry used to carry a
	// "never despawn again" flag; nothing sets it now that despawn is decided by a grace period
	// that restarts whenever BLUFOR are seen, so a zone always comes back round to this loop.
	while {true} do {
		if (_opfor_spawn == true) exitWith {};
		sleep 10;
		_opfor_spawn = (zone_spawn_array select _index) select 1;
	};
	if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};
};