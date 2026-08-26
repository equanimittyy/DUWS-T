// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
#include "..\..\..\..\shared\includes\action_style.hpp"

params ["_MissionPos", "_mission_name"];
if (!([8, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 350;

_markerText2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _markerText2 = localize "STR_DUWS_T_c8";
    };
};
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_laptopletsdothis";

// The offer's site-finder vetted a cluster of enterable buildings near _MissionPos. Pick 3-5 of them: every
// one gets a garrison and an orange cross on the map, but the laptop hides in only one, so the player has to
// clear them to find it. The finder guaranteed a cluster; abort defensively only if it evaporated.
private _usable = [_MissionPos, 2, _radius] call fnc_usableBuildings;
if (_usable isEqualTo []) exitWith { [8, "STR_DUWS_T_crtzxs0j", "no_building"] call fnc_mission_abort };
private _bldgCount = (3 + floor random 3) min (count _usable);   // 3-5, capped at what exists
private _bldgs = [];
private _pool = +_usable;
for "_i" from 1 to _bldgCount do { _bldgs pushBack (_pool deleteAt (floor random (count _pool))) };

// Laptop hides in one random building of the cluster, on a random interior slot (any floor). The task and
// ellipse centre on _MissionPos, not this building, so the marker never gives the hiding place away.
private _laptopBldg = selectRandom _bldgs;
private _targetpos = selectRandom ([_laptopBldg] call BIS_fnc_buildingPositions);
private _randomPos = _MissionPos;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

_tableLoc = _targetpos;

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_j97ecrsh", _mission_name, _randomPos, "download"] call fnc_missionTaskCreate;

// One orange cross per candidate building, no text: the player sees every possible site but not which holds
// the laptop until it is cleared. Names tracked so the win and timeout paths can delete them all.
private _crossMarkers = [];
{
    private _cpos = getPosATL _x;
    private _mk = format ["laptopcross_%1_%2", round (_cpos select 0), round (_cpos select 1)];
    createMarker [_mk, _cpos];
    _mk setMarkerType "mil_destroy";
    _mk setMarkerColor "ColorOrange";
    _mk setMarkerText "";
    _crossMarkers pushBack _mk;
} forEach _bldgs;

_laptop = "";
switch (VERSION_X) do {
    case "MODERN": {
        // Objective sits inside the laptop building on its random interior slot: a small desk there, the
        // laptop on the desk. The old open-air table + camonet + pallet camp does not fit indoors, so it goes.
        // setPosATL, not the plain spawn position, so both land on the slot's exact height rather than snap
        // to the terrain under the building.
        _table = createVehicle ["Land_TableDesk_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _table setPosATL _tableLoc;
        _table setDir 0;
        [_table, "mission_sabotage_laptop"] call fnc_duws_keep;
        sleep 1;
        _laptop = createVehicle ["Land_Laptop_unfolded_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _laptop setPosATL [(_tableLoc select 0), (_tableLoc select 1), (_tableLoc select 2) + 0.46];
        _laptop setDir 270;
        [_laptop, "mission_sabotage_laptop"] call fnc_duws_keep;
    };
};

// Each candidate building holds a garrisoned team, raised and claimed up front so the objective is defended
// before the player can reach it. The cluster is then ringed by a mixed patrol -- a car and, where the
// faction fields one, an IFV, plus foot teams. DUWS_fnc_zoneSpawnOne skips a vehicle the faction cannot
// field, so the IFV is "if available" for free.
private _garrison = [];
{ _garrison pushBack (["garrison:team", getPosATL _x, 30] call DUWS_fnc_zoneSpawnOne) } forEach _bldgs;
(_garrison select { !isNull _x }) call fnc_mission_claim;
sleep 1;

// Patrols raise on a stagger (raiseGarrison sleeps between groups), so build them off the main thread and
// claim each as it comes -- a quick finish still tears them down by ownership.
[_randomPos, _radius] spawn {
    params ["_c", "_r"];
    private _patrolTokens = [
        "widepatrol:car", "closepatrol:ifv", "closepatrol:team", "closepatrol:team",
        "widepatrol:team", "widepatrol:patrol", "widepatrol:patrol"
    ];
    (([_patrolTokens, _c, _r] call DUWS_fnc_raiseGarrison) select { !isNull _x }) call fnc_mission_claim;
};

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
}, [_MissionPos,_targetpos,_mission_name,_markername2,_radius,_crossMarkers], 10, true, true, "", "_this == player"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["sabotage_action_%1", netId _laptop]];

// Searchable through the player's own action, the same way a body is. The laptop carries two
// actions -- this and the sabotage -- so giving it one of its own was also what made the
// index-0 removeAction in fnc_sabotage_laptop_success unsafe.
if (hardcore_mode_enable) then {
    [[_laptop], "objective"] call fnc_search_flag_group;
};
sleep 5; // let the patrols finish spawning

// Success comes through the laptop's addAction, not a wait here, so the deadline runs on a watcher:
// fail the mission if the clock runs out while it is still live (slot shut, token unadvanced).
[DUWS_curDeadlineAt, _VARtaskgeneratedName, _markername2, _targetpos, _radius, _crossMarkers] spawn {
    params ["_deadline", "_taskId", "_marker", "_tpos", "_radius", "_crosses"];
    private _token = DUWS_mission_token;
    waitUntil { sleep 5; time > _deadline || Mission_available || DUWS_mission_token != _token };
    if (time > _deadline && !Mission_available && DUWS_mission_token == _token) then {
        { deleteMarker _x } forEach _crosses;
        // TODO: give this mission a bespoke Overlord timeout-fail line; fnc_mission_deadline_fail emits the generic.
        [_taskId, _marker, "mission_sabotage_laptop", _tpos, _radius, false] call fnc_mission_deadline_fail;
    };
};
