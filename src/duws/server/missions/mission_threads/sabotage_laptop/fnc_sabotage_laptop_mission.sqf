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

// The offer's site-finder already vetted a usable building near _MissionPos; pick the best multi-storey one
// and the interior slot the laptop sits on. [] only if the buildings vanished in the gap -- abort and release.
private _pick = [_MissionPos, _radius] call fnc_laptop_building_pick;
if (_pick isEqualTo []) exitWith { [8, "STR_DUWS_T_crtzxs0j", "no_building"] call fnc_mission_abort };
_pick params ["_Building", "_targetpos"];
private _randomPos = getPosATL _Building;

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
        // Objective sits inside the building on the chosen floor: a small desk on the interior slot, the
        // laptop on the desk. The old open-air table + camonet + pallet camp does not fit indoors, so it goes.
        // setPosATL, not the plain spawn position, so both land on the floor's exact height rather than snap
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

// Garrison the objective building and its immediate neighbours so the laptop is defended from inside; the
// patrol ring stays on the wider mission radius. Both centre on the building, not the interior slot.
[[_randomPos, 50, 2, 4] call fnc_garrisonBuildings] call fnc_mission_claim;
sleep 1;
[_randomPos, _radius] spawn fnc_missionPatrolswithintel;

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
sleep 5; // let the patrols finish spawning

// Success comes through the laptop's addAction, not a wait here, so the deadline runs on a watcher:
// fail the mission if the clock runs out while it is still live (slot shut, token unadvanced).
[DUWS_curDeadlineAt, _VARtaskgeneratedName, _markername2, _targetpos, _radius] spawn {
    params ["_deadline", "_taskId", "_marker", "_tpos", "_radius"];
    private _token = DUWS_mission_token;
    waitUntil { sleep 5; time > _deadline || Mission_available || DUWS_mission_token != _token };
    if (time > _deadline && !Mission_available && DUWS_mission_token == _token) then {
        // TODO: give this mission a bespoke Overlord timeout-fail line; fnc_mission_deadline_fail emits the generic.
        [_taskId, _marker, "mission_sabotage_laptop", _tpos, _radius, false] call fnc_mission_deadline_fail;
    };
};
