// Locality: server -- publishes the site store; loaded ahead of the zone/town state files that consume it.
// Site key: zone_<x>_<y> / town_<n> / FOB_<n> / HQ. One record per occupant, so a town's crowd and garrison are two occupants of one site, not two systems sharing a radius.
if (!isServer) exitWith {};

// Mission namespace values must serialize into save games; hooks are CODE, so they live in their own
// store, rebuilt at boot rather than restored (docs/info/architecture/arma_engine_gotchas.md).
if (isNil "DUWS_sites") then { DUWS_sites = createHashMap };
if (isNil "DUWS_occupants") then { DUWS_occupants = createHashMap };
if (isNil "DUWS_siteHooks") then { DUWS_siteHooks = createHashMap };

// Disposal is a property of the site, not of what it carries: a zone's infantry is deleted, a FOB's
// is frozen, same kind of thing decided one level up.
// stream: occupants come off the map, losses counted as attrition. freeze: simulation off in place --
// rebuilding player-owned contents from a table would refund every killed soldier and repaired damage point.
#define DISPOSAL_DEFAULT "stream"

// Idempotent: a rebuilt zone keeps its existing record -- the vacate latch and empty clock describe
// the ground, not the garrison currently standing on it.
fnc_site_register = {
    params ["_key", "_pos", "_radius", ["_disposal", DISPOSAL_DEFAULT]];
    private _s = DUWS_sites getOrDefault [_key, createHashMap];
    if (count _s == 0) then {
        _s set ["key", _key];
        DUWS_sites set [_key, _s];
        DUWS_occupants set [_key, []];
    };
    // Refreshed every call: a rebuilt zone can change radius, and a stale one would stream against
    // ground the site no longer covers.
    _s set ["pos", _pos];
    _s set ["radius", _radius];
    _s set ["disposal", _disposal];
    _s
};

fnc_site_at = { params ["_key"]; DUWS_sites getOrDefault [_key, createHashMap] };

// Buffer/grace/presence live per occupant, not per site: a town's crowd (200 m/60 s) and its garrison
// (400 m/120 s) need different answers, and towns sit close enough (210 m apart vs 1200 m zone spacing)
// that one shared pair of fields could not serve both without a trail of populated towns behind a
// crossing player.
//
// awaitVacate starts latched, else an occupant registered under a player's feet reads them as just
// having walked up and raises men around them.
//
// awake starts true on a frozen site (men already exist and are simulated) and false on a streamed one
// (nothing spawned yet) -- describing what stands, not what's wanted. Starting frozen awake=false would
// leave no transition to flip simulation off, so a base nobody is near on the poller's first pass (the
// HQ, almost every game) would stay fully simulated all campaign.
fnc_site_occupant_register = {
    params ["_key", "_kind", ["_side", EAST], ["_buffer", 400], ["_grace", 120], ["_latch", true],
            ["_aiAware", true], ["_minAI", 2]];
    private _list = DUWS_occupants getOrDefault [_key, []];
    private _i = _list findIf { (_x get "kind") isEqualTo _kind };
    if (_i >= 0) exitWith { _list select _i };
    private _frozen = (([_key] call fnc_site_at) getOrDefault ["disposal", DISPOSAL_DEFAULT])
        isEqualTo "freeze";
    private _o = createHashMapFromArray [
        ["kind", _kind], ["side", _side], ["buffer", _buffer], ["grace", _grace],
        ["aiAware", _aiAware], ["minAI", _minAI],
        ["awake", _frozen], ["seenLast", false], ["emptySince", -1], ["awaitVacate", _latch],
        ["baseline", 0], ["tier", 0], ["deployedList", []], ["deployedStrength", 0],
        ["trg", objNull], ["raising", false]
    ];
    _list pushBack _o;
    DUWS_occupants set [_key, _list];
    _o
};

// Presence numbers come from a named profile in DUWS_streamProfiles (buffer, grace, latch, AI-aware,
// hold-count), not inlined per caller. Default profile matches this function's own defaults.
fnc_site_occupant_register_profile = {
    params ["_key", "_kind", "_side", "_profile"];
    (DUWS_streamProfiles getOrDefault [_profile, [400, 120, true, true, 2]])
        params ["_buffer", "_grace", "_latch", "_aiAware", "_minAI"];
    [_key, _kind, _side, _buffer, _grace, _latch, _aiAware, _minAI] call fnc_site_occupant_register
};

// createHashMap rather than nil for a miss: callers read fields off the answer, and nil would fault
// the whole pass rather than just the unregistered site.
fnc_site_occupant = {
    params ["_key", "_kind"];
    private _list = DUWS_occupants getOrDefault [_key, []];
    private _i = _list findIf { (_x get "kind") isEqualTo _kind };
    if (_i < 0) then { createHashMap } else { _list select _i }
};

fnc_site_hooks_set = {
    params ["_key", "_kind", "_hooks"];
    (DUWS_siteHooks getOrDefault [_key, createHashMap, true]) set [_kind, _hooks];
};

// A default is required, not optional: an unregistered site must answer, not fault -- "present"
// returning nil would read as false and quietly stop a whole kind from ever waking.
fnc_site_hook = {
    params ["_key", "_kind", "_name", ["_default", {}]];
    ((DUWS_siteHooks getOrDefault [_key, createHashMap]) getOrDefault [_kind, createHashMap])
        getOrDefault [_name, _default]
};

// Asked of the store, not by comparing against {}: whether isEqualTo holds for two separately
// compiled empty CODE blocks isn't safe to dispatch on.
fnc_site_hasHook = {
    params ["_key", "_kind", "_name"];
    _name in keys ((DUWS_siteHooks getOrDefault [_key, createHashMap]) getOrDefault [_kind, createHashMap])
};

// A roster (unit array per site+kind), not a per-unit flag: the capture condition polls this count
// twice a second, and walking allUnits for stamped units would scan hundreds of entries mid-firefight.
// Dead men stay on it (still the site's to collect; the count asks about the living). A unit that
// changes hands (a recruited civilian) is dropped, or teardown would delete a man from their new squad.
// Held outside the occupant record as references, not save state; the var name is derived once.
fnc_site_roster_var = {
    params ["_siteKey", ["_kind", "garrison"]];
    format ["DUWS_siteUnits_%1_%2", _siteKey, _kind]
};

fnc_site_roster = {
    params ["_siteKey", ["_kind", "garrison"]];
    private _var = [_siteKey, _kind] call fnc_site_roster_var;
    private _r = missionNamespace getVariable [_var, []];
    // Stored on first read so later callers append into the same array, not a copy the next read
    // would discard.
    if (isNil {missionNamespace getVariable _var}) then { missionNamespace setVariable [_var, _r] };
    _r
};

// Emptied in place, not replaced: callers hold the array itself, and swapping in a new one would
// leave them appending into one nothing reads.
fnc_site_roster_clear = {
    params ["_siteKey", ["_kind", "garrison"]];
    private _r = [_siteKey, _kind] call fnc_site_roster;
    _r resize 0;
};

fnc_site_roster_drop = {
    params ["_siteKey", "_unit", ["_kind", "garrison"]];
    private _r = [_siteKey, _kind] call fnc_site_roster;
    private _i = _r find _unit;
    if (_i >= 0) then { _r deleteAt _i };
};

// Everything keyed to a retired site leaves the store together -- a record left behind keeps being
// asked whether anybody's at the (now gone) base for the rest of the campaign, paying a spatial query
// every pass.
// Rosters are emptied in place before their variables go, so anything still holding one of those
// arrays reads it as empty rather than appending into a list nothing collects.
fnc_site_retire = {
    params ["_key"];
    {
        private _kind = _x get "kind";
        [_key, _kind] call fnc_site_roster_clear;
        missionNamespace setVariable [[_key, _kind] call fnc_site_roster_var, nil];
    } forEach (DUWS_occupants getOrDefault [_key, []]);
    DUWS_sites deleteAt _key;
    DUWS_occupants deleteAt _key;
    DUWS_siteHooks deleteAt _key;
};

// By roster, never proximity: a radius sweep once caught a neighbouring town's garrison, which then
// read its untouched survivors as a mauling nobody inflicted and came back thinned all campaign.
// A vehicle goes only once nothing living is aboard, so a site-crewed transport leaves with its crew
// while a player-parked one (off roster) stays; empty groups are swept too since not every spawner
// sets deleteGroupWhenEmpty.
// A composition member is never taken this way (persistent flag) -- collecting a zone turret gunner
// would delete a gun about to be stowed.
fnc_site_collect = {
    params ["_siteKey", ["_kind", "garrison"]];
    private _men = ([_siteKey, _kind] call fnc_site_roster) select { !isNull _x };
    private _vehs = [];
    private _grps = [];
    {
        private _veh = vehicle _x;
        if (_veh != _x && {!(_veh getVariable ["persistent", false])}) then {
            _vehs pushBackUnique _veh;
        };
        _grps pushBackUnique (group _x);
    } forEach _men;
    { deleteVehicle _x } forEach _men;
    { if (({alive _x} count crew _x) == 0) then { deleteVehicle _x } } forEach _vehs;
    { if (count units _x == 0) then { deleteGroup _x } } forEach _grps;
    [_siteKey, _kind] call fnc_site_roster_clear;
};

// A roster is a unit list everywhere, so a garrison can be counted, thinned and collected without
// every caller knowing whether it holds groups or men.
// Global rather than local: callers are a spawned worker and a poller hook, and SQF has no closures --
// neither can see the scope this was written in.
fnc_site_men_of = {
    params ["_grps"];
    private _men = [];
    { _men append (units _x) } forEach _grps;
    _men
};

// Deliberately not bounded by the site radius: a patrol that's wandered out is still the site's, and
// reinforcements walking in are not -- the whole reason a roster exists.
fnc_site_alive = {
    params ["_siteKey", ["_kind", "garrison"]];
    { alive _x } count ([_siteKey, _kind] call fnc_site_roster)
};

// Freeze: nothing rebuilt or deleted, an occupant's simulation flips off where it stands.
// enableSimulationGlobal, not enableSimulation -- the latter is local, so a server-side freeze would
// leave clients still simulating.
// Only registered occupants freeze (a player-parked vehicle isn't the site's). The roster is read each
// pass, not captured, so a wholesale redeploy doesn't leave a watcher thawing units that no longer
// exist; only units whose state differs are touched (the command already broadcasts).
fnc_site_setFrozen = {
    params ["_key", "_o", "_awake"];
    {
        if (!isNull _x && {!((_x getVariable ["DUWS_siteAwake", true]) isEqualTo _awake)}) then {
            _x enableSimulationGlobal _awake;
            _x setVariable ["DUWS_siteAwake", _awake];
        };
    } forEach ([_key, _o get "kind"] call fnc_site_roster);
};

// Built in one place, so the crowd and garrison can't disagree about which town they're in.
fnc_town_site_key = {
    params ["_townIndex"];
    format ["town_%1", _townIndex]
};

// Ten seconds: how long a player can stand somewhere before anything should appear, since a
// late-materialising garrison is the pop-in every hold/latch here exists to prevent. Zones and crowds
// already ran at this; only the town garrison was slower, at thirty.
#define SITE_TICK 10

// The presence test for occupants that answer to players alone -- a town's crowd, and a base thawing
// on approach.
fnc_site_near = {
    params ["_players", "_pos", "_ring"];
    (_players findIf { _x distance _pos < _ring }) >= 0
};

// Ground ring: fnc_duws_bluforNear (player, or _minAI friendly AI). Air ring (occupant-declared,
// 0 = none): any BLUFOR aircraft reaching in from beyond it, player or AI flown -- folded in here
// because bluforNear discounts anything airborne, and an AA emplacement must still wake for a jet
// overhead its ground ring never reaches.
// Shared by the raise worker and the register, so a wake and its confirmation can't reach opposite
// answers and strand the gun.
// _airSpeed (0 = no gate) and _playerAir narrow the air answer to a zone's threat: under-speed and,
// when _playerAir, only player-crewed or a UAV -- so an AI transit or support heli isn't a wake. AA
// passes neither, to catch any jet at cruise. Both match the poller's prebuilt committed-air list, so
// wake and re-confirmation can't disagree.
fnc_site_bluforOrAir = {
    params ["_pos", "_ring", ["_minAI", 2], ["_airRing", 0], ["_airSpeed", 0], ["_playerAir", false]];
    if ([_pos, _ring, _minAI] call fnc_duws_bluforNear) exitWith { true };
    if (_airRing <= 0) exitWith { false };
    ((_pos nearEntities [["Air"], _airRing]) findIf {
        ({ side _x == WEST } count (crew _x)) > 0
        && {_airSpeed <= 0 || {speed _x < _airSpeed}}
        && {!_playerAir || {unitIsUAV _x || {(crew _x) findIf { isPlayer _x } >= 0}}}
    }) >= 0
};

// Replaces a thread per zone plus a sleeper per FOB plus two town loops with one. The saving is the
// shared pre-gate, not the thread count: per-zone fnc_duws_bluforNear calls cost ~240 spatial queries a
// minute over a mostly empty map; here the player list is built once and every site distance-tested
// against it first, paying the spatial query only where somebody is.
// Scheduled scripts share ~3 ms a frame, so the rule this poller is written to: gate, then dispatch,
// never do real work inline. Every hook below either answers a question or spawns a worker.
fnc_site_poller = {
    if (!isServer) exitWith {};
    while {true} do {
        // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
        try {
        sleep SITE_TICK;

        private _players = (call BIS_fnc_listPlayers) select { alive _x };
        // A crowd is held up by a player, a garrison by any BLUFOR -- two different answers, so both
        // lists are built once here, and neither costs a spatial query until somebody is actually
        // within reach of the site being asked about.
        private _west = (allUnits select { side _x == WEST }) apply { getPosATL _x };
        // WEST aircraft positions for occupant-declared air rings, off the vehicle list (not
        // allUnits): one entry per aircraft, not per crew seat, and far shorter to walk.
        // _westAir: every WEST aircraft, for an AA ring that must catch any jet, AI-flown included.
        // _westAirCommitted: player-crewed aircraft (or any UAV -- its operator flies by terminal,
        // body never aboard, so crew never reads as a player) holding under DUWS_zoneAirCommitSpeed,
        // since an AI transit or support heli should never stand a garrison up.
        private _westAir = [];
        private _westAirCommitted = [];
        {
            if !(({ side _x == WEST } count (crew _x)) > 0) then { continue };
            private _ap = getPosATL _x;
            _westAir pushBack _ap;
            if (speed _x < DUWS_zoneAirCommitSpeed
                && {unitIsUAV _x || {(crew _x) findIf { isPlayer _x } >= 0}}) then {
                _westAirCommitted pushBack _ap;
            };
        } forEach (vehicles select { _x isKindOf "Air" });
        // Hostile half of the same gate, for frozen sites below. Built once here rather than per
        // site: with the HQ plus a FOB per zone-and-a-half, per-site spatial queries would run more
        // often than the per-zone threads this poller replaced.
        private _east = (allUnits select { side _x == EAST }) apply { getPosATL _x };
        private _now = time;
        private _t0 = diag_tickTime;

        {
            private _key = _x;
            private _site = _y;
            private _pos = _site get "pos";
            private _radius = _site get "radius";
            private _frozen = (_site get "disposal") isEqualTo "freeze";

            {
                private _o = _x;
                private _kind = _o get "kind";
                // "driven" occupants are ordered by a sibling: a zone's prefab must stand before
                // anyone is placed on it, and turrets must be crewed before stowing, so those two
                // follow the garrison's own cycle instead of reaching their own presence conclusion a
                // fraction of a second apart from it.
                if (_o getOrDefault ["driven", false]) then { continue };
                private _ring = _radius + (_o get "buffer");
                private _here = if (_o get "aiAware") then {
                    // Fewer AI hold a site than raise one -- hysteresis that stops a zone flickering
                    // off around the edges of the force that just took it.
                    private _min = if (_o get "awake") then {
                        _o getOrDefault ["minAIHold", _o get "minAI"]
                    } else { _o get "minAI" };
                    // Gates the expensive helper rather than replacing it: fnc_duws_bluforNear still
                    // decides every ground arrival, so zones and towns keep deciding it the same way.
                    private _ground = (_west findIf { _x distance _pos < _ring }) >= 0
                        && { [_pos, _ring, _min] call fnc_duws_bluforNear };
                    // Air ring: a BLUFOR aircraft reaching in from beyond the ground ring, only for
                    // occupants that declare one (AA, or a zone), against the prebuilt list --
                    // bluforNear discounts anything airborne, so this is a site's whole reach against
                    // aircraft. airRingCommitted picks player-crewed/UAV only for a zone; AA reads
                    // every aircraft to catch a jet at cruise.
                    _ground || {
                        private _ar = _o getOrDefault ["airRing", 0];
                        _ar > 0 && {
                            private _air = if (_o getOrDefault ["airRingCommitted", false]) then { _westAirCommitted } else { _westAir };
                            (_air findIf { _x distance _pos < _ar }) >= 0
                        }
                    }
                } else {
                    [_players, _pos, _ring] call fnc_site_near
                };

                // A frozen site must wake on either side too: a garrison the shared BLUFOR test can't
                // rouse (its AI arm watches for BLUFOR on OPFOR ground) would sit in the middle of the
                // radius unable to ever sleep, and lose its base while nobody's looking.
                // Gated by the cheap list first: fnc_side_count_at still decides (it resolves crew
                // and filters the dead, which the bare _east list does neither), reached only once
                // somebody is actually within range.
                if (_frozen && {!_here} && {(_east findIf { _x distance _pos < _ring }) >= 0}) then {
                    _here = ([_pos, _ring, EAST] call fnc_side_count_at) > 0;
                };

                // Latch-clear and wake happen on different passes: the arrival test can't distinguish
                // someone walking up from someone already standing there, so doing both in one pass
                // would raise men around whoever was already inside.
                if (_o get "awaitVacate") then {
                    if (!_here) then { _o set ["awaitVacate", false] };
                    _here = false;
                };

                // emptySince is kept for every occupant, even one with its own cycle below, since it
                // still measures how long the site's been empty against its own grace.
                if (_here) then { _o set ["emptySince", -1] } else {
                    if ((_o get "emptySince") < 0) then { _o set ["emptySince", diag_tickTime] };
                };

                // An occupant that answers to more than presence (a garrison also weighs reputation,
                // purchases, and whether its town is cleared) keeps its own cycle and is handed this
                // pass's answers rather than folding into a presence test it isn't.
                // if/else, not an early exit: exitWith inside a forEach ends the whole loop, so one
                // occupant with its own cycle would stop every occupant after it from being serviced.
                if (_frozen) then {
                    // A frozen occupant is always there -- only whether it's running changes. Grace
                    // still applies so a player crossing the fence doesn't thaw and immediately
                    // refreeze the base.
                    private _awake = _here || {_now - (_o getOrDefault ["lastSeen", -1e6]) <= (_o get "grace")};
                    if (_here) then { _o set ["lastSeen", _now] };
                    if !((_o get "awake") isEqualTo _awake) then {
                        _o set ["awake", _awake];
                        [_key, _o, _awake] call fnc_site_setFrozen;
                    };
                } else {
                if ([_key, _kind, "tick"] call fnc_site_hasHook) then {
                    private _fnc_tick = [_key, _kind, "tick"] call fnc_site_hook;
                    [_key, _o, _here, _now] call _fnc_tick;
                } else {
                    if (_o get "awake") then {
                        if (_here) then { _o set ["lastSeen", _now] };
                        if (_now - (_o getOrDefault ["lastSeen", _now]) >= (_o get "grace")) then {
                            _o set ["awake", false];
                            private _fnc_sleep = [_key, _kind, "sleep"] call fnc_site_hook;
                            [_key, _o] call _fnc_sleep;
                        };
                    } else {
                        // Two consecutive polls, not a sleep-and-retest: both exist so a helicopter
                        // transiting the radius doesn't commit a fill, but this form doesn't stall the
                        // shared pass that holds every other site's clock.
                        private _fnc_present = [_key, _kind, "present", {true}] call fnc_site_hook;
                        if (_here && {_o get "seenLast"} && {[_key, _o] call _fnc_present}) then {
                            _o set ["awake", true];
                            _o set ["lastSeen", _now];
                            private _fnc_wake = [_key, _kind, "wake"] call fnc_site_hook;
                            [_key, _o] call _fnc_wake;
                        };
                };
                };
                };
                _o set ["seenLast", _here];
            } forEach (DUWS_occupants getOrDefault [_key, []]);
        } forEach DUWS_sites;

        // Scheduled thread: the engine spreads the pass across frames, so _passMs is wall-clock, not
        // single-frame cost (arma_engine_gotchas.md). Warn only past half the tick, since that's
        // cadence slipping, not the scheduler's by-design multi-frame spread.
        private _passMs = round ((diag_tickTime - _t0) * 1000);
        if (_passMs > SITE_TICK * 500) then {
            ["WARN", "STREAM", format ["site pass %1 ms of a %2 s cadence (%3 sites) -- cannot sustain, per-site work may have crept inline",
                _passMs, SITE_TICK, count DUWS_sites]] call fnc_log;
        };
        if (duws_log_level >= 4) then {
            ["DEBUG", "STREAM", format ["site pass: %1 sites in %2 ms",
                count DUWS_sites, _passMs]] call fnc_log;
        };
        } catch {
            ["ERROR", "STREAM", format ["site pass threw, thread held alive: %1", _exception]] call fnc_log;
            sleep 10;
        };
    };
};
