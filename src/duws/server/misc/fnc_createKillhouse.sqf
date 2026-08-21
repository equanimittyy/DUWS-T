// Locality: server; the addAction and HitPart bodies below run on the machine that triggers
// them, not here.
#include "..\..\shared\includes\action_style.hpp"

if (!isServer) exitWith {};

private _centerSpawnX = worldSize * 0.05;
private _centerSpawnY = worldSize * 0.05;

#include "killhouse_composition.sqf"

// Broadcast: clients test their own distance to the killhouse, for the contact markers and for
// the death-penalty exemption in client_init. Left server-local, both silently fail everywhere
// except a hosting player's machine, which is also the server.
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
    // Global: the local form leaves clients simulating props the server froze, and the course
    // furniture then sits somewhere different on every machine.
    _obj enableSimulationGlobal false;
    _obj allowDamage false;
    // Spare it from the cleanup sweep. That sweep bins any un-crewed object in `vehicles` once
    // DUWS_CleanupLifetime elapses with no player inside KEEP_RADIUS, and the course floats at
    // 1000 m in a map corner nobody stands near between runs -- so every prop, terminals included,
    // ages out and vanishes. Server-local: both readers of this flag run server-side, so a
    // broadcast would only add 682 JIP entries for nothing.
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
{
    if (_x isKindOf "SignAd_Sponsor_Blueking_F") then { _flagBlueking = _x; };
    if (_x isKindOf "SignAd_Sponsor_Redstone_F") then { _flagRedstone = _x; };
} forEach _computerObjects;  // Flags never end up in _computerObjects; scanned separately below by proximity.

private _flags = nearestObjects [[_centerSpawnX, _centerSpawnY, _centerSpawnZ], ["SignAd_Sponsor_Blueking_F","SignAd_Sponsor_Redstone_F"], 500];
{
    if (_x isKindOf "SignAd_Sponsor_Blueking_F") then { _flagBlueking = _x; };
    if (_x isKindOf "SignAd_Sponsor_Redstone_F") then { _flagRedstone = _x; };
} forEach _flags;

if (!isNull _flagBlueking) then {
    private _tpA = _flagBlueking modelToWorld [0.484848, -3.43652, 0];
    _tpA set [2, (getPosWorld _flagBlueking select 2) + (-1.04517)];
    missionNamespace setVariable ["killhouse_tpA", _tpA, true];
};
if (!isNull _flagRedstone) then {
    private _tpB = _flagRedstone modelToWorld [0.478247, -4.01343, 0];
    _tpB set [2, (getPosWorld _flagRedstone select 2) + (-1.05688)];
    missionNamespace setVariable ["killhouse_tpB", _tpB, true];
};
["INFO", "SUPPORT", format ["Teleport A: %1, Teleport B: %2", missionNamespace getVariable "killhouse_tpA", missionNamespace getVariable "killhouse_tpB"]] call fnc_log;
missionNamespace setVariable ["killhouse_targets", []];
missionNamespace setVariable ["killhouse_enemies", []];

// Deletes a shot target. Called from each target's HitPart handler, which runs on the
// shooting client, so the delete has to come back here -- the server owns the list.
// The membership test keeps that list authoritative and stops a remote call deleting
// anything that is not a killhouse target. Repeat hits on one target are no-ops.
killhouse_srv_target_hit = {
    if (!isServer) exitWith {};
    params [["_target", objNull]];
    private _targets = missionNamespace getVariable ["killhouse_targets", []];
    if !(_target in _targets) exitWith {};
    missionNamespace setVariable ["killhouse_targets", _targets - [_target], true];
    // Off the list at once but off the map a beat later: the list drives wave pacing and must
    // react immediately, while deleting under the player's crosshair reads as the round
    // missing. The two are deliberately not the same moment.
    _target spawn { sleep killhouse_corpse_linger; deleteVehicle _this; };
};
publicVariable "killhouse_srv_target_hit";

// Run shape. Globals rather than file-scope privates: the killhouse_srv_* bodies run later,
// from remoteExec, where a private declared here is long out of scope.
killhouse_run_total              = 30;
killhouse_wave_size              = 10;
killhouse_wave_threshold         = 3;   // next wave once this many or fewer are alive
killhouse_wave_timeout           = 30;  // ...or this long after the last wave, but only while
killhouse_wave_timeout_threshold = 10;  // at or below this, so a stalled run cannot stack
                                        // wave on wave onto a course nobody is clearing
killhouse_reward_training        = 1;
killhouse_reward_challenge       = 3;
killhouse_progress_delay         = 10;  // before the first progress hint, so the opening
                                        // briefing is readable before the counter overwrites it
killhouse_progress_period        = 1;   // between progress hints after that; cannot resolve
                                        // finer than the wave loop's own tick below
killhouse_corpse_linger          = 2;   // seconds a hit target or body stays before deletion
killhouse_min_spawn_dist         = 15;  // no spawn this close to a player already in the course
killhouse_max_spawn_dist         = 25;  // ...and none further than this from the nearest one, so
                                        // the drill keeps coming to the player instead of making
                                        // them walk the course looking for it
killhouse_area_radius            = 80;  // 3D from the composition centre, and the one
                                        // definition of "inside the killhouse": it picks who
                                        // hears hints and which enemies are still in play. The
                                        // structure reaches ~55 m from centre and floats at
                                        // 1000 m, so it cannot catch anyone standing underneath
publicVariable "killhouse_area_radius"; // clients gate their contact markers on the same value

// Players currently inside the killhouse. Position rather than a flag set by the teleport
// actions: players also arrive by other routes and leave by dying, respawning or the exit
// action, and none of those would clear a flag.
killhouse_srv_occupants = {
    if (!isServer) exitWith { [] };
    private _centre = [
        missionNamespace getVariable ["killhouse_centerX", 0],
        missionNamespace getVariable ["killhouse_centerY", 0],
        missionNamespace getVariable ["killhouse_centerZ", 0]
    ];
    allPlayers select { (getPosWorld _x) distance _centre < killhouse_area_radius }
};

// Every killhouse hint goes through here, so the drill never talks to players out in the
// field. Targeting the occupant units also drops the dedicated-server case for free: it owns
// no player unit, so it is never in the list and needs no isDedicated special case.
killhouse_srv_hint = {
    if (!isServer) exitWith {};
    params ["_msg"];
    private _who = call killhouse_srv_occupants;
    if (_who isEqualTo []) exitWith {};
    [_msg] remoteExec ["hint", _who];
};

// Rung to open a run and again when one ends, whether it was finished or failed. Both bells ring
// rather than the nearer one: they are ~60 m apart at opposite entrances, so 3D falloff already
// decides who hears what, and picking a bell would mean picking a player to pick it from.
// say3D carries to every client by itself, so this needs no remoteExec.
killhouse_srv_bell = {
    if (!isServer) exitWith {};
    { _x say3D "killhouse_bell"; } forEach (missionNamespace getVariable ["killhouse_bells", []]);
};

// Three call sites need exactly this, and a half-cleared killhouse leaks objects at 1000 m
// where nobody will ever see them to notice.
killhouse_srv_clear_all = {
    if (!isServer) exitWith {};
    { deleteVehicle _x; } forEach (missionNamespace getVariable ["killhouse_targets", []]);
    { deleteVehicle _x; } forEach (missionNamespace getVariable ["killhouse_enemies", []]);
    missionNamespace setVariable ["killhouse_targets", [], true];
    missionNamespace setVariable ["killhouse_enemies", [], true];
};

// Clearing the flag is the whole cancel mechanism -- the wave loop polls it and returns
// within a tick. Holding the script handle to terminate would be the obvious alternative,
// but SCRIPT has no serialized form and the mission namespace is written into save games.
killhouse_srv_end_run = {
    if (!isServer) exitWith {};
    params [["_announce", true]];
    if !(missionNamespace getVariable ["killhouse_run_active", false]) exitWith {};
    missionNamespace setVariable ["killhouse_run_active", false];
    if (_announce) then {
        [localize "STR_DUWS_KILLHOUSE_TRAINING_CANCELLED"] call killhouse_srv_hint;
    };
};

// One death inside the course ends a challenge run with nothing paid: the drill is meant to cost
// the player for a bad move, and letting them respawn and walk back in to finish would remove
// that. Training is untouched -- it is a shooting drill against props, not a test.
//
// The client reports every player death and the server decides, rather than the client filtering
// first: killhouse_area_radius is the mission's one definition of "inside the killhouse", and the
// client's own death handler measures a much wider radius for a different purpose (waiving the CP
// death penalty). Two radii answering one question is how they drift apart.
killhouse_srv_player_died = {
    if (!isServer) exitWith {};
    params ["_unit", "_deathPos"];
    if !(missionNamespace getVariable ["killhouse_run_active", false]) exitWith {};
    if !((missionNamespace getVariable ["killhouse_run_mode", ""]) isEqualTo "CHALLENGE") exitWith {};
    private _centre = [
        missionNamespace getVariable ["killhouse_centerX", 0],
        missionNamespace getVariable ["killhouse_centerY", 0],
        missionNamespace getVariable ["killhouse_centerZ", 0]
    ];
    if (_deathPos distance _centre > killhouse_area_radius) exitWith {};

    [false] call killhouse_srv_end_run;   // silent: the failure below replaces the cancel message
    call killhouse_srv_clear_all;
    call killhouse_srv_bell;
    // Occupants plus the unit that just died, so the message does not depend on whether a dead
    // player is still returned by allPlayers -- on a solo run that is the only recipient there is.
    [localize "STR_DUWS_KILLHOUSE_FAILED"] remoteExec ["hint", ((call killhouse_srv_occupants) - [_unit]) + [_unit]];
};
publicVariable "killhouse_srv_player_died";

// Picks up to _want rows for the next wave and removes them from _pool. Returns the rows.
//
// A row is wanted between killhouse_min_spawn_dist and killhouse_max_spawn_dist of the nearest
// player in the course: closer than the minimum usually lands behind the player and reads as a
// glitch rather than a drill, further than the maximum turns the drill into a hunt for it.
// Rejected rows stay in the pool, because the band moves with the player and a row out of reach
// this wave is often the obvious one two waves later. That is the whole reason the pool is
// consumed rather than walked by a cursor: most rows fail the band at any given moment, so a
// cursor would step past nearly the entire composition on the first wave and leave a run of
// three with nothing to place.
//
// The minimum is hard, the maximum only a preference: when the band around a stationary player
// has been picked clean the wave falls back to the nearest rows outside it. Honouring the
// maximum instead would leave the run hanging on a wave that can never come, since nothing
// short of the player moving would ever refill the band.
//
// An empty return therefore means the pool itself is exhausted, which is the caller's signal to
// finish on what is already down.
killhouse_srv_pick_slots = {
    if (!isServer) exitWith {[]};
    params ["_pool", "_want"];
    private _centerX = missionNamespace getVariable "killhouse_centerX";
    private _centerY = missionNamespace getVariable "killhouse_centerY";
    private _centerZ = missionNamespace getVariable "killhouse_centerZ";
    // Resolved once: the test runs per row, the occupant list does not change within a wave.
    private _occupied = (call killhouse_srv_occupants) apply { getPosWorld _x };

    // [rank, index] per usable row: 0 for one inside the band and its distance for one outside,
    // so sorting puts the whole band first and then the nearest of the rest.
    private _ranked = [];
    {
        _x params ["_class", "_dX", "_dY", "_dZ"];
        private _pos = [_centerX + _dX, _centerY + _dY, _centerZ + _dZ];
        // Nobody in the course leaves the band without a reference point, so every row counts
        // as inside it: a run whose players have all left must still place its rows and finish.
        if (_occupied isEqualTo []) then {
            _ranked pushBack [0, _forEachIndex];
        } else {
            private _near = selectMin (_occupied apply { _x distance _pos });
            if (_near >= killhouse_min_spawn_dist) then {
                private _rank = [_near, 0] select (_near <= killhouse_max_spawn_dist);
                _ranked pushBack [_rank, _forEachIndex];
            };
        };
    } forEach _pool;
    _ranked sort true;

    private _take = (_ranked select [0, _want]) apply { _x select 1 };
    private _rows = _take apply { _pool select _x };
    // Highest index first, so each removal leaves the ones still to go where they are.
    _take sort false;
    { _pool deleteAt _x } forEach _take;
    _rows
};

// Spawns one wave onto the composition rows it is handed.
killhouse_srv_spawn_wave = {
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
            // These range targets ignore bullet damage, so a server-side Hit/HandleDamage EH
            // never fires on them. HitPart is a physical-impact event instead, and it runs on
            // the machine that fired the round, so it goes on every machine and bounces the
            // delete back here. Keyed to _obj: JIP clients get it, and the queued message is
            // dropped when the target is deleted.
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
            // Static by design: this is a CQB shooting course, so a row holds where it spawned
            // instead of pathing out to meet the player -- the difficulty is meant to be reading
            // and clearing rooms, not an open firefight. PATH only, so targeting and firing stay
            // on and a row still shoots back. UP, not AUTO: a prone static enemy is a pixel hunt.
            _unit disableAI "PATH";
            _unit setUnitPos "UP";
            // Read by the kill-income handler in server_init.sqf. A run already pays its own
            // reward and can be restarted at will, so its bodies must not also feed the tally.
            _unit setVariable ["killhouse_enemy", true];
            // Drop from the list before deleting, not after: the wave loop counts this array
            // to decide when the next wave is due and when the run is finished, and a
            // deleted unit no longer matches for removal. The body then lingers, so a kill
            // is something the player sees rather than a unit blinking out of existence.
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

// Drives one run to completion in either mode, and supersedes whatever was running.
killhouse_srv_start_run = {
    if (!isServer) exitWith {};
    params ["_mode"];
    private _allSlots = missionNamespace getVariable "killhouse_targetData";
    if (isNil "_allSlots") exitWith {};

    [false] call killhouse_srv_end_run;   // silent: a new run supersedes, it does not cancel
    call killhouse_srv_clear_all;

    // One shuffled composition row per spawn, taken out of the pool as it is used, so no row is
    // reused within a run and nothing is ever spawned on top of anything already placed. That is
    // also why the total is capped at the row count instead of wrapping. It is a guarantee about
    // the moment of spawning only -- enemies path away afterwards and may bunch up wherever they
    // like. Shuffled from a copy because the pool is consumed: BIS_fnc_arrayShuffle is free to
    // work in place, which would eat the master row list a run at a time.
    private _slots = (+_allSlots) call BIS_fnc_arrayShuffle;
    private _total = killhouse_run_total min (count _slots);
    // Without this an empty composition would read as "all spawned, none alive" on the first
    // pass and pay the reward for a run that never happened.
    if (_total < 1) exitWith {};

    // Supersede token. Clearing the active flag alone does not stop the outgoing thread: it
    // can wake from its sleep after this function has set the flag back to true and carry on
    // spawning alongside the new run. Each run captures its own id and stops the moment it is
    // no longer the current one. A number, so it still serializes into a save.
    private _runId = (missionNamespace getVariable ["killhouse_run_id", 0]) + 1;
    missionNamespace setVariable ["killhouse_run_id", _runId];
    missionNamespace setVariable ["killhouse_run_active", true];
    // Read by killhouse_srv_player_died: only a challenge run is failed by a death.
    missionNamespace setVariable ["killhouse_run_mode", _mode];
    call killhouse_srv_bell;

    [_mode, _slots, _total, _runId] spawn {
        params ["_mode", "_slots", "_total", "_runId"];
        private _listVar = ["killhouse_enemies", "killhouse_targets"] select (_mode == "TRAINING");
        private _spawned = 0;
        private _lastWave = time;
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
            // Anything outside the volume has left the course -- with movement disabled that
            // takes blast or ragdoll. The drop is 1000 m onto open sea, and a unit that survives
            // the water would swim about forever without ever firing its Killed handler --
            // the run could then never reach zero alive and would hang. Killing it here routes
            // it through the same handler as a shot enemy, so the count stays honest.
            {
                if ((getPosWorld _x) distance _centre > killhouse_area_radius) then {
                    _x setDamage 1;
                };
            } forEach (missionNamespace getVariable ["killhouse_enemies", []]);

            private _alive = count (missionNamespace getVariable [_listVar, []]);
            if (_spawned >= _total) then {
                _complete = (_alive == 0);
            } else {
                private _due = (_alive <= killhouse_wave_threshold)
                    || { _alive <= killhouse_wave_timeout_threshold
                         && { time - _lastWave >= killhouse_wave_timeout } };
                if (_due) then {
                    private _want = killhouse_wave_size min (_total - _spawned);
                    private _wave = [_slots, _want] call killhouse_srv_pick_slots;
                    if !(_wave isEqualTo []) then {
                        [_mode, _wave] call killhouse_srv_spawn_wave;
                        _spawned = _spawned + (count _wave);
                        _lastWave = time;
                    };
                    // Pool emptied without meeting the count: every row the composition has is
                    // already down or was down earlier this run. Settle the run at what actually
                    // went out, so the loop finishes instead of waiting on a wave that will
                    // never come.
                    if (_slots isEqualTo []) then { _total = _spawned; };
                };
            };
            // Re-read rather than reuse _alive: a wave may have gone up this pass, and the
            // count the player is told should include it.
            if (!_complete && { time >= _nextProgress }) then {
                private _up = count (missionNamespace getVariable [_listVar, []]);
                [format [localize "STR_DUWS_KILLHOUSE_PROGRESS", _total - (_spawned - _up), _total, _up]] call killhouse_srv_hint;
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

killhouse_srv_cleanup = {
    if (!isServer) exitWith {};
    [true] call killhouse_srv_end_run;
    call killhouse_srv_clear_all;
    [localize "STR_DUWS_T_CLEANUP_DONE"] call killhouse_srv_hint;
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

        // Gear hangs off the terminal rather than the arsenal crates mid-course: both teleport
        // points land at a terminal, and a player made to walk the course to re-kit will not.
        // Suffixed JIP ids because an object-keyed message *is* that object's netId -- a second
        // entry on the same terminal would evict the first, and these props are never deleted.
        [_x, [ACT_EQUIP("STR_DUWS_T_160jkc3a"), fnc_duws_Arsenal, [], 80, false, false, "",
            "_this distance _target < 8 && support_armory_available"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["killhouse_arsenal_%1", netId _x]];
        // No quick kits in Limited: an on-demand role loadout bypasses the tracked pool the mode
        // enforces (same reason as fnc_addQuickChangeActions).
        if (!DUWS_arsenalLimited) then {
            [_x, [ACT_EQUIP("STR_DUWS_T_QUICK_KITS"), { [] call fnc_quick_kits_menu; }, [], 80, false, false, "",
                "_this distance _target < 8"]] remoteExec ["addAction", [0,-2] select isDedicated, format ["killhouse_kits_%1", netId _x]];
        };
    } forEach _computerObjects;
};

["INFO", "SUPPORT", "interactions added, killhouse ready"] call fnc_log;
