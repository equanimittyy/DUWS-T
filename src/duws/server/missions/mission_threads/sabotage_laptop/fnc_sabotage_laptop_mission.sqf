// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
#include "..\..\..\..\shared\includes\action_style.hpp"

params ["_MissionPos", "_mission_name"];
if (!([8, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 200;

_markerText2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _markerText2 = localize "STR_DUWS_T_c8";
    };
};
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_laptopletsdothis";

private _site = [_MissionPos, _radius, 8] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

_tableLoc = _targetpos;

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_j97ecrsh", _mission_name, _randomPos, "download"] call fnc_missionTaskCreate;

_laptop = "";
switch (VERSION_X) do {
    case "MODERN": {
        _table = createVehicle ["Land_WoodenTable_large_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _table setDir 0;
        [_table, "mission_sabotage_laptop"] call fnc_duws_keep;
        sleep 1;
        _pallet = createVehicle ["VirtualReammoBox_camonet_F", [(_tableLoc select 0)+3, (_tableLoc select 1)+3], [], 0, "CAN_COLLIDE"];
        [_pallet, "mission_sabotage_laptop"] call fnc_duws_keep;
        sleep 1;
        _laptop = createVehicle ["Land_Laptop_unfolded_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _laptop setpos [(_tableLoc select 0),(_tableLoc select 1),1.0];
        _laptop setDir 270;
        [_laptop, "mission_sabotage_laptop"] call fnc_duws_keep;
        sleep 1;
        _camonet = createVehicle ["CamoNet_INDP_open_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _camonet setDir 0;
        [_camonet, "mission_sabotage_laptop"] call fnc_duws_keep;
    };
};

[_targetpos, _radius] call fnc_garrisonBuildings;

// CREATE OPFOR PATROLS
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;

// ADD SABOTAGE ACTION TO LAPTOP
// Suffixed JIP id, not the laptop itself: the hardcore intel rotary below hangs off the same
// object, and an object-keyed id is that object's netId, so the two entries evicted each other
// and a joining client got the search but never the sabotage. The success path removes this id.
// The local half of a split: an addAction runs on whoever activated it, and its index exists
// only on that machine, so removal has to happen here. Everything else the hack changes is
// shared state and is decided on the server.
[_laptop,[ACT_COMMIT("STR_DUWS_T_p3200mf5"), {
    params ["_target", "_caller", "_actionId", "_arguments"];
    // Dropped locally first. The server's broadcast removal is a round-trip away, and this
    // action admits only the activating player, so they are the only one who could pay
    // themselves twice inside that window.
    _target removeAction _actionId;
    ([_target] + _arguments) remoteExec ["fnc_sabotage_laptop_success", 2];
}, [_MissionPos,_targetpos,_mission_name,_markername2,_radius], 10, true, true, "", "_this == player"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["sabotage_action_%1", netId _laptop]];

// Searchable through the player's own action, the same way a body is. The laptop carries two
// actions -- this and the sabotage -- so giving it one of its own was also what made the
// index-0 removeAction in fnc_sabotage_laptop_success unsafe.
if (hardcore_mode_enable) then {
    [[_laptop], "objective"] call fnc_search_flag_group;
};
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
// 设置任务目标位置

sleep 5; // 等待巡逻队生成完毕
