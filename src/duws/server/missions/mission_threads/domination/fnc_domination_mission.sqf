// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([13, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 800;
_cpreward = 10;
_apreward = 30;
_speaker = localize "STR_DUWS_T_hound";
_speaker1 = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_dominationletsdothis";
_message1 = ([localize "STR_DUWS_T_dominationoverlord"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_dominationcopy"] call fnc_cs);
_message3 = ([localize "STR_DUWS_T_dominationend"] call fnc_cs);
_messagehoundlost = ([localize "STR_DUWS_T_dominationhoundlost"] call fnc_cs);


_apcMarkers = [];

private _site = [_MissionPos, _radius, 13] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["combat%1%2", round(_MissionPos select 0), round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_domination", _mission_name, _randomPos, "attack"] call fnc_missionTaskCreate;

["Armor Hunting",{hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

sleep 2;


_fn_waterproofBluforVehicleCenter = {
    params ["_centerPos", "_spawnRadius", "_vehicleType", "_faceDirection"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    while {_attempts < 10 && !_validPos} do {
        _randomAngle = random 360;
        _randomDistance = random _spawnRadius;
        _spawnPos = _centerPos getPos [_randomDistance, _randomAngle];
        
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // avoid a busy loop
    };
    
    if (!_validPos) then {
        _randomAngle = random 360;
        _randomDistance = random _spawnRadius;
        _spawnPos = _centerPos getPos [_randomDistance, _randomAngle];
    };
    
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    _vehicle = createVehicle [_vehicleType, _groundPos, [], 0, "NONE"];
    _vehicle setDir _faceDirection;
    
    _vehicle
};

_fn_createBluforCrewGroup = {
    params ["_vehicle", "_centerPos", "_unitTypes", "_faceDirection"];
    
    _crewGroup = [getPos _vehicle, WEST, _unitTypes, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
    
    _units = units _crewGroup;
    
    if (count _units >= 1) then {
        _units select 0 assignAsDriver _vehicle;
        (_units select 0) moveInDriver _vehicle;
    };
    
    if (count _units >= 2) then {
        _units select 1 assignAsGunner _vehicle;
        (_units select 1) moveInGunner _vehicle;
    };
    
    if (count _units >= 3) then {
        _units select 2 assignAsCommander _vehicle;
        (_units select 2) moveInCommander _vehicle;
    };
    
    {
        if (!(_x in _vehicle)) then {
            _x moveInCargo _vehicle;
        };
    } forEach _units;
    
    {
        _x allowDamage false;
        _x allowFleeing 0;
        
        // AUTOCOMBAT left enabled on purpose: the AI engages on its own
        
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        _x setDir _faceDirection;
        
    } forEach units _crewGroup;
    
    _crewGroup deleteGroupWhenEmpty true;
    // Claimed after they are seated, not at spawn: fnc_mission_claim stamps the vehicle a unit is
    // in, and at spawn they are all still standing next to it.
    [_crewGroup] call fnc_mission_claim;
    
    _crewGroup
};

_fn_waterproofOpforGroupEdge = {
    params ["_centerPos", "_radius", "_unitTypes", "_opforAngle"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    while {_attempts < 10 && !_validPos} do {
        _angleVariation = (random 60) - 30;
        _currentAngle = _opforAngle + _angleVariation;
        
        while {_currentAngle >= 360} do {_currentAngle = _currentAngle - 360};
        while {_currentAngle < 0} do {_currentAngle = _currentAngle + 360};
        
        _distanceVariation = _radius * (0.8 + random 0.2);
        _spawnPos = _centerPos getPos [_distanceVariation, _currentAngle];
        
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // avoid a busy loop
    };
    
    if (!_validPos) then {
        _spawnPos = _centerPos getPos [_radius, _opforAngle];
    };
    
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    _opforGroup = [_groundPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    [_opforGroup] call fnc_mission_claim;
    {
    [_x] call fnc_addRandomLoot;
    } forEach units _opforGroup;
    {
        _x allowFleeing 0;
        
        // AUTOCOMBAT left enabled on purpose: the AI engages on its own
        
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        _x setUnitPos "AUTO";
        
        _x setDir (_opforAngle - 180);
        
    } forEach units _opforGroup;
    
    _opforGroup deleteGroupWhenEmpty true;
    
    _opforGroup
};

_fn_waterproofOpforVehicleEdge = {
    params ["_centerPos", "_radius", "_vehicleType", "_opforAngle"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    while {_attempts < 10 && !_validPos} do {
        _angleVariation = (random 60) - 30;
        _currentAngle = _opforAngle + _angleVariation;
        
        while {_currentAngle >= 360} do {_currentAngle = _currentAngle - 360};
        while {_currentAngle < 0} do {_currentAngle = _currentAngle + 360};
        
        _distanceVariation = _radius * (0.8 + random 0.2);
        _spawnPos = _centerPos getPos [_distanceVariation, _currentAngle];
        
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // avoid a busy loop
    };
    
    if (!_validPos) then {
        _spawnPos = _centerPos getPos [_radius, _opforAngle];
    };
    
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    _vehicle = createVehicle [_vehicleType, _groundPos, [], 0, "NONE"];
    _vehicle setDir _opforAngle;
    
    _vehicle
};

_fn_createOpforCrewGroup = {
    params ["_vehicle", "_centerPos", "_unitTypes", "_faceDirection"];
    
    _crewGroup = [getPos _vehicle, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    
    _units = units _crewGroup;
    
    if (count _units >= 1) then {
        _units select 0 assignAsDriver _vehicle;
        (_units select 0) moveInDriver _vehicle;
    };
    
    if (count _units >= 2) then {
        _units select 1 assignAsGunner _vehicle;
        (_units select 1) moveInGunner _vehicle;
    };
    
    if (count _units >= 3) then {
        _units select 2 assignAsCommander _vehicle;
        (_units select 2) moveInCommander _vehicle;
    };
    
    {
        if (!(_x in _vehicle)) then {
            _x moveInCargo _vehicle;
        };
    } forEach _units;
    
    {
        _x allowDamage false;
        _x allowFleeing 0;
        
        // AUTOCOMBAT left enabled on purpose: the AI engages on its own
        
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        _x setDir _faceDirection;
        
    } forEach units _crewGroup;
    
    _crewGroup deleteGroupWhenEmpty true;
    // Claimed after they are seated, not at spawn: fnc_mission_claim stamps the vehicle a unit is
    // in, and at spawn they are all still standing next to it.
    [_crewGroup] call fnc_mission_claim;
    
    _crewGroup
};

_fn_validateOpforAngle = {
    params ["_centerPos", "_radius", "_initialAngle"];
    
    private ["_currentAngle", "_attempts", "_foundValidAngle", "_testPos"];
    
    _currentAngle = _initialAngle;
    _attempts = 0;
    _foundValidAngle = false;
    
    while {_attempts < 10 && !_foundValidAngle} do {
        _validPoints = 0;
        
        for "_i" from 0 to 2 do {
            _distance = _radius * (0.8 + (_i * 0.1));
            _testPos = _centerPos getPos [_distance, _currentAngle];
            
            if (!surfaceIsWater _testPos) then {
                _validPoints = _validPoints + 1;
            };
        };
        
        if (_validPoints >= 2) then {
            _foundValidAngle = true;
        } else {
            _currentAngle = _currentAngle + 45;
            if (_currentAngle >= 360) then {
                _currentAngle = _currentAngle - 360;
            };
            _attempts = _attempts + 1;
        };
        
        sleep 0.5;
    };
    
    if (!_foundValidAngle) then {
        _currentAngle = _initialAngle;
        ["INFO", "MISSION", format ["WARNING: NO suitable attack angle found, using original one: %1", _currentAngle]] call fnc_log;
    };
    
    _currentAngle
};


_initialOpforAngle = random 360;
_opforAngle = [_MissionPos, _radius, _initialOpforAngle] call _fn_validateOpforAngle;

_bluforSpawnRadius = 150;
_redSpawnRadius = _radius - 50;

_bluforFaceDir = _opforAngle;

_bluforVehicleGroups = [];
_bluforInfantryGroups = [];
_bluforUnitsAll = [];
_bluforAPCs = [];

_bluforCrewTypes = [
    blufor_SOLDIER_X,      // driver
    blufor_SOLDIER_X,      // gunner
    blufor_SOLDIER_X       // commander
];

for "_i" from 1 to 2 do {
    _bluforAPC = [_MissionPos, _bluforSpawnRadius, blufor_APC1_X, _bluforFaceDir] call _fn_waterproofBluforVehicleCenter;
    
    _bluforAPCs pushBack _bluforAPC;

    _apcMarkerName = format ["apc_marker_%1_%2", _i, round(time)];
    _apcMarker = createMarker [_apcMarkerName, getPos _bluforAPC];
    _apcMarker setMarkerType "o_unknown";
    _apcMarker setMarkerColor "ColorBlue";
    _apcMarker setMarkerSize [1, 1];
    _apcMarker setMarkerText "APC";
    _apcMarkers pushBack _apcMarkerName;

    _bluforVehicleGroup = [_bluforAPC, _MissionPos, _bluforCrewTypes, _bluforFaceDir] call _fn_createBluforCrewGroup;
    
    {
        _bluforUnitsAll pushBack _x;
    } forEach units _bluforVehicleGroup;
    
    _bluforAPC allowDamage false;
    _bluforUnitsAll pushBack _bluforAPC;
    
    _bluforVehicleGroups pushBack _bluforVehicleGroup;
    
    _apcPos = getPos _bluforAPC;
    
    _bluforInfantryTypes = [
        blufor_SL_SOLDIER_X,
        blufor_TL_SOLDIER_X,
        blufor_AR_SOLDIER_X,
        blufor_MARK_SOLDIER_X,
        blufor_SL_SOLDIER_X,
        blufor_TL_SOLDIER_X,
        blufor_AR_SOLDIER_X,
        blufor_MARK_SOLDIER_X
    ];
    
    _infantryGroup = [_apcPos, WEST, _bluforInfantryTypes, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
    [_infantryGroup] call fnc_mission_claim;
    
    {
        _angle = random 360;
        _distance = 10 + random 5;
        _infantryPos = _apcPos getPos [_distance, _angle];
        
        if (surfaceIsWater _infantryPos) then {
            _infantryPos = _apcPos getPos [5, _angle];
        };
        
        _x setPos _infantryPos;
        
        _x allowDamage false;
        _x allowFleeing 0;
        
        // AUTOCOMBAT left enabled on purpose: the AI engages on its own
        
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        _x setUnitPos "AUTO";
        
        _x setDir _bluforFaceDir;
        
        _bluforUnitsAll pushBack _x;
        
    } forEach units _infantryGroup;
    
    _infantryGroup setBehaviour "COMBAT";
    _infantryGroup setCombatMode "RED";
    
    _infantryGroup deleteGroupWhenEmpty true;
    
    _bluforInfantryGroups pushBack _infantryGroup;
};

_opforGroups = [];
for "_i" from 1 to 3 do {
    _opforUnits = [
        opfor_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_GL_SOLDIER_X,
        opfor_AA_SOLDIER_X,
        opfor_TL_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_GL_SOLDIER_X
    ];
    
    _opforGroup = [_MissionPos, _redSpawnRadius, _opforUnits, _opforAngle] call _fn_waterproofOpforGroupEdge;
    _opforGroups pushBack _opforGroup;
};

_opforCrewTypes = [
    opfor_CREW_X,      // driver
    opfor_CREW_X,      // gunner
    opfor_CREW_X       // commander
];

_opforTanks = [];
_opforTankGroups = [];
_opforTankUnitsAll = [];

for "_i" from 1 to 4 do {
    _opforTank = [_MissionPos, _redSpawnRadius, opfor_MBT_TANK1_X, _opforAngle] call _fn_waterproofOpforVehicleEdge;
    
    _opforTankGroup = [_opforTank, _MissionPos, _opforCrewTypes, _opforAngle] call _fn_createOpforCrewGroup;
    {
        _opforTankUnitsAll pushBack _x;
    } forEach units _opforTankGroup;
    
    _opforTank allowDamage false;
    {
    [_x] call fnc_addRandomLoot;
    } forEach units _crewGroup;
    _opforTankUnitsAll pushBack _opforTank;
    
    _opforTanks pushBack _opforTank;
    _opforTankGroups pushBack _opforTankGroup;
};

_allOpforGroups = _opforGroups + _opforTankGroups;

{
    _bluforUnit = _x;
    {
        _bluforUnit reveal _x;
    } forEach _opforTanks;
    
    {
        {
            _bluforUnit reveal _x;
        } forEach units _x;
    } forEach _opforGroups;
    
    {
        {
            _bluforUnit reveal _x;
        } forEach units _x;
    } forEach _opforTankGroups;
} forEach _bluforUnitsAll;

_allRedUnits = [];
{
    _allRedUnits pushBack _x;
} forEach _opforTanks;
{
    {
        _allRedUnits pushBack _x;
    } forEach units _x;
} forEach _opforTankGroups;
{
    {
        _allRedUnits pushBack _x;
    } forEach units _x;
} forEach _opforGroups;

{
    _redUnit = _x;
    {
        _redUnit reveal _x;
    } forEach _bluforUnitsAll;
} forEach _allRedUnits;


_redSpawnPos = _MissionPos getPos [_redSpawnRadius, _opforAngle];

_attempts = 0;
_validMarkerPos = false;
while {_attempts < 10 && !_validMarkerPos} do {
    _testPos = _MissionPos getPos [_redSpawnRadius, _opforAngle + (random 60 - 30)];
    
    if (!surfaceIsWater _testPos) then {
        _redSpawnPos = _testPos;
        _validMarkerPos = true;
    };
    
    _attempts = _attempts + 1;
    sleep 0.5;
};

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;

_arrowDir = _redSpawnPos getDir _MissionPos;
_arrowMarkerName = format ["opfor_spawn_arrow_%1", round(time)];
_arrowMarker = createMarker [_arrowMarkerName, _redSpawnPos];
_arrowMarker setMarkerType "mil_arrow2";
_arrowMarker setMarkerColor "ColorRed";
_arrowMarker setMarkerDir _arrowDir;
_arrowMarker setMarkerSize [1.1, 1.1];
_arrowMarker setMarkerAlpha 0.7;
_arrowMarker setMarkerText localize "STR_DUWS_T_dominationarrow";
//Create the marker	

// TASK AND NOTIFICATION



_bluforAPCPositions = [];
{
    _bluforAPCPositions pushBack (getPos _x);
} forEach _bluforAPCs;

{
    _group = _x;
    {
        _wp = _group addWaypoint [_x, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointSpeed "FULL";
    } forEach _bluforAPCPositions;
    
    _wp2 = _group addWaypoint [_bluforAPCPositions select 0, 0];
    _wp2 setWaypointType "SAD";
    _wp2 setWaypointBehaviour "AWARE";
    _wp2 setWaypointCombatMode "RED";
    _wp2 setWaypointSpeed "FULL";
} forEach _allOpforGroups;

sleep 5;
{
    _x allowDamage true;
} forEach _bluforUnitsAll;

{
    _x allowDamage true;
} forEach _opforTankUnitsAll;


sleep 90;
{
    _x setDamage 1;
} forEach _bluforAPCs;
[_speaker1, _messagehoundlost] remoteExec ["fnc_duws_dialogue", 0];
waitUntil {
    sleep 3;
    
    _allCrewDead = true;
    {
        if ({alive _x} count units _x > 0) then {
            _allCrewDead = false;
        };
    } forEach _opforTankGroups;
    
    _allCrewDead
};

[_markername2] call fnc_missionMarkerClear;
deleteMarker _arrowMarkerName;
{ deleteMarker _x; } forEach _apcMarkers;

[_speaker1, _message3] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_MissionPos, _radius, "", true] call fnc_mission_end;