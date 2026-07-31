// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([5, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 400;
_cpreward = 30;
_apreward = 30;
_speaker = localize "STR_DUWS_T_Viper";
_message = localize "STR_DUWS_T_sniperletsdothis";
_message1 = ([localize "STR_DUWS_T_sniperend"] call fnc_cs);

_markerText2 = localize "STR_DUWS_T_c5";

private _site = [_MissionPos, _radius, 5] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["sniperhunt%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_16dh939j", _mission_name, _randomPos, "kill"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];


[[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;
// CREATE PATROLS, NO VEHICLES
sleep 1;
[_missionpos, 15, false] spawn fnc_createoppatrol2;
sleep 1;
[_randompos, _radius, false] spawn fnc_createoppatrol2;
sleep 1;
[_randompos, _radius] spawn { [_this call fnc_createopteam2] call fnc_mission_claim };
sleep 1;
[_randompos, _radius] spawn { [_this call fnc_createopteam2] call fnc_mission_claim };

_group = [_targetpos, east, [opfor_SL_SOLDIER_X, opfor_SNIPER_SOLDIER_X, opfor_SNIPER_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
[_group] call fnc_mission_claim;
_target1 = units _group select 1;
_target2 = units _group select 2;

// What a searched corpse reveals. Absent here, the reveal branch of the body search had nothing to
// mark, so it returned silently and this mission paid at the roll's lower band instead of its full
// rate -- the garrison it applies to only started carrying intel when fnc_garrisonBuildings took
// over, so the gap had never shown.

// 为狙击手添加吉利服
[_target1] spawn {
    params ["_unit"];
    sleep 5;
    _unit forceAddUniform "U_B_FullGhillie_sard";
};
[_target2] spawn {
    params ["_unit"];
    sleep 5;
    _unit forceAddUniform "U_B_FullGhillie_sard";
};
// 为狙击手添加机密情报
[_target1] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
// 为狙击手添加机密情报
[_target2] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
// Put an intel action on leader
if (hardcore_mode_enable) then {
	[[units _group select 0], "objective"] call fnc_search_flag_group;
};

if (VERSION_X == "MODERN") then {
	if !(("OPTRE" in BLUFOR_FactionFile_X) 
		or ("HL2ECR" in BLUFOR_FactionFile_X)
		or ("TIOW" in BLUFOR_FactionFile_X)) then {
		removeheadgear _target1;
		removeheadgear _target2;
		_target1 addHeadgear "H_Shemag_khk";
		_target2 addHeadgear "H_Shemag_khk";
	};
};

[_group, _targetpos, _radius] call bis_fnc_taskPatrol;
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;

// TASK AND NOTIFICATION
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;

sleep 5; // 等待巡逻队生成完毕


waitUntil {sleep 2; (!alive _target1 && !alive _target2)};

[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius] call fnc_mission_end;