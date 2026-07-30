// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([0, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_markerText2 = localize "STR_DUWS_T_c0";
_radius = 300;
_positions_needed = 5;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_Signal";
_message = localize "STR_DUWS_T_squadletsdothis";
_message1 = localize "STR_DUWS_T_squadoverlord";

// find some buildings for squad to hide
_usableBuildings = [];
_usableBuildings = [_MissionPos,_positions_needed,_radius] call fnc_usableBuildings;

if (count _usableBuildings < 2) exitWith {
	[0, "STR_DUWS_T_mission_no_building"] call fnc_mission_abort;
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_Building = _usableBuildings select (floor (random (count _usableBuildings)));
_BuildingPos = getPos _Building;
_targetpos = _BuildingPos;

_markername2 = [_MissionPos, _radius] call fnc_missionMarkerData;

// Create soldiers  -- BEGIN
_soldier1 = format ["s1%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
_soldier2 = format ["s2%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];    
_soldier3 = format ["s3%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];    

_group = createGroup west;

blufor_SOLDIER_TL_X createUnit [[(_BuildingPos select 0),(_BuildingPos select 1)+30], _group,format["this setcaptive true; %1 = this",_soldier1],blufor_ai_skill_random];
blufor_SOLDIER_LAT_X createUnit [[(_BuildingPos select 0),(_BuildingPos select 1)+31], _group,format["this setcaptive true; %1 = this",_soldier2],blufor_ai_skill_random];
blufor_SOLDIER_AR_X createUnit [[(_BuildingPos select 0),(_BuildingPos select 1)+32], _group,format["this setcaptive true; %1 = this",_soldier3],blufor_ai_skill_random];

sleep 5;
_randPos = selectRandom [3,4,5];
_safePos = _Building buildingPos _randPos;
_rand = random 1;
{
	_x setPosATL [_safePos select 0,(_safePos select 1)+_rand,_safePos select 2];
	// switchMove is local, so posing from the server held the captives on a hosting player's
	// screen and left every client a squad standing about. Keyed so a joiner finds them held,
	// and the key is dropped when they are freed.
	[_x, "acts_CrouchingIdleRifle01"] remoteExec ["switchMove", 0, format ["rescue_pose_%1", netId _x]];
	_rand = random 1;
} forEach units _group;

// function to execute on captive squad when players are near
fnc_rescue_squad_uncaptive = {
    params ["_markername2","_sol1","_sol2","_sol3","_MissionPos","_targetPos","_radius","_mission_name"];
    
    {
        _x setcaptive false;
        [_x, ""] remoteExec ["switchMove", 0];
        remoteExec ["", format ["rescue_pose_%1", netId _x]];
    } forEach [_sol1,_sol2,_sol3];
    [{hint localize "STR_DUWS_T_xdbfx123"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    
};

// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_speaker1, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_VARtaskgeneratedName, localize "STR_DUWS_T_kievbwmd", _mission_name, _MissionPos, "help"] call fnc_missionTaskCreate; 

// trigger to uncaptive squad when players are near
_trg=createTrigger["EmptyDetector",_Building];
_trg setTriggerArea[200,200,0,false, 20];
_trg setTriggerActivation["WEST","PRESENT",false];
_trg setTriggerStatements["this",format["[""%1"",%2,%3,%4,%5,%6,%7,""%8""] spawn fnc_rescue_squad_uncaptive",_markername2,_soldier1,_soldier2,_soldier3,_MissionPos,_targetPos,_radius,_mission_name], ""];
_trg setTriggerTimeout [10, 10, 10, true ]; 

// CREATE TRIGGER ZONES
_trg=createTrigger["EmptyDetector",_Building];
_trg setTriggerArea[100,100,0,false, 20];
_trg setTriggerActivation["WEST","PRESENT",false];
_trg setTriggerStatements["this",format["[""%1"",%2,%3,%4,%5,%6,%7,""%8""] spawn fnc_rescue_squad_success",_markername2,_soldier1,_soldier2,_soldier3,_MissionPos,_targetPos,_radius,_mission_name], ""];
_trg setTriggerTimeout [10, 10, 10, true ];  

sleep 10;

// CREATE OPFOR PATROLS
[_MissionPos, _radius] spawn fnc_missionPatrols;

sleep 5; // 等待巡逻队生成完毕
