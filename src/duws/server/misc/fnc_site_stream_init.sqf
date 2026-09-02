// Locality: server -- publishes the site store. Called once from server_fnc_init, ahead of the zone
// and town state files, which are its consumers.
//
// A site is a keyed place that carries occupants and puts them away when nobody is near: a zone, a
// town, a FOB, the HQ. Its key is the one already in use -- zone_<x>_<y>, town_<n>, FOB_<n>, HQ.
// A site holds one record per occupant it carries, so a town's crowd and a town's garrison are two
// occupants of one site rather than two systems that happen to share a radius.
if (!isServer) exitWith {};

// Plain values only. The mission namespace is written into save games and everything in it must have
// a serialized form, so the hooks -- which are CODE -- live in a store of their own and are rebuilt
// at boot rather than restored (docs/info/architecture/arma_engine_gotchas.md).
if (isNil "DUWS_sites") then { DUWS_sites = createHashMap };
if (isNil "DUWS_occupants") then { DUWS_occupants = createHashMap };
if (isNil "DUWS_siteHooks") then { DUWS_siteHooks = createHashMap };

// Disposal is a property of the site, not of what it carries. A zone's infantry is deleted and a
// FOB's is frozen and they are the same kind of thing, so the choice sits one level up.
//
//   stream -- occupants are taken off the map: men deleted, structures stowed. What was lost is
//             remembered as attrition rather than as objects.
//   freeze -- everything stays where it is with simulation off. For a site whose contents are the
//             player's property: rebuilding those from a table would hand back every soldier who
//             had been killed and every point of damage a building had taken.
#define DISPOSAL_DEFAULT "stream"

// Registered once, by whatever builds the place. Idempotent: a zone that is rebuilt keeps the record
// it already had, because the state on it -- the vacate latch, the empty clock -- describes the
// ground rather than the garrison currently standing on it.
fnc_site_register = {
    params ["_key", "_pos", "_radius", ["_disposal", DISPOSAL_DEFAULT]];
    private _s = DUWS_sites getOrDefault [_key, createHashMap];
    if (count _s == 0) then {
        _s set ["key", _key];
        DUWS_sites set [_key, _s];
        DUWS_occupants set [_key, []];
    };
    // Refreshed on every registration: a zone can be rebuilt at a different radius, and a stale one
    // would stream against ground the site no longer covers.
    _s set ["pos", _pos];
    _s set ["radius", _radius];
    _s set ["disposal", _disposal];
    _s
};

fnc_site_at = { params ["_key"]; DUWS_sites getOrDefault [_key, createHashMap] };

// Buffer, grace and the whole presence answer are per occupant rather than per site, which the numbers
// force: a town's crowd is noticed 200 m out and cleaned up after 60 s, and the garrison standing in the
// same town is 400 and 120. Towns can sit 210 m apart where zones_spacing holds zones 1200 apart, and a
// long grace on a crowd leaves a trail of populated towns behind a player crossing the map -- two
// decisions about one town that a single pair of fields would have to pick a winner between. "Is anyone
// here" therefore has two answers at one town, and each occupant keeps its own.
//
// awaitVacate starts latched: an occupant registered under a player's feet would otherwise read them
// as having just walked up and raise its men around them.
//
// awake starts true on a frozen site and false on a streamed one, because it describes what is
// standing rather than what is wanted: a streamed occupant has spawned nothing yet, while a frozen
// one is registered around men who already exist and are already simulated. Starting it false would
// leave the freeze with no transition to make -- the first empty pass would find the field already
// saying "asleep" and never switch simulation off -- so a base nobody was near when the poller made
// its first pass would stay fully simulated for the campaign. That is the HQ almost every game: it
// registers at base build and the poller does not start until zone build-out has finished.
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
        ["trg", objNull], ["raising", false], ["withdrawing", false]
    ];
    _list pushBack _o;
    DUWS_occupants set [_key, _list];
    _o
};

// [_key, _kind, _side, _profile] call fnc_site_occupant_register_profile -> occupant
//
// Registers an occupant with the presence numbers a named profile carries, so the buffer, grace, latch,
// AI-aware gate and hold-count for every site kind live in DUWS_streamProfiles rather than inline at
// each caller. The default is the zone profile -- the same values this function already defaults to.
fnc_site_occupant_register_profile = {
    params ["_key", "_kind", "_side", "_profile"];
    (DUWS_streamProfiles getOrDefault [_profile, [400, 120, true, true, 2]])
        params ["_buffer", "_grace", "_latch", "_aiAware", "_minAI"];
    [_key, _kind, _side, _buffer, _grace, _latch, _aiAware, _minAI] call fnc_site_occupant_register
};

// createHashMap rather than nil for a miss: every caller reads fields off the answer, and a nil
// would fault the whole pass rather than the one site that was never registered.
fnc_site_occupant = {
    params ["_key", "_kind"];
    private _list = DUWS_occupants getOrDefault [_key, []];
    private _i = _list findIf { (_x get "kind") isEqualTo _kind };
    if (_i < 0) then { createHashMap } else { _list select _i }
};

// Kept apart from the records so those stay serializable. Rebuilt at boot by whatever registers the
// site, which is also what makes a reloaded campaign safe: the data comes back from the save and the
// behaviour comes back from the source.
fnc_site_hooks_set = {
    params ["_key", "_kind", "_hooks"];
    (DUWS_siteHooks getOrDefault [_key, createHashMap, true]) set [_kind, _hooks];
};

// A default is required rather than optional: a site whose hooks have not been registered yet must
// answer, not fault, and "present" answering nil would read as false and quietly stop a whole kind
// from ever waking.
fnc_site_hook = {
    params ["_key", "_kind", "_name", ["_default", {}]];
    ((DUWS_siteHooks getOrDefault [_key, createHashMap]) getOrDefault [_kind, createHashMap])
        getOrDefault [_name, _default]
};

// Asked of the store rather than by comparing the answer against {}. Whether isEqualTo holds for two
// separately compiled empty blocks is not a property worth resting a dispatch on.
fnc_site_hasHook = {
    params ["_key", "_kind", "_name"];
    _name in keys ((DUWS_siteHooks getOrDefault [_key, createHashMap]) getOrDefault [_kind, createHashMap])
};

// Every unit an occupant spawned, one array per site and kind.
// A roster, not a per-unit flag: the capture condition polls this count twice a second, and walking
// allUnits for stamped units would scan hundreds of entries on a firefight's frames. Dead men stay on it
// (a corpse is still the site's to collect, and the count asks about the living); a unit that changes
// hands -- a recruited civilian is the player's now -- is dropped, or teardown would delete a man in their
// squad. Held outside the occupant record (references, not save state), the name derived once.
fnc_site_roster_var = {
    params ["_siteKey", ["_kind", "garrison"]];
    format ["DUWS_siteUnits_%1_%2", _siteKey, _kind]
};

fnc_site_roster = {
    params ["_siteKey", ["_kind", "garrison"]];
    private _var = [_siteKey, _kind] call fnc_site_roster_var;
    private _r = missionNamespace getVariable [_var, []];
    // Stored on first read so every later caller appends into the same array rather than into a
    // copy the next read would discard.
    if (isNil {missionNamespace getVariable _var}) then { missionNamespace setVariable [_var, _r] };
    _r
};

// Emptied in place, not replaced: callers hold the array itself, and swapping in a new one would
// leave them appending into an array nothing reads.
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

// The ground is gone: a FOB the player removed or an enemy destroyed. Everything keyed to it leaves
// the store together, because nothing else ever will -- a record left behind goes on being asked
// whether anybody is standing where the base used to be for the rest of the campaign, and a frozen
// site pays a spatial query for that answer every pass.
//
// Rosters are emptied in place before their variables go, so anything still holding one of those
// arrays reads it as empty rather than appending into a list nothing will collect.
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

// Takes an occupant's men off the map with everything they leave behind.
// By roster, never proximity: a radius sweep once took a neighbouring town's garrison, which then read
// its untouched survivors as a mauling nobody inflicted and came back thinned for the campaign. A vehicle
// goes only once nothing living is aboard, so a site-crewed transport leaves with its crew while a
// player-parked one (not on the roster) stays; empty groups are swept too (not every spawner sets
// deleteGroupWhenEmpty). A composition member is never taken this way (the persistent flag says so) --
// collecting a zone turret gunner's emplacement would delete a gun about to be stowed.
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

// The groups a raise hands back, flattened to the men in them. A roster is a unit list everywhere,
// so a garrison can be counted, thinned and collected without every caller having to know whether it
// is holding groups or men. Global rather than a local helper: the callers are a spawned worker and
// a hook the poller calls, and SQF has no closures -- neither can see the scope it was written in.
fnc_site_men_of = {
    params ["_grps"];
    private _men = [];
    { _men append (units _x) } forEach _grps;
    _men
};

// What an occupant is worth, wherever its men happen to be standing. Deliberately not bounded by the
// site radius: a patrol that has wandered out is still the site's, and reinforcements that walk in
// are not, which is the whole reason a roster exists.
fnc_site_alive = {
    params ["_siteKey", ["_kind", "garrison"]];
    { alive _x } count ([_siteKey, _kind] call fnc_site_roster)
};

// The freeze, as a disposal mode: nothing is rebuilt or deleted, each registered occupant just has its
// simulation switched off where it stands and back on when anybody arrives (where nearly all of an idle
// soldier's cost sits). enableSimulationGlobal, not enableSimulation -- the latter is local, so a
// server-side freeze would leave clients still simulating them. This is why a base is exempt from
// streaming: rebuilding one from a table would refund every killed soldier and lose its buildings' damage,
// and it must stay a live respawn point. Only registered occupants freeze (a player-parked vehicle is not
// the site's). The roster is read each pass, not captured, so a wholesale redeploy does not leave a watcher
// thawing units that no longer exist; only units whose state differs are touched (the command broadcasts).
fnc_site_setFrozen = {
    params ["_key", "_o", "_awake"];
    {
        if (!isNull _x && {!((_x getVariable ["DUWS_siteAwake", true]) isEqualTo _awake)}) then {
            _x enableSimulationGlobal _awake;
            _x setVariable ["DUWS_siteAwake", _awake];
        };
    } forEach ([_key, _o get "kind"] call fnc_site_roster);
};

// The key a town's occupants file under. One place builds it, so the crowd and the garrison cannot
// disagree about which town they are in.
fnc_town_site_key = {
    params ["_townIndex"];
    format ["town_%1", _townIndex]
};

// How often every site is asked whether anything should change. Ten seconds because that is how long
// a player stands somewhere before anything appears, and a garrison materialising late is the pop-in
// every hold and latch in this system exists to prevent. Zones and crowds already ran at this; only
// the town garrison was slower, at thirty.
#define SITE_TICK 10

// [_players, _pos, _ring] call fnc_site_near -> is any player within the ring. The presence test
// for occupants that answer to players alone -- a town's crowd, and a base thawing on approach.
fnc_site_near = {
    params ["_players", "_pos", "_ring"];
    (_players findIf { _x distance _pos < _ring }) >= 0
};

// [_pos, _ring, _minAI, _airRing, _airSpeed] call fnc_site_bluforOrAir -> BLUFOR present.
//
// The ground ring is answered by fnc_duws_bluforNear (a player, or _minAI friendly AI); the air ring,
// when an occupant declares one (0 = none), additionally by any single BLUFOR aircraft -- player or AI
// flown -- reaching in from beyond it. An AA emplacement must wake for a jet high overhead its ground
// ring never reaches, and bluforNear discounts anything airborne, so the air answer is folded back in
// here. The hardpoint form of presence, shared by the raise worker and the register so a wake and its
// confirmation cannot reach opposite answers and strand the gun.
//
// _airSpeed (0 = no gate) and _playerAir filter the air answer to a zone's kind of threat: aircraft
// under the speed, and -- when _playerAir -- only player-crewed ones or a UAV, so an AI transit or an AI
// support heli is not a wake. AA passes neither (speed 0, _playerAir false): catching any jet at cruise
// is what an AA ring is for. Both match the poller's prebuilt committed-air list, so a zone's wake and
// this re-confirmation cannot disagree.
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

// One thread for every site, replacing a thread per zone plus a sleeper per FOB plus two town loops.
//
// The saving is the shared pre-gate, not the thread count: instead of every zone thread running
// fnc_duws_bluforNear (a nearEntities + player-list build) each tick -- 240 spatial queries a minute over
// a mostly empty map -- the player list is built once and every site distance-tested against it, the
// spatial query paid only where somebody is. The risk is one long pass (scheduled scripts share ~3 ms a
// frame), so the rule this poller is written to: gate, then dispatch -- never do real work inline. Every
// hook below either answers a question or spawns a worker.
fnc_site_poller = {
    if (!isServer) exitWith {};
    while {true} do {
        // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
        try {
        sleep SITE_TICK;

        private _players = (call BIS_fnc_listPlayers) select { alive _x };
        // Both lists built once for the whole pass, which is the point of the shared thread. A crowd
        // is held up by a player and a garrison by any BLUFOR, so the two answers differ and each
        // occupant says which it wants -- but neither costs a spatial query until somebody is
        // actually within reach of the site being asked about.
        private _west = (allUnits select { side _x == WEST }) apply { getPosATL _x };
        // WEST aircraft positions, for the air ring an occupant declares. Off the engine's vehicle
        // list, not allUnits: one entry per aircraft rather than one per crew seat, and a far shorter
        // list to walk than every man in the mission. Two of them, built in one pass:
        //   _westAir           every WEST aircraft, for an AA ring that must catch any jet, AI-flown
        //                      included -- that is the emplacement's whole job.
        //   _westAirCommitted  a zone's kind of threat only: player-crewed aircraft (a player in a
        //                      seat, or any UAV -- a player drives one by terminal with its body never
        //                      aboard, so its crew never reads as a player) holding under
        //                      DUWS_zoneAirCommitSpeed. An AI transit or an AI support heli is neither,
        //                      so it never stands a garrison up.
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
        // The hostile half of the same gate, for the frozen sites below. Built here rather than
        // asked per site, because a base with nothing near it would otherwise pay a spatial query
        // every pass for the whole campaign -- and with the HQ plus a FOB per zone and a half, that
        // is more of them than the per-zone threads this poller replaced ever ran.
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
                // An occupant a sibling orders. A zone's prefab has to be standing before anyone is
                // placed on it and its turrets have to be crewed out before it can be stowed, so
                // those two are driven by the garrison's own cycle rather than reaching their own
                // conclusions about presence a fraction of a second apart from it.
                if (_o getOrDefault ["driven", false]) then { continue };
                private _ring = _radius + (_o get "buffer");
                private _here = if (_o get "aiAware") then {
                    // Fewer AI hold a site than raise one. That hysteresis stops a zone flickering
                    // off around the edges of the force that just took it.
                    private _min = if (_o get "awake") then {
                        _o getOrDefault ["minAIHold", _o get "minAI"]
                    } else { _o get "minAI" };
                    // The cheap list gates the expensive helper rather than answering in its place:
                    // fnc_duws_bluforNear still decides every ground arrival, so zones and towns go on
                    // deciding it the same way. What the gate removes is a spatial query per site per
                    // pass across a map that is nearly always empty of anyone.
                    private _ground = (_west findIf { _x distance _pos < _ring }) >= 0
                        && { [_pos, _ring, _min] call fnc_duws_bluforNear };
                    // Air ring: a BLUFOR aircraft reaching in from beyond the ground ring. Only an
                    // occupant that declares one (AA, or a zone) pays it, and it stays a distance test
                    // over a prebuilt list. bluforNear discounts anything airborne, so this is the
                    // whole of a site's reach against aircraft. airRingCommitted picks the committed
                    // list -- a zone wakes only for player-crewed air or a UAV holding on-station; AA
                    // leaves it unset and reads every aircraft, to catch a jet at cruise.
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

                // A frozen site wakes on either side. A garrison that cannot be woken by an attacker
                // is a garrison that loses its base while nobody is looking, and the shared BLUFOR
                // test cannot answer it -- its AI arm exists to notice BLUFOR arriving on OPFOR
                // ground, so at a friendly base it would count the garrison standing in the middle
                // of the radius and never let it sleep.
                //
                // Gated by the cheap list first, the same way the BLUFOR arm is: the helper still
                // decides, because it resolves crew and filters the dead where a bare unit list
                // does neither, but it is only reached where somebody is actually within range.
                if (_frozen && {!_here} && {(_east findIf { _x distance _pos < _ring }) >= 0}) then {
                    _here = ([_pos, _ring] call fnc_opfor_count_at) > 0;
                };

                // One empty sighting spends the latch, and a site cannot clear it and wake on the
                // same pass: the arrival test cannot tell somebody walking up from somebody already
                // standing in the middle, so an occupant registered under a player's feet would
                // otherwise raise its men around them.
                if (_o get "awaitVacate") then {
                    if (!_here) then { _o set ["awaitVacate", false] };
                    _here = false;
                };

                // The empty clock, kept for every occupant whether or not it drives the default
                // transitions below: an occupant with a cycle of its own still measures how long the
                // site has been empty against its own grace.
                if (_here) then { _o set ["emptySince", -1] } else {
                    if ((_o get "emptySince") < 0) then { _o set ["emptySince", diag_tickTime] };
                };

                // An occupant that answers to more than presence keeps its own cycle and is handed
                // the answers this pass already has. A crowd exists whenever somebody is there; a
                // garrison also answers to the reputation band, to what the commander has bought and
                // to whether its town has been cleared, and folding those into wake-and-sleep would
                // mean expressing them as a presence test they are not.
                // if/else rather than an early exit: exitWith inside a forEach block ends the whole
                // loop, so one occupant with a cycle of its own would stop every occupant after it
                // from being serviced at all.
                if (_frozen) then {
                    // A frozen occupant has no wake-and-sleep transition to make: it is always
                    // there, and all that changes is whether it is running. The grace period still
                    // applies, so a player crossing the fence does not thaw the base and refreeze it
                    // a second later.
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
                        // Two consecutive polls rather than a sleep-and-retest. Both forms exist for the
                        // same reason -- a helicopter crossing the radius should not commit a fill --
                        // and this one does not stall the pass that holds every other site's clock.
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

        // Scheduled thread: the engine spreads the pass across frames, so _passMs is wall-clock, not a
        // single-frame cost (arma_engine_gotchas.md). Warn only past half the tick -- cadence slipping,
        // not the many-frame spread the scheduler does by design.
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
