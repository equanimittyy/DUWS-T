// Locality: server; the hold-action code blocks below run on the machine that triggers them, not here (callers remoteExec to target 2).

params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([8, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};


_radius = 350;

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_laptopletsdothis";

// Pick 3-5 of the vetted building cluster: each gets a garrison, an orange cross and a laptop, but only one
// laptop is real. The rest are decoys, a third rigged to blow, so the player must clear and sabotage each
// to find out which. Abort only if the cluster evaporated since the offer.
private _usable = [_MissionPos, 2, _radius] call fnc_usableBuildings;
if (_usable isEqualTo []) exitWith { [8, _requester, "no_building"] call fnc_mission_abort };
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

// The task name the watcher and hold-actions key on; the marker follows once the laptops are seated (below).
private _VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

// One orange objective marker per candidate building, no text: the player sees every possible site but not
// which holds the laptop until it is cleared. Names tracked so the win and timeout paths can delete them all.
private _crossMarkers = [];
{
    private _cpos = getPosATL _x;
    private _mk = format ["laptopcross_%1_%2", round (_cpos select 0), round (_cpos select 1)];
    createMarker [_mk, _cpos];
    _mk setMarkerType "hd_objective_noShadow";
    _mk setMarkerColor "ColorOrange";
    _mk setMarkerText "";
    _crossMarkers pushBack _mk;
} forEach _bldgs;

// Table and laptop are left simulated, not frozen, so a destroyed building drops them instead of leaving
// them hanging where the floor was. fnc_place_settled seats the laptop clear of the table rather than
// dropping it -- a laptop created clipping the table takes an ejection impulse and lands on the floor.
private _laptops = [];
switch (VERSION_X) do {
    case "MODERN": {
        // Pass 1: drop a table into each candidate, upright, left simulated to fall the slot-to-floor gap.
        private _pending = [];
        {
            private _bldg = _x;
            // Nearest-to-centroid slot, not a raw random one: a perimeter buildingPos sits against a
            // wall, leaving the table clipping into it or wedged where the player cannot reach the laptop.
            // The slots closest to the mean of all slots are the building's interior.
            private _positions = [_bldg] call BIS_fnc_buildingPositions;
            private _slot = _positions param [0, [0,0,0]];
            if (count _positions > 1) then {
                private _sx = 0; private _sy = 0;
                { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _positions;
                private _cen = [_sx / count _positions, _sy / count _positions, 0];
                private _scored = _positions apply { [_cen distance2D _x, _x] };
                _scored sort true;
                _slot = (selectRandom (_scored select [0, 1 max floor (count _scored / 2)])) select 1;
            };
            private _table = createVehicle ["Land_CampingTable_F", _slot, [], 0, "CAN_COLLIDE"];
            _table setVectorUp [0, 0, 1];
            _table setDir 0;
            _table setPosATL _slot;
            _pending pushBack [_table, _bldg isEqualTo _laptopBldg];
        } forEach _bldgs;

        // One wait covers every table in the air at once, so the cost is flat in the building count
        // rather than a sleep per table.
        sleep 1.5;

        // The 1 cm gap keeps the laptop off the still-live table on the settle frame; seated flush the two
        // interpenetrate and physx kicks it away.
        {
            _x params ["_table", "_isReal"];
            // allowDamage false hardens the real objective -- patrol fire that destroyed it would make the
            // mission unwinnable. setVelocity zeroes the slot-to-floor drop residual so the live table rests.
            _table setVectorUp [0, 0, 1];
            _table setVelocity [0, 0, 0];
            _table allowDamage false;
            [_table, "mission_sabotage_laptop"] call fnc_duws_keep;

            private _topZ = (boundingBoxReal _table select 1) select 2;
            private _lap = ([[["Land_Laptop_unfolded_F", 0, 0, _topZ + 0.01, random 360]], _table, "mission_sabotage_laptop"] call fnc_place_settled) select 0;

            // Paired so a rigged decoy's blast can clear both props (invulnerable, so the shell alone
            // leaves them standing). Read server-side by fnc_sabotage_laptop_decoy.
            _lap setVariable ["DUWS_laptop_table", _table];
            // Rigged roll is fixed here, not at the action, so a decoy's fate is the same for whoever
            // reaches it. Only decoys are ever rigged.
            private _rigged = !_isReal && {random 1 < 0.33};
            _laptops pushBack [_lap, _isReal, _rigged];
            if (_isReal) then { _targetpos = getPosATL _lap };
        } forEach _pending;
    };
};

// Feeds the client floating markers (client/misc/fnc_sabotage_laptop_markers.sqf); the deadline watcher
// below prunes these on mission end.
private _lapObjs = _laptops apply { _x select 0 };
missionNamespace setVariable ["DUWS_sabotage_laptops",
    (missionNamespace getVariable ["DUWS_sabotage_laptops", []]) + _lapObjs, true];

// Each candidate building holds a garrisoned team, spread into that exact building by hand rather than the
// garrison posture -- which hunts the nearest structure with >=5 slots and could put defenders in a
// neighbour, drifting the guards off the laptop. DUWS_garrisonedBy is stamped so an overlapping zone
// garrison cannot double-occupy the house; it frees itself once the group is gone.
private _garrison = [];
{
    private _bldg = _x;
    private _grp = ["garrison:team", getPosATL _bldg, 30, "none", getPosATL _bldg] call DUWS_fnc_zoneSpawnOne;
    if (!isNull _grp) then {
        _bldg setVariable ["DUWS_garrisonedBy", _grp];
        [_grp, [_bldg], count units _grp, "AUTO"] call fnc_spreadIntoBuildings;
        _garrison pushBack _grp;
    };
} forEach _bldgs;
[_garrison] call fnc_mission_claim;
sleep 1;

// Ring raised like the building garrison above: per-token zoneSpawnOne, claimed as one batch. Inline
// and synchronous -- the spawn builders never yield -- so a fast finish cannot land between raise and
// claim, and the whole ring is owned before the next line runs.
private _ring = [];
{
    private _grp = [_x, _randomPos, _radius] call DUWS_fnc_zoneSpawnOne;
    if (!isNull _grp) then { _ring pushBack _grp };
} forEach [
    "widepatrol:car", "closepatrol:ifv", "closepatrol:team", "closepatrol:team",
    "widepatrol:team", "widepatrol:patrol", "widepatrol:patrol"
];
[_ring] call fnc_mission_claim;

// Marker + task now the laptops are seated; the brief below is manual (fixed speaker).
_markername2 = [_randomPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_j97ecrsh", _mission_name, "download"] call fnc_mission_present;
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_laptopcopy"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;

// A hold-to-complete "Sabotage" on each laptop (6 s, the body-search hold). The entry always shows but
// only progresses once no living OPFOR is within 50 m; a hold attempted with enemies up is interrupted
// at once with a hint. Completing sets DUWS_laptop_done, which the show-condition reads, so the entry
// drops on every machine. The real laptop wins; a decoy reveals itself and, if rigged, arms the bomb.
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
[DUWS_curDeadlineAt, _VARtaskgeneratedName, _markername2, _targetpos, _radius, _crossMarkers, _mission_name, _lapObjs] spawn {
    params ["_deadline", "_taskId", "_marker", "_tpos", "_radius", "_crosses", "_mission_name", "_lapObjs"];
    private _token = DUWS_mission_token;
    waitUntil { sleep 5; time > _deadline || Mission_available || DUWS_mission_token != _token };
    // Wakes for every end path (win, timeout, slot recycle): drop these from the marker list so the icons
    // clear now, not when the props finally leave on the keep-radius clock.
    missionNamespace setVariable ["DUWS_sabotage_laptops",
        (missionNamespace getVariable ["DUWS_sabotage_laptops", []]) - _lapObjs, true];
    if (time > _deadline && !Mission_available && DUWS_mission_token == _token) then {
        // Cross markers are raw createMarker names, cleared by hand; the ellipse and the timeout notice
        // route through finish (line [], FAILED, notify true).
        { deleteMarker _x } forEach _crosses;
        [_mission_name, _taskId, "FAILED", _tpos, _radius, [_marker], [], false, "mission_sabotage_laptop", false, true] call fnc_mission_finish;
    };
};
