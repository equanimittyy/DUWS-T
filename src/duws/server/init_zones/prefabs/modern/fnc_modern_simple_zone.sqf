// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
_centerSpawn = _this select 0;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

_vehicle_0 = objNull;
if (true) then
{
  _this = createVehicle ["Land_MultiMeter_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
  _vehicle_0 = _this;
  _this setPos _centerSpawn;
};
_centerSpawnZ = (getpos _vehicle_0 select 2);
deleteVehicle _vehicle_0;

///////////////////////////////////////////////////////////////////////

// --DUWS-COMPOSITION BEGIN name="Simple Zone" schema=C--
_staticsArray = [
	["CamoNet_INDP_open_F",[0,0,0],0,1,0,[],"","",true,false] 
];
// --DUWS-COMPOSITION END--

// PLACE STATICS WITHOUT INTERACTION
_vehicle = objNull;
{
	_xyz = (_x select 1);
	_posX = (_xyz select 0);
	_posY = (_xyz select 1);
	_posZ = (_xyz select 2);
	_vehicle = createVehicle [(_x select 0), [0,0,0], [], 0, "CAN_COLLIDE"];
	_vehicle setDir (_x select 2);
	_vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
	_vehicle enableSimulationGlobal false;
} forEach _staticsArray;

// PLACE STATICS WITH INTERACTION
_vehicle_20 = objNull;
_this = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_vehicle_20 = _this;
_this setDir 0;
_this setPosATL [(_centerSpawnX)-0.1, (_centerSpawnY)-0.2, 0];
[_this,"opfor"] spawn fnc_fill_ammobox; 

// 迫击炮 (随机位置 + 安全检查)
_vehicle_999 = objNull;
if (true) then
{
  _found = false;
  _pos = [0,0,0];
  _attempts = 0;
  while {!_found && _attempts < 20} do {
    _rX = (_centerSpawnX) + (random 600) - 300;
    _rY = (_centerSpawnY) + (random 600) - 300;
    _candidate = [_rX, _rY, 0];
    _flat = _candidate isFlatEmpty [5, 0, 0.2, 5, 0, false, objNull];
    if (count _flat > 0 && !surfaceIsWater _candidate) then {
      _pos = _flat;
      _found = true;
    };
    _attempts = _attempts + 1;
  };
  if (!_found) then { _pos = [_rX, _rY, 0]; };
  _this = createVehicle ["B_Mortar_01_F", _pos, [], 0, "CAN_COLLIDE"];
  _vehicle_999 = _this;
  _this setDir 215.154;
};
_vehicle_999 setdamage 0;
  sleep 0.1;
  _vehicle_999 setVectorUp [0,0,1];

// 防空炮1 (随机位置 + 安全检查)
_vehicle_1000 = objNull;
if (true) then
{
  _found = false;
  _pos = [0,0,0];
  _attempts = 0;
  while {!_found && _attempts < 20} do {
    _rX = (_centerSpawnX) + (random 600) - 300;
    _rY = (_centerSpawnY) + (random 600) - 300;
    _candidate = [_rX, _rY, 0];
    _flat = _candidate isFlatEmpty [5, 0, 0.2, 5, 0, false, objNull];
    if (count _flat > 0 && !surfaceIsWater _candidate) then {
      _pos = _flat;
      _found = true;
    };
    _attempts = _attempts + 1;
  };
  if (!_found) then { _pos = [_rX, _rY, 0]; };
  _this = createVehicle ["B_static_AA_F", _pos, [], 0, "CAN_COLLIDE"];
  _vehicle_1000 = _this;
  _this setDir 215.154;
};
_vehicle_1000 setdamage 0;
  sleep 0.1;
  _vehicle_1000 setVectorUp [0,0,1];

// 防空炮2 (随机位置 + 安全检查)
_vehicle_1002 = objNull;
if (true) then
{
  _found = false;
  _pos = [0,0,0];
  _attempts = 0;
  while {!_found && _attempts < 20} do {
    _rX = (_centerSpawnX) + (random 600) - 300;
    _rY = (_centerSpawnY) + (random 600) - 300;
    _candidate = [_rX, _rY, 0];
    _flat = _candidate isFlatEmpty [5, 0, 0.2, 5, 0, false, objNull];
    if (count _flat > 0 && !surfaceIsWater _candidate) then {
      _pos = _flat;
      _found = true;
    };
    _attempts = _attempts + 1;
  };
  if (!_found) then { _pos = [_rX, _rY, 0]; };
  _this = createVehicle ["B_static_AA_F", _pos, [], 0, "CAN_COLLIDE"];
  _vehicle_1002 = _this;
  _this setDir 215.154;
};
_vehicle_1002 setdamage 0;
  sleep 0.1;
  _vehicle_1002 setVectorUp [0,0,1];

_groupAA = [[0,0], EAST, [opfor_SOLDIER_X,opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupAA deleteGroupWhenEmpty true;
_guardAA1 = units _groupAA select 0;
_guardAA2 = units _groupAA select 1;
_guardAA1 moveinGunner _vehicle_1000;
_guardAA2 moveinGunner _vehicle_1002;

_groupMTR = [[0,0], EAST, [opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupMTR deleteGroupWhenEmpty true;
_guardMTR1 = units _groupMTR select 0;
_guardMTR1 moveinGunner _vehicle_999;


_light1 = createVehicle ["Land_Camping_Light_F", [0,0,0], [], 0, "NONE"];
_light1 allowdamage false;
_light1 setdamage 0;
_light1 setpos _flagPos;