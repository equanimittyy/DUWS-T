// Locality: server; the hold-action code blocks below run on the machine that triggers them, not here (callers remoteExec to target 2).

params ["_MissionPos", "_mission_name"];
if (!([8, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 350;

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

// Marker + task before the spawn-up (tens of seconds); the brief below stays manual (fixed speaker,
// pre-localised, no callsign substitution).
private _VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
_markername2 = [_randomPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_j97ecrsh", _mission_name, "download"] call fnc_mission_present;

// Brief opens the mission, before the building/laptop spawn-up below (tens of seconds): the spawn must
// not delay the opening line. Speaker and message are fixed strings, independent of the spawned sites.
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_laptopcopy"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;

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

// A camping table and laptop in every candidate building, on an interior floor slot biased toward the
// building's middle. One is the real objective, the rest decoys; a third of the decoys are rigged.
// _laptops holds [object, isReal, rigged] so the action loop below can wire each to the right handler.
//
// Two passes with a physics settle between them. A buildingPos slot is authored above the floor, so a
// table seated there by hand floats; instead each table is dropped simulated and left to fall onto the
// real floor collision, then frozen. The laptop is seated only afterward -- base-flush on its table's
// settled top -- and never simulated itself, because physx slides a loose laptop off the small top.
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

        // Pass 2: freeze each settled table, then drop a laptop onto its now-static, level top. The table
        // is frozen first so the laptop lands on a surface that no longer moves -- a laptop left on a
        // still-settling table slid straight off, the failure the old blanket freeze papered over. A
        // frozen prop still collides, so it makes a solid landing surface. The laptop starts a finger
        // above the top (base offset backed out so it clears the surface, not clips it), upright, and
        // turned 90 degrees off the table's own heading; it falls the last gap to rest flat.
        {
            _x params ["_table", "_isReal"];
            // Freeze == harden: enableSimulation false also suppresses damage, so stray patrol fire cannot
            // destroy the real objective (mission unwinnable) or a decoy prop. A rigged decoy still
            // detonates -- its bomb is a separate shell in the decoy handler, not damage to the laptop.
            _table setVectorUp [0, 0, 1];
            _table enableSimulationGlobal false;
            _table allowDamage false;
            private _tPos = getPosATL _table;
            private _topZ = (_tPos select 2) + (boundingBoxReal _table select 1 select 2);

            private _lap = createVehicle ["Land_Laptop_unfolded_F", _tPos, [], 0, "CAN_COLLIDE"];
            private _lBase = (boundingBoxReal _lap select 0) select 2;
            _lap setVectorUp [0, 0, 1];
            _lap setDir ((getDir _table) + 90);
            _lap setPosATL [_tPos select 0, _tPos select 1, _topZ + 0.05 - _lBase];
            _x set [2, _lap];
        } forEach _pending;

        // Laptops settle onto their (now frozen) tables in one shared wait, as the tables did onto the floor.
        sleep 1;

        // Pass 3: freeze each rested laptop and wire it to its handler.
        {
            _x params ["_table", "_isReal", "_lap"];
            _lap enableSimulationGlobal false;
            _lap allowDamage false;
            [_table, "mission_sabotage_laptop"] call fnc_duws_keep;
            [_lap, "mission_sabotage_laptop"] call fnc_duws_keep;
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

// Each candidate building holds a garrisoned team, raised and claimed up front so the objective is defended
// before the player can reach it. The team is spawned posture "none" at the building and spread into that
// exact building by hand, not left to the garrison posture: garrison hunts the nearest structure with >=5
// slots within 300 m, so a candidate with fewer slots gets no defenders and a neighbour can be claimed in
// its place -- the laptop and its guards must not drift apart. DUWS_garrisonedBy is stamped so an
// overlapping zone garrison cannot double-occupy the same house; it frees itself once the group is gone.
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
_garrison call fnc_mission_claim;
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
[DUWS_curDeadlineAt, _VARtaskgeneratedName, _markername2, _targetpos, _radius, _crossMarkers, _mission_name] spawn {
    params ["_deadline", "_taskId", "_marker", "_tpos", "_radius", "_crosses", "_mission_name"];
    private _token = DUWS_mission_token;
    waitUntil { sleep 5; time > _deadline || Mission_available || DUWS_mission_token != _token };
    if (time > _deadline && !Mission_available && DUWS_mission_token == _token) then {
        // Cross markers are raw createMarker names, cleared by hand; the ellipse and the timeout notice
        // route through finish (line [], FAILED, notify true).
        { deleteMarker _x } forEach _crosses;
        [_mission_name, _taskId, "FAILED", _tpos, _radius, [_marker], [], false, "mission_sabotage_laptop", false, true] call fnc_mission_finish;
    };
};
