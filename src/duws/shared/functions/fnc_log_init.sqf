// Locality: all machines -- compiled first thing by server/server_init.sqf and
// client/client_init.sqf, before the function registry, so the registry self-check and
// every boot milestone can use it.

// Raise to 4 to get DEBUG. Left alone if a caller set it earlier, so a debug session can
// pin the level before init runs.
if (isNil "duws_log_level") then { duws_log_level = 3 }; // 0 off, 1 ERROR .. 4 DEBUG

// Which machine a line came from. In a hosted session server and client share one RPT, and
// without this you cannot tell whether a message is the host's server half or its client.
duws_log_where = call {
    if (isDedicated) exitWith { "SRV" };
    if (isServer) exitWith { "HOST" };
    if (hasInterface) exitWith { "CLI" };
    "HC"
};

// Fixed-width bracket format so the whole mission is greppable as `\[DUWS\]` and filterable
// per level, machine or subsystem without a parser.
fnc_log = {
    params [["_level", "INFO"], ["_tag", "DUWS"], ["_msg", ""]];
    private _n = ["OFF", "ERROR", "WARN", "INFO", "DEBUG"] find (toUpper _level);
    if (_n < 0) then { _n = 3 };
    if (_n > duws_log_level) exitWith {};
    // The one diag_log the mission keeps: this is the sink every other log line funnels
    // into. Routing it through fnc_log makes fnc_log call itself and nothing reaches the rpt.
    diag_log format ["[DUWS][%1][%2][%3] %4", toUpper _level, duws_log_where, _tag, _msg];
};

// A waitUntil that cannot stall silently. An unbounded `waitUntil {cond}` whose condition
// never comes true produces no RPT output at all: the campaign simply stops, and the only
// evidence is the absence of a later log line. This warns every 10 s naming the condition,
// and gives up at _timeout.
// Returns true if the condition came true, false on timeout. It never aborts the caller --
// a slow-but-working wait on a loaded host must not kill a campaign in progress, so the
// call site decides what a timeout means.
// Scheduled only: it sleeps, so callers must be inside spawn/execVM, never `call`.
fnc_waitLogged = {
    params [["_tag", "DUWS"], ["_label", ""], ["_cond", {true}], ["_timeout", 120]];
    if (call _cond) exitWith { true };

    private _start = diag_tickTime;
    private _deadline = _start + _timeout;
    // Back off 10 -> 30 -> 60 -> 120s. A legitimately slow stage (zone generation over a
    // large radius runs minutes) would otherwise bury the rest of the log in repeats, while
    // a fast wait that trips once still gets its warning immediately.
    private _gap = 10;
    private _nextWarn = _start + _gap;
    ["DEBUG", _tag, format ["waiting for: %1", _label]] call fnc_log;

    waitUntil {
        sleep 0.1;
        if (diag_tickTime > _nextWarn) then {
            _gap = 120 min (_gap * 2);
            _nextWarn = diag_tickTime + _gap;
            ["WARN", _tag, format ["still waiting %1s for: %2",
                round (diag_tickTime - _start), _label]] call fnc_log;
        };
        (call _cond) || {diag_tickTime > _deadline}
    };

    private _ok = call _cond;
    if (_ok) then {
        ["INFO", _tag, format ["ok after %1s: %2", round (diag_tickTime - _start), _label]] call fnc_log;
    } else {
        ["ERROR", _tag, format ["TIMEOUT after %1s waiting for: %2 (caller continues)",
            _timeout, _label]] call fnc_log;
    };
    _ok
};

// A campaign loop that dies or stalls leaves no error, only silence: an engine error does not stop a scheduled
// script, and nothing in the mission throws, so no try/catch ever fires. Mission time, because the loops sleep on
// it, so a paused game reads no loop as late. Session state, not saved: a load starts every loop again.
// Guarded: a host compiles this file twice (server_init, then client_init), and a reset forgets the loops beating.
if (isNil "DUWS_loopBeats") then { DUWS_loopBeats = createHashMap };

fnc_loopBeat = {
    params ["_name", "_period"];
    private _beat = DUWS_loopBeats getOrDefault [_name, []];
    if (_beat isEqualTo []) then {
        ["INFO", "LOOP", format ["%1 started, beat every %2 s", _name, _period]] call fnc_log;
    } else {
        if (_beat select 2) then {
            ["INFO", "LOOP", format ["%1 beat again after %2 s silent", _name, round (time - (_beat select 0))]] call fnc_log;
        };
    };
    DUWS_loopBeats set [_name, [time, _period, false]];
};

// Run from the cleanup pass, so the cleanup loop is the one loop whose death this cannot report.
fnc_loopCheck = {
    {
        _y params ["_last", "_period", "_reported"];
        private _silent = time - _last;
        // Floored: the check runs only every 30 s, and one loaded pass can outlast three short periods.
        if (!_reported && {_silent > ((3 * _period) max 60)}) then {
            _y set [2, true];
            ["ERROR", "LOOP", format ["%1 silent for %2 s, expected a beat every %3 s", _x, round _silent, _period]] call fnc_log;
        };
    } forEach DUWS_loopBeats;
};

// Broadcast from the server only. Every machine compiles this file for itself, so a client
// re-broadcasting its own copy would just race the server's for no gain -- but a JIP client
// that has not run client_init yet still needs both to exist.
if (isServer) then {
    publicVariable "fnc_log";
    publicVariable "fnc_waitLogged";
};

["INFO", "BOOT", format ["logging up, level %1", duws_log_level]] call fnc_log;
