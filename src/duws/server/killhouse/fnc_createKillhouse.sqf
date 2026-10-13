// Locality: server; the addAction and HitPart bodies below run on the machine that triggers them, not here.
#include "..\..\shared\includes\action_style.hpp"

if (!isServer) exitWith {};

private _centerSpawnX = worldSize * 0.05;
private _centerSpawnY = worldSize * 0.05;

// The composition's heights are offsets from this floor.
private _centerSpawnZ = 1000;
private _objectsData = ["duws_killhouse", "objects"] call fnc_composition_rows;
private _targetsData = ["duws_killhouse", "targets"] call fnc_composition_rows;

// Broadcast: clients test their own distance for contact markers and the death-penalty exemption
// in client_init; targetData/run_active stay server-local, and reads of those elsewhere silently fail except on a hosting player's machine, which is also the server.
missionNamespace setVariable ["killhouse_centerX", _centerSpawnX, true];
missionNamespace setVariable ["killhouse_centerY", _centerSpawnY, true];
missionNamespace setVariable ["killhouse_centerZ", _centerSpawnZ, true];
missionNamespace setVariable ["killhouse_targetData", _targetsData];
missionNamespace setVariable ["killhouse_run_active", false];
private _computerObjects = [];
private _bellObjects = [];
{
    _x params ["_class", "_dX", "_dY", "_dZ", "_dir"];
    private _newX = _centerSpawnX + _dX;
    private _newY = _centerSpawnY + _dY;
    private _newZ = _centerSpawnZ + _dZ;

    private _obj = createVehicle [_class, [_newX, _newY, _newZ], [], 0, "CAN_COLLIDE"];
    _obj setPosWorld [_newX, _newY, _newZ];
    _obj setDir _dir;
    // Global: the local form leaves clients simulating props the server froze, so the course
    // furniture then sits somewhere different on every machine.
    _obj enableSimulationGlobal false;
    _obj allowDamage false;
    // Spare it from the cleanup sweep: that sweep bins any un-crewed object in `vehicles` once
    // DUWS_CleanupLifetime elapses with no player inside KEEP_RADIUS, and the course floats at 1000 m
    // where nobody stands between runs. Server-local: both readers of this flag run server-side.
    _obj setVariable ["persistent", true];

    if (_class == "Land_MultiScreenComputer_01_olive_F") then {
        _computerObjects pushBack _obj;
    };
    if (_class == "Land_MysteriousBell_01_F") then {
        _bellObjects pushBack _obj;
    };
} forEach _objectsData;
// One bell per entrance gate, and the run functions run in scopes these locals never reach.
missionNamespace setVariable ["killhouse_bells", _bellObjects];

["INFO", "SUPPORT", format ["spawned %1 props, %2 targets pending, %3 computers", count _objectsData, count _targetsData, count _computerObjects]] call fnc_log;
private _flagBlueking = objNull;
private _flagRedstone = objNull;
private _flags = nearestObjects [[_centerSpawnX, _centerSpawnY, _centerSpawnZ], ["SignAd_Sponsor_Blueking_F","SignAd_Sponsor_Redstone_F"], 500];
{
    if (_x isKindOf "SignAd_Sponsor_Blueking_F") then { _flagBlueking = _x; };
    if (_x isKindOf "SignAd_Sponsor_Redstone_F") then { _flagRedstone = _x; };
} forEach _flags;

// A respawn position aimed at the course does not land the player on it, so each entry stands on
// its own patch of open HQ ground and onPlayerRespawn lifts whoever arrives there to its entrance.
private _respawns = [];
if (!isNull _flagBlueking) then {
    private _tpA = _flagBlueking modelToWorld [0.484848, -3.43652, 0];
    _tpA set [2, (getPosWorld _flagBlueking select 2) + (-1.04517)];
    missionNamespace setVariable ["killhouse_tpA", _tpA, true];
    private _anchorA = [(PosOfBLUHQ select 0) + 12, (PosOfBLUHQ select 1) + 5.7, 0];
    [west, _anchorA, "4. " + localize "STR_DUWS_KILLHOUSE_TELEPORT_A"] call BIS_fnc_addRespawnPosition;
    _respawns pushBack [_anchorA, _tpA];
};
if (!isNull _flagRedstone) then {
    private _tpB = _flagRedstone modelToWorld [0.478247, -4.01343, 0];
    _tpB set [2, (getPosWorld _flagRedstone select 2) + (-1.05688)];
    missionNamespace setVariable ["killhouse_tpB", _tpB, true];
    private _anchorB = [(PosOfBLUHQ select 0) + 20, (PosOfBLUHQ select 1) + 6.2, 0];
    [west, _anchorB, "5. " + localize "STR_DUWS_KILLHOUSE_TELEPORT_B"] call BIS_fnc_addRespawnPosition;
    _respawns pushBack [_anchorB, _tpB];
};
missionNamespace setVariable ["killhouse_respawns", _respawns, true];
["INFO", "SUPPORT", format ["Teleport A: %1, Teleport B: %2", missionNamespace getVariable "killhouse_tpA", missionNamespace getVariable "killhouse_tpB"]] call fnc_log;
missionNamespace setVariable ["killhouse_targets", []];
missionNamespace setVariable ["killhouse_enemies", []];

// Called from each target's HitPart handler, which runs on the shooting client, so the delete
// has to come back here -- the server owns the list. The membership test stops a remote call
// deleting anything that is not a killhouse target; repeat hits on one target are no-ops.
killhouse_srv_target_hit = {
    if (!isServer) exitWith {};
    params [["_target", objNull]];
    private _targets = missionNamespace getVariable ["killhouse_targets", []];
    if !(_target in _targets) exitWith {};
    missionNamespace setVariable ["killhouse_targets", _targets - [_target], true];
    // Off the list at once but off the map a beat later: the list drives the run's count and must react
    // immediately, while deleting under the player's crosshair would read as the round missing.
    _target spawn { sleep killhouse_corpse_linger; deleteVehicle _this; };
};
publicVariable "killhouse_srv_target_hit";

// Globals rather than file-scope privates: the killhouse_srv_* bodies run later from remoteExec, where a private declared here is long out of scope.
killhouse_total_training         = 10;
killhouse_total_challenge        = 20;
killhouse_reward_training        = 1;
killhouse_reward_challenge       = 3;
killhouse_progress_delay         = 10;  // before the first progress hint, so the opening briefing is readable before the counter overwrites it
killhouse_progress_period        = 1;   // between progress hints after that; cannot resolve finer than the run loop's own tick below
killhouse_corpse_linger          = 2;
killhouse_min_spawn_dist         = 15;  // from any player in the course: a contact that appears in their face reads as a glitch
killhouse_area_radius            = 80;  // 3D from the composition centre: the one definition of
                                        // "inside the killhouse" -- who hears hints, which enemies are still in play. The structure
                                        // reaches ~55 m from centre and floats at 1000 m, so it cannot catch anyone standing underneath.
publicVariable "killhouse_area_radius"; // clients gate their contact markers on the same value

// Position rather than a flag set by the teleport actions: players also arrive by other routes
// and leave by dying, respawning or the exit action, and none of those would clear a flag.
killhouse_srv_occupants = {
    if (!isServer) exitWith { [] };
    private _centre = [
        missionNamespace getVariable ["killhouse_centerX", 0],
        missionNamespace getVariable ["killhouse_centerY", 0],
        missionNamespace getVariable ["killhouse_centerZ", 0]
    ];
    allPlayers select { (getPosWorld _x) distance _centre < killhouse_area_radius }
};

// Every killhouse hint goes through here, so the drill never talks to players out in the field.
// Targeting occupant units also drops the dedicated-server case for free: it owns no player unit, so it is never in the list and needs no isDedicated special case.
killhouse_srv_hint = {
    if (!isServer) exitWith {};
    params ["_msg"];
    private _who = call killhouse_srv_occupants;
    if (_who isEqualTo []) exitWith {};
    [_msg] remoteExec ["hint", _who];
};

// Rung to open a run and again when it is cleared. Both bells ring rather
// than the nearer one: they are ~60 m apart at opposite entrances, so 3D falloff already decides
// who hears what -- picking a bell would mean picking a player to pick it from. say3D carries to every client by itself, so this needs no remoteExec.
killhouse_srv_bell = {
    if (!isServer) exitWith {};
    { _x say3D "killhouse_bell"; } forEach (missionNamespace getVariable ["killhouse_bells", []]);
};

// A half-cleared killhouse leaks objects at 1000 m where nobody will ever see them to notice.
killhouse_srv_clear_all = {
    if (!isServer) exitWith {};
    { deleteVehicle _x; } forEach (missionNamespace getVariable ["killhouse_targets", []]);
    { deleteVehicle _x; } forEach (missionNamespace getVariable ["killhouse_enemies", []]);
    missionNamespace setVariable ["killhouse_targets", [], true];
    missionNamespace setVariable ["killhouse_enemies", [], true];
};

killhouse_srv_spawn_contacts = {
    if (!isServer) exitWith {};
    params ["_mode", "_slots"];
    private _centerX = missionNamespace getVariable "killhouse_centerX";
    private _centerY = missionNamespace getVariable "killhouse_centerY";
    private _centerZ = missionNamespace getVariable "killhouse_centerZ";

    if (_mode == "TRAINING") then {
        private _targets = missionNamespace getVariable ["killhouse_targets", []];
        {
            _x params ["_class", "_dX", "_dY", "_dZ", "_dir"];
            private _obj = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
            _obj setPosWorld [_centerX + _dX, _centerY + _dY, _centerZ + _dZ];
            _obj setDir _dir;
            // These range targets ignore bullet damage, so a server-side Hit/HandleDamage EH never fires on
            // them; HitPart is a physical-impact event instead, running on the machine that fired the round,
            // so it bounces the delete back here. Keyed to _obj: JIP clients get it, and the queued message is dropped once the target is deleted.
            [_obj, ["HitPart", {
                [((_this select 0) select 0)] remoteExec ["killhouse_srv_target_hit", 2];
            }]] remoteExec ["addEventHandler", 0, _obj];
            _targets pushBack _obj;
        } forEach _slots;
        missionNamespace setVariable ["killhouse_targets", _targets, true];
        [format [localize "STR_DUWS_T_TARGETS_SPAWNED", count _slots]] call killhouse_srv_hint;
    } else {
        private _unitPool = [
            opfor_SOLDIER_X, opfor_AA_SOLDIER_X, opfor_AR_SOLDIER_X, opfor_AT_SOLDIER_X,
            opfor_GL_SOLDIER_X, opfor_LAT_SOLDIER_X, opfor_SL_SOLDIER_X, opfor_TL_SOLDIER_X,
            opfor_MARK_SOLDIER_X, opfor_ENG_SOLDIER_X, opfor_SNIPER_SOLDIER_X,
            opfor_OPERATOR_X, opfor_OFFICER_X
        ];
        private _enemies = missionNamespace getVariable ["killhouse_enemies", []];
        {
            _x params ["_class", "_dX", "_dY", "_dZ"];
            private _posATL = [_centerX + _dX, _centerY + _dY, _centerZ + _dZ];
            private _group = [_posATL, EAST, [selectRandom _unitPool], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
            _group deleteGroupWhenEmpty true;
            private _unit = leader _group;
            _unit setPosWorld _posATL;
            _unit setDir (random 360);
            _unit setBehaviour "COMBAT";
            _unit setCombatMode "RED";
            _unit allowFleeing 0;
            // Static by design: this is a CQB course, so a row holds where it spawned instead of pathing out
            // to meet the player -- the difficulty is reading and clearing rooms, not an open firefight. PATH
            // only so targeting and firing still work; UP not AUTO, since a prone static enemy is a pixel hunt.
            _unit disableAI "PATH";
            _unit setUnitPos "UP";
            // Read by the kill-income handler in server_init.sqf; a run already pays its own reward, so its bodies must not also feed the tally.
            _unit setVariable ["killhouse_enemy", true];
            // Drop from the list before deleting, not after: a deleted unit no longer matches for removal, and
            // the run loop counts this array to decide when the course is clear. The body lingers so a kill is something the player sees rather than a unit blinking out of existence.
            _unit addEventHandler ["Killed", {
                params ["_unit"];
                if (!isServer) exitWith {};
                private _live = missionNamespace getVariable ["killhouse_enemies", []];
                missionNamespace setVariable ["killhouse_enemies", _live - [_unit], true];
                _unit spawn { sleep killhouse_corpse_linger; deleteVehicle _this; };
            }];
            _enemies pushBack _unit;
        } forEach _slots;
        missionNamespace setVariable ["killhouse_enemies", _enemies, true];
        [format [localize "STR_DUWS_T_ENEMIES_SPAWNED", count _slots]] call killhouse_srv_hint;
    };
};

killhouse_srv_start_run = {
    if (!isServer) exitWith {};
    params ["_mode"];
    private _allSlots = missionNamespace getVariable "killhouse_targetData";
    if (isNil "_allSlots") exitWith {};

    // Unscheduled, since a remoteExec'd body runs scheduled: a second start landing while this one is suspended mid-spawn would put two runs' contacts in the course.
    // A new id with the flag, or a cancelled run's thread still asleep counts this run as its own and pays it twice; a number so it serializes into a save.
    private _runId = 0;
    isNil {
        if !(missionNamespace getVariable ["killhouse_run_active", false]) then {
            missionNamespace setVariable ["killhouse_run_active", true];
            _runId = (missionNamespace getVariable ["killhouse_run_id", 0]) + 1;
            missionNamespace setVariable ["killhouse_run_id", _runId];
        };
    };
    if (_runId == 0) exitWith {
        (localize "STR_DUWS_KILLHOUSE_RUN_BUSY") remoteExec ["hint", remoteExecutedOwner];
    };
    call killhouse_srv_clear_all;

    private _centerX = missionNamespace getVariable "killhouse_centerX";
    private _centerY = missionNamespace getVariable "killhouse_centerY";
    private _centerZ = missionNamespace getVariable "killhouse_centerZ";
    private _occupied = (call killhouse_srv_occupants) apply { getPosWorld _x };
    // One row per contact, so nothing spawns on top of another -- and why the total is capped at the row count instead of wrapping.
    // Shuffled from a copy because BIS_fnc_arrayShuffle works in place, which would eat the master row list a run at a time.
    private _slots = (+_allSlots) call BIS_fnc_arrayShuffle;
    if !(_occupied isEqualTo []) then {
        // Nearest player first, so a run fills the rooms ahead of whoever started it; the shuffle above survives as the tie-break.
        private _ranked = [];
        {
            _x params ["_class", "_dX", "_dY", "_dZ"];
            private _pos = [_centerX + _dX, _centerY + _dY, _centerZ + _dZ];
            private _near = selectMin (_occupied apply { _x distance _pos });
            if (_near >= killhouse_min_spawn_dist) then {
                _ranked pushBack [_near, _forEachIndex];
            };
        } forEach _slots;
        _ranked sort true;
        _slots = _ranked apply { _slots select (_x select 1) };
    };
    _slots = _slots select [0, [killhouse_total_challenge, killhouse_total_training] select (_mode == "TRAINING")];
    private _total = count _slots;
    // Without this a run with no usable row would read as "none alive" on the first pass and pay the reward for a run that never happened.
    if (_total < 1) exitWith { missionNamespace setVariable ["killhouse_run_active", false]; };

    call killhouse_srv_bell;
    [_mode, _slots] call killhouse_srv_spawn_contacts;

    [_mode, _total, _runId] spawn {
        params ["_mode", "_total", "_runId"];
        private _listVar = ["killhouse_enemies", "killhouse_targets"] select (_mode == "TRAINING");
        private _nextProgress = time + killhouse_progress_delay;
        private _complete = false;
        private _centre = [
            missionNamespace getVariable ["killhouse_centerX", 0],
            missionNamespace getVariable ["killhouse_centerY", 0],
            missionNamespace getVariable ["killhouse_centerZ", 0]
        ];

        while { !_complete
                && { missionNamespace getVariable ["killhouse_run_active", false] }
                && { (missionNamespace getVariable ["killhouse_run_id", 0]) isEqualTo _runId } } do {
            // Anything outside the volume has left the course -- with movement disabled that takes blast or
            // ragdoll. The drop is 1000 m onto open sea, and a unit that survives the water would swim forever
            // without firing its Killed handler, hanging the run; killing it here routes through that same handler so the count stays honest.
            {
                if ((getPosWorld _x) distance _centre > killhouse_area_radius) then {
                    _x setDamage 1;
                };
            } forEach (missionNamespace getVariable ["killhouse_enemies", []]);

            private _up = count (missionNamespace getVariable [_listVar, []]);
            _complete = (_up == 0);
            if (!_complete && { time >= _nextProgress }) then {
                [format [localize "STR_DUWS_KILLHOUSE_PROGRESS", _up, _total]] call killhouse_srv_hint;
                _nextProgress = time + killhouse_progress_period;
            };

            if (!_complete) then { sleep 1; };
        };

        if (_complete) then {
            missionNamespace setVariable ["killhouse_run_active", false];
            private _reward = [killhouse_reward_challenge, killhouse_reward_training] select (_mode == "TRAINING");
            [_reward, "killhouse_score"] call fnc_cp_adjust;
            call killhouse_srv_bell;
            [format [localize "STR_DUWS_KILLHOUSE_RESULT", _total, _reward]] call killhouse_srv_hint;
        };
    };
};

killhouse_srv_spawn_targets = {
    if (!isServer) exitWith {};
    ["TRAINING"] call killhouse_srv_start_run;
};
publicVariable "killhouse_srv_spawn_targets";

killhouse_srv_spawn_enemies = {
    if (!isServer) exitWith {};
    ["CHALLENGE"] call killhouse_srv_start_run;
};
publicVariable "killhouse_srv_spawn_enemies";

// Clearing the flag is the whole cancel mechanism -- the run loop polls it and returns within a
// tick. Holding the script handle to terminate would be the obvious alternative, but SCRIPT has no serialized form and the mission namespace is written into save games.
killhouse_srv_cleanup = {
    if (!isServer) exitWith {};
    private _cancelled = missionNamespace getVariable ["killhouse_run_active", false];
    missionNamespace setVariable ["killhouse_run_active", false];
    call killhouse_srv_clear_all;
    [localize (["STR_DUWS_T_CLEANUP_DONE", "STR_DUWS_KILLHOUSE_TRAINING_CANCELLED"] select _cancelled)] call killhouse_srv_hint;
};
publicVariable "killhouse_srv_cleanup";

if (count _computerObjects > 0) then {
    {
        [_x, [
            ACT_SECONDARY_MENU("STR_DUWS_T_KILLHOUSE_CONTROLS"),
            {
                [localize "STR_DUWS_T_KILLHOUSE_CONTROLS", [
                    [localize "STR_DUWS_T_SPAWN_TARGETS", { [] remoteExec ["killhouse_srv_spawn_targets", 2]; }, [], [0,1,0,1]],
                    [localize "STR_DUWS_T_SPAWN_ENEMIES", { [] remoteExec ["killhouse_srv_spawn_enemies", 2]; }, [], [1,0,0,1]],
                    [localize "STR_DUWS_T_CLEANUP",       { [] remoteExec ["killhouse_srv_cleanup", 2]; }, [], [1,1,0,1]],
                    [localize "STR_DUWS_KILLHOUSE_EXIT_TRAINING", {
                        private _respawnPos = getMarkerPos "respawn_west";
                        if (_respawnPos isEqualTo [0,0,0]) then { _respawnPos = PosOfBLUHQ; };
                        player setPos _respawnPos;
                        hint localize "STR_DUWS_KILLHOUSE_EXIT_MSG";
                    }, [], [1,0.533,0,1]]
                ]] call fnc_open_action_menu;
            },
            [],
            90,
            true,
            true,
            "",
            "true"
        ]] remoteExec ["addAction", [0,-2] select isDedicated, _x];

        // Gear hangs off the terminal rather than the arsenal crates mid-course: both teleport points land
        // at a terminal, and a player made to walk the course to re-kit will not. Suffixed JIP ids because an object-keyed message *is* that object's netId -- a second entry on the same terminal would evict the first, and these props are never deleted.
        [_x, [ACT_EQUIP("STR_DUWS_T_160jkc3a"), fnc_duws_Arsenal, [], 80, false, false, "",
            "_this distance _target < 8 && support_armory_available"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["killhouse_arsenal_%1", netId _x]];
        [_x, [ACT_COMMIT("STR_DUWS_T_ARSENAL_COLLECT"), fnc_arsenal_collect, [], 10, false, false, "",
            "_this distance _target < 8 && support_armory_available"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["killhouse_collect_%1", netId _x]];
        // No quick kits in Limited: an on-demand role loadout bypasses the tracked pool the mode enforces (same reason as fnc_addQuickChangeActions).
        if (!DUWS_arsenalLimited) then {
            [_x, [ACT_EQUIP("STR_DUWS_T_QUICK_KITS"), { [] call fnc_quick_kits_menu; }, [], 80, false, false, "",
                "_this distance _target < 8"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["killhouse_kits_%1", netId _x]];
        };
    } forEach _computerObjects;
};

["INFO", "SUPPORT", "interactions added, killhouse ready"] call fnc_log;
