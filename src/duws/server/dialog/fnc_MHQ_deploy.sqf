// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).

// MHQ must be empty to Deploy
_empty = (count (crew MHQ1)) == 0;
if (!_empty) exitWith {
	["info",[localize "STR_DUWS_T_ywl7naen",localize "STR_DUWS_T_bnw9muay"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
	["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,true];
};

_mhqDir = getDir MHQ1;

// 创建完全静止的虚拟驾驶员
_groupMHQ = [[0,0], WEST, ["C_Soldier_VR_F"], [], [], blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupMHQ deleteGroupWhenEmpty true;
_MHQdriver = units _groupMHQ select 0;

// 彻底隐藏并禁用AI
hideObjectGlobal _MHQdriver;
_MHQdriver disableAI "ALL";                     // 禁用所有AI
_MHQdriver setBehaviour "CARELESS";             // 漠不关心
_MHQdriver setCombatMode "BLUE";                // 永不接战
_MHQdriver allowFleeing 0;                      // 禁止逃跑
_MHQdriver enableSimulationGlobal false;
_MHQdriver forceSpeed 0;                        // 速度为0
_MHQdriver setVariable ["Vcm_Disable", true];   // 禁用VCOM AI（如已安装）
_MHQdriver setVariable ["lambs_danger_disableAI", true]; // 禁用LAMBS（如已安装）

// 放入载具（货物位，避免影响炮手/驾驶员位）
_MHQdriver moveInDriver MHQ1;

// Deploy the ammo box
_ammoPOS = MHQ1 getRelPos [6,120];
MHQ_ammobox = objNull;

switch (VERSION_X) do {
	case "MODERN": {
		MHQ_ammobox = createVehicle ["O_supplyCrate_F", _ammoPOS, [], 0, "CAN_COLLIDE"];
		[MHQ_ammobox, "MHQ"] call fnc_duws_keep;
	};
};	

MHQ_ammobox setDir _mhqDir;

// Put some crap in the ammobox
[MHQ_ammobox,"blufor"] spawn fnc_fill_ammobox; 

[[MHQ_ammobox,[localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal,[], 0, false, false, "", "_this distance _target < 8"]],"addAction",true,true] call BIS_fnc_MP;
[[MHQ_ammobox,[localize "STR_DUWS_T_xfgokhbc",fnc_AI_rearm,[], 0, false, false, "", "_this distance _target < 8"]],"addAction",true,true] call BIS_fnc_MP;

sleep 0.2;

// Deploy the Tent
MHQ_tent = objNull;
MHQ_tent = createVehicle ["CamoNet_INDP_big_F", getPos MHQ1, [], 0, "CAN_COLLIDE"];
MHQ_tent setDir _mhqDir;

// create marker on MHQ
_markerType = "b_motor_inf";
if (MHQ1 isKindof "tank") then {_markerType = "b_armor"};

// Remove Undeployed Marker and create a Deployed Marker 
[MHQ1] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated,false];
sleep 0.2;
[MHQ1, _markerType, "ColorYellow", 1, 1, localize "STR_DUWS_T_cmbq8ut7"] remoteExec ["kndr_assignMarker", [0,-2] select isDedicated,false];

// Add to Respawn positions
_respawn_location = MHQ1 getRelPos [4,270];
MHQ_respawn = [west, _respawn_location] call BIS_fnc_addRespawnPosition;
publicVariable "MHQ_respawn";

MHQ_deployed = true;
publicVariable "MHQ_deployed";

["INFO", "SUPPORT", format ["MHQ deployed at %1", getPos MHQ1]] call fnc_log;

["undeploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,true];

// Lock vehicle
MHQ1 setVehicleLock "LOCKED";

