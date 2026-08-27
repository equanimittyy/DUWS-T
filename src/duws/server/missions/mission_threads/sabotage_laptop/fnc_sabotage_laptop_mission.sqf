// Locality: server; the hold-action code blocks below run on the machine that triggers them, not here (callers remoteExec to target 2).

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
// one gets a garrison, an orange cross on the map, and a laptop on a desk -- but only one laptop is the real
// objective. The rest are decoys, a third of them rigged to blow, so the player has to clear each building
// and sabotage its laptop to find out which is which. The finder guaranteed a cluster; abort defensively
// only if it evaporated.
private _usable = [_MissionPos, 2, _radius] call fnc_usableBuildings;
if (_usable isEqualTo []) exitWith { [8, "STR_DUWS_T_crtzxs0j", "no_building"] call fnc_mission_abort };
private _bldgCount = (3 + floor random 3) min (count _usable);   // 3-5, capped at what exists
private _bldgs = [];
private _pool = +_usable;
for "_i" from 1 to _bldgCount do { _bldgs pushBack (_pool deleteAt (floor random (count _pool))) };

// The real laptop hides in one random building of the cluster. The task and ellipse centre on _MissionPos,
// not this building, so the marker never gives the hiding place away. _targetpos is set to the real laptop's
// exact slot in the spawn loop below.
private _laptopBldg = selectRandom _bldgs;
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

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

// A desk-and-laptop in every candidate building, on a random interior slot (any floor). One is the real
// objective, the rest decoys; a third of the decoys are rigged. _laptops holds [object, isReal, rigged] so
// the action loop below can wire each to the right handler. setPosATL, not the plain spawn position, so both
// props land on the slot's exact height rather than snap to the terrain under the building.
private _laptops = [];
switch (VERSION_X) do {
    case "MODERN": {
        {
            private _slot = selectRandom ([_x] call BIS_fnc_buildingPositions);
            private _isReal = _x isEqualTo _laptopBldg;
            private _table = createVehicle ["Land_TableDesk_F", _slot, [], 0, "CAN_COLLIDE"];
            _table setPosATL _slot;
            _table setDir 0;
            [_table, "mission_sabotage_laptop"] call fnc_duws_keep;
            private _lap = createVehicle ["Land_Laptop_unfolded_F", _slot, [], 0, "CAN_COLLIDE"];
            _lap setPosATL [_slot select 0, _slot select 1, (_slot select 2) + 0.46];
            _lap setDir 270;
            [_lap, "mission_sabotage_laptop"] call fnc_duws_keep;
            // Rigged roll is fixed here, not at the action, so a decoy's fate is the same for whoever
            // reaches it. Only decoys are ever rigged.
            private _rigged = !_isReal && {random 1 < 0.33};
            _laptops pushBack [_lap, _isReal, _rigged];
            if (_isReal) then { _targetpos = _slot };
        } forEach _bldgs;
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

// SABOTAGE ACTION ON EVERY LAPTOP
// A hold-to-complete "Sabotage" on each laptop, real or decoy, timed to the body-search hold (6 s). The
// entry always shows, but the hold only makes progress once the building is clear -- no living OPFOR
// within 50 m of the laptop -- and a hold attempted with enemies still up is interrupted at once and
// answered with a hint, so the refusal is instant, not a wasted six seconds. Completing sets
// DUWS_laptop_done on the laptop, which the show-condition reads, so the entry drops on every machine
// without a per-client removal. The real laptop's completion wins the mission; a decoy's reveals it and,
// if rigged, arms the bomb.
//
// Object-keyed JIP id (netId): a late joiner re-runs the add, but the show-condition keeps it hidden on
// an already-sabotaged laptop, and the success/decoy paths clear the queued add anyway. The 50 m check
// is an engine spatial query (nearEntities), valid on the activating client.
private _condShow = "(_this == player) && !(_target getVariable ['DUWS_laptop_done', false])";
private _condProg = _condShow + " && (({side _x == east && alive _x} count (_target nearEntities [['CAManBase'], 50])) == 0)";
private _interrupted = {
    params ["_target"];
    // Fires on any interrupt, a voluntary release included, so re-check: only nag about OPFOR when they
    // are the reason the hold could not finish.
    if ({side _x == east && alive _x} count (_target nearEntities [["CAManBase"], 50]) > 0) then { hint localize "STR_DUWS_T_laptopnotclear" };
};
{
    _x params ["_lap", "_isReal", "_rigged"];
    private _completed = if (_isReal) then {
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            _target setVariable ["DUWS_laptop_done", true, true];
            ([_target] + _arguments) remoteExec ["fnc_sabotage_laptop_success", 2];
        }
    } else {
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            _target setVariable ["DUWS_laptop_done", true, true];
            ([_target, _caller] + _arguments) remoteExec ["fnc_sabotage_laptop_decoy", 2];
        }
    };
    private _args = if (_isReal) then {
        [_MissionPos, _targetpos, _mission_name, _markername2, _radius, _crossMarkers]
    } else {
        [_rigged]
    };
    [
        _lap, localize "STR_DUWS_T_p3200mf5",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        _condShow, _condProg, {}, {}, _completed, _interrupted, _args, 6, 30, false, false
    ] remoteExec ["BIS_fnc_holdActionAdd", [0,-2] select isDedicated, format ["sabotage_action_%1", netId _lap]];
} forEach _laptops;

sleep 5; // let the patrols finish spawning

// Success comes through the laptop's addAction, not a wait here, so the deadline runs on a watcher:
// fail the mission if the clock runs out while it is still live (slot shut, token unadvanced).
[DUWS_curDeadlineAt, _VARtaskgeneratedName, _markername2, _targetpos, _radius, _crossMarkers] spawn {
    params ["_deadline", "_taskId", "_marker", "_tpos", "_radius", "_crosses"];
    private _token = DUWS_mission_token;
    waitUntil { sleep 5; time > _deadline || Mission_available || DUWS_mission_token != _token };
    if (time > _deadline && !Mission_available && DUWS_mission_token == _token) then {
        { deleteMarker _x } forEach _crosses;
        [_taskId, _marker, "mission_sabotage_laptop", _tpos, _radius, false, ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_laptopfail"]] call fnc_mission_deadline_fail;
    };
};
