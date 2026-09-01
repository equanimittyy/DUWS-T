// Locality: server -- callers remoteExec to target 2.
//
// The transport_IDAP delivery, but the truck starts at HQ instead of at an objective in the field: the
// player drives it into the surveyed town where an IDAP crew waits. The outcome moves that town's rep by
// the row's REP figure.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([21, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 50;
private _deliverDist = 50;
private _deadline = DUWS_curDeadlineAt;

// duws_town_circles is index-aligned with civ_locations, so a circle's index is the one
// fnc_town_rep_adjust takes.
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _circles = missionNamespace getVariable ["duws_town_circles", []];
private _townIdx = -1;
private _townPos = [];
private _bestD = 1e9;
{
    _x params ["_c", ""];
    if ((_enemyTowns findIf { _x distance2D _c < 5 }) < 0) then {
        private _d = _c distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _townPos = _c; _townIdx = _forEachIndex };
    };
} forEach _circles;
if (_townIdx < 0) exitWith { [21, _requester, "no_delivery_town"] call fnc_mission_abort };

// The aid crew's thanks names the delivery town: the location's own name, nearest-location fallback, then
// a generic if the map left it unnamed. duws_town_circles is index-aligned with civ_locations.
private _townName = text ((missionNamespace getVariable ["civ_locations", []]) select _townIdx);
if (_townName == "") then { _townName = text (nearestLocation [_townPos, ""]) };
if (_townName == "") then { _townName = localize "STR_DUWS_T_idap_town_generic" };

private _hqPos = if (!isNil "bluHQ_object" && { !isNull bluHQ_object }) then { getPosATL bluHQ_object } else { +PosOfBLUHQ };
private _spawnPos = [[_hqPos select 0, _hqPos select 1], 10, 300, 15, 0, 0.4, 0, [], []] call BIS_fnc_findSafePos;
if (_spawnPos isEqualTo [] || { (_spawnPos select 0) == 0 && { (_spawnPos select 1) == 0 } }) then { _spawnPos = _hqPos };

private _truck = "C_Truck_02_transport_F" createVehicle _spawnPos;
[_truck, "mission_deliver_supplies"] call fnc_duws_keep;

private _box1 = "";
private _box2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle _spawnPos;
        _box2 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle _spawnPos;
        { [_x, "mission_deliver_supplies"] call fnc_duws_keep } forEach [_box1, _box2];
        _box1 attachTo [_truck, [0, -0.5, 0]];
        _box1 setDir 90;
        _box2 attachTo [_truck, [0, -2.2, 0]];
        _box2 setDir 75;
    };
};

private _crewPos = [_townPos, 0, 80, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
if (_crewPos isEqualTo [] || { (_crewPos select 0) == 0 && { (_crewPos select 1) == 0 } }) then { _crewPos = _townPos };
private _crewClasses = [
    "C_IDAP_Man_Aidworker_01_F", "C_IDAP_Man_Aidworker_02_F", "C_IDAP_Man_Aidworker_03_F",
    "C_IDAP_Man_Aidworker_04_F", "C_IDAP_Man_Aidworker_05_F", "C_IDAP_Man_Aidworker_06_F"
];
private _crewUnits = [];
for "_i" from 1 to 3 do { _crewUnits pushBack (selectRandom _crewClasses) };
private _crew = [_crewPos, civilian, _crewUnits, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;
private _marshaller = objNull;
{
    _x setPos (_crewPos getPos [5 + random 3, random 360]);
    _x disableAI "MOVE";
    _x disableAI "PATH";
    _x setBehaviour "CARELESS";
    if (_forEachIndex == 0) then { _x switchMove "Acts_JetsShooterNavigate_loop_m"; _marshaller = _x };
} forEach units _crew;

// Pin the exact drop on the crew; the search circle only marks the town centre.
private _delivMarker = format ["delivsup_drop_%1", DUWS_mission_token];
createMarker [_delivMarker, _crewPos];
_delivMarker setMarkerShape "ICON";
_delivMarker setMarkerType "o_unknown";
_delivMarker setMarkerColor "ColorGreen";
_delivMarker setMarkerText "IDAP";
_delivMarker setMarkerSize [1, 1];

private _hqMarker = format ["delivsup_hq_%1", DUWS_mission_token];
createMarker [_hqMarker, _spawnPos];
_hqMarker setMarkerShape "ICON";
_hqMarker setMarkerType "hd_pickup";
_hqMarker setMarkerColor "ColorBlue";
_hqMarker setMarkerText "Supply Truck";
[_hqMarker] spawn { params ["_m"]; sleep 120; deleteMarker _m };

[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
sleep 2;

private _taskId = format ["delivsup%1%2", round (_townPos select 0), round (_townPos select 1)];
private _marker = [_townPos, _radius, _taskId, localize "STR_DUWS_T_DELIVER_SUPPLIES_DESC", _mission_name, "move",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_deliversupplies_brief", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_deliversupplies_copy"]]
] call fnc_mission_present;

private _cleanup = {
    deleteMarker _hqMarker;
    deleteMarker _delivMarker;
    { if (_x isEqualType objNull && { !isNull _x }) then { deleteVehicle _x } } forEach [_box1, _box2];
    if (!isNull _truck) then { deleteVehicle _truck };
    { deleteVehicle _x } forEach units _crew;
    deleteGroup _crew;
};

// Trigger on the crew's spot, not the town centre -- else the delivery ticks up to 40 m short of the drop.
waitUntil {
    sleep 2;
    (getDammage _truck > 0.95) || (_truck distance _crewPos < _deliverDist) || (({ alive _x } count units _crew) == 0) || (time > _deadline)
};

if (getDammage _truck > 0.95) exitWith {
    [_townIdx, -(DUWS_curReward select 2), "deliver_supplies_truck_lost"] call fnc_town_rep_adjust;
    call _cleanup;
    [_mission_name, _taskId, "FAILED", _townPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_idaptruckdown"]] call fnc_mission_finish;
};

if (({ alive _x } count units _crew) == 0) exitWith {
    [_townIdx, -(DUWS_curReward select 2), "deliver_supplies_crew_dead"] call fnc_town_rep_adjust;
    call _cleanup;
    [_mission_name, _taskId, "FAILED", _townPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_idapcrewdead"]] call fnc_mission_finish;
};

if (time > _deadline) exitWith {
    [_townIdx, -(DUWS_curReward select 2), "deliver_supplies_deadline"] call fnc_town_rep_adjust;
    call _cleanup;
    [_mission_name, _taskId, "FAILED", _townPos, _radius, [_marker]] call fnc_mission_finish;
};

// Delivered: the transport_IDAP hand-over. The aid crew thanks the player in person (VOICE, in the room),
// Overlord signs off over the net, then the sacks come off the bed and the emptied truck pulls away. The
// close line is spoken here, mid-theatre, so finish's _line is left empty.
deleteMarker _delivMarker;
if (!isNull _marshaller) then { _marshaller switchMove "" };
[localize "STR_DUWS_T_IDAP", format [localize "STR_DUWS_T_idapend", _townName], "VOICE"] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_deliversupplies_close"] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[_townIdx, DUWS_curReward select 2, "deliver_supplies_success"] call fnc_town_rep_adjust;
sleep 2;
if (_box2 isEqualType objNull && { !isNull _box2 }) then { deleteVehicle _box2 };
sleep 2;
if (_box1 isEqualType objNull && { !isNull _box1 }) then { deleteVehicle _box1 };
sleep 8;
if (!isNull _truck) then { deleteVehicle _truck };
call _cleanup;
[_mission_name, _taskId, "SUCCEEDED", _townPos, _radius, [_marker], [], true] call fnc_mission_finish;
