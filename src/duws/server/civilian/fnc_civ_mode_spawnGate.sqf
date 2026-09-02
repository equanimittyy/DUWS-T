// Locality: server -- called only by fnc_civ_handler_ravage and fnc_civ_handler_wbk, which run on
// the machine whose trigger fired.
//
// Everything both mode handlers do before they place a single unit: take the campaign-wide town
// mutex, re-check that a player is still inside, cancel a pending cleanup, wait out the spawn
// enable time, and refuse a duplicate or already-satisfied request. The two copies of this were
// identical line for line, so a fix to one silently missed the other.
//
// Deliberately unreachable from fnc_civ_handler. The plain handler is what runs mod-free and
// streams its crowd off the enemy-zone model with no mutex at all; giving all three a shared gate
// would put RAVAGE and WBK logic on the path every stock game takes.
//
// Returns [_ok, _targetPop]. Every failing path releases the lock before returning, so a caller
// that stops on _ok == false owes nothing further. The gate cannot abort the caller itself:
// exitWith leaves the nearest call scope, which from in here is this function.

params ["_locIndex", "_centerPos", "_triggerRadius", "_tag"];

if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Function called for location %1", _locIndex]] call fnc_log; };

// Ten-minute ceiling on the queue, after which this town takes the lock regardless: a holder that
// died mid-spawn would otherwise block every other town for the rest of the campaign.
private _timeout = diag_tickTime + 600;
waitUntil {
    sleep 2;
    (civ_current_active_location == -1 || civ_current_active_location == _locIndex) || diag_tickTime > _timeout
};
if (diag_tickTime > _timeout) then {
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Location %1 wait timeout, forcing spawn.", _locIndex]] call fnc_log; };
};

if (civ_current_active_location == -1) then {
    civ_current_active_location = _locIndex;
    publicVariable "civ_current_active_location";
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Lock acquired for location %1", _locIndex]] call fnc_log; };
} else {
    if (civ_current_active_location == _locIndex) then {
        if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Location %1 already holds lock, continuing.", _locIndex]] call fnc_log; };
    } else {
        civ_current_active_location = _locIndex;
        publicVariable "civ_current_active_location";
        if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Location %1 force-acquired lock after timeout.", _locIndex]] call fnc_log; };
    };
};

// Re-checked after the wait, not before it: the queue above can hold a town for minutes, and the
// player whose entry triggered it is often long gone by the time the lock comes free.
private _playersNow = allPlayers select { _x distance _centerPos < _triggerRadius };
if (count _playersNow == 0) exitWith {
    ["ERROR", _tag, format ["[Spawn] No players in location %1 after acquiring lock, aborting.", _locIndex]] call fnc_log;
    [_locIndex] call fnc_civ_mode_releaseLock;
    [false, 0]
};

private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
if (missionNamespace getVariable [_pendingVar, false]) then {
    missionNamespace setVariable [_pendingVar, false];
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Cancelled pending cleanup for %1 due to player re-entry", _locIndex]] call fnc_log; };
};

if (isNil "civ_spawn_enabled_time") then {
    waitUntil { !isNil "civ_spawn_enabled_time" };
};
private _enableTime = missionNamespace getVariable ["civ_spawn_enabled_time", 0];
if (_enableTime > time) then {
    private _wait = _enableTime - time;
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["Delaying spawn for location %1 for %2 seconds", _locIndex, _wait]] call fnc_log; };
    sleep _wait;
};

private _spawningKey = format ["civ_spawning_%1", _locIndex];
private _spawnedKey = format ["civ_spawned_%1", _locIndex];

if (missionNamespace getVariable [_spawningKey, false]) exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Location %1 is already spawning, skipping duplicate request", _locIndex]] call fnc_log; };
    [_locIndex] call fnc_civ_mode_releaseLock;
    [false, 0]
};
missionNamespace setVariable [_spawningKey, true];

if (missionNamespace getVariable [_spawnedKey, false]) exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Location %1 already spawned, skipping", _locIndex]] call fnc_log; };
    missionNamespace setVariable [_spawningKey, false];
    [_locIndex] call fnc_civ_mode_releaseLock;
    [false, 0]
};
missionNamespace setVariable [_spawnedKey, true];

private _targetPop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
if (_targetPop <= 0) exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", _tag, format ["[Spawn] Target population for location %1 is %2, skipping spawn", _locIndex, _targetPop]] call fnc_log; };
    // Both flags cleared, not just the spawning one: the town never filled, so a later entry has
    // to be allowed to try again rather than be turned away as already spawned.
    missionNamespace setVariable [_spawnedKey, false];
    missionNamespace setVariable [_spawningKey, false];
    [_locIndex] call fnc_civ_mode_releaseLock;
    [false, 0]
};

[true, _targetPop]
