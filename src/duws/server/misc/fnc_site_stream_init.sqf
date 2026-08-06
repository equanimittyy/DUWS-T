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
// at boot rather than restored (docs/info/arma_engine_gotchas.md).
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

// Buffer, grace and the whole presence answer are per occupant rather than per site, which the
// numbers force: a town's crowd is noticed 200 m out and cleaned up after 60 s, and the garrison
// standing in the same town is 400 and 120. Towns can sit 210 m apart where zones_spacing holds
// zones 1200 apart, and a long grace on a crowd leaves a trail of populated towns behind a player
// crossing the map -- two decisions about one town that a single pair of fields would have to pick a
// winner between. "Is anyone here" therefore has two answers at one town, and each occupant keeps
// its own.
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

// Every unit an occupant spawned, in one array per site and kind.
//
// A roster rather than a flag on each unit: the zone capture condition reads its count twice a
// second while a player stands in the zone, and walking allUnits to find the stamped ones would put
// a several-hundred-entry scan on exactly the frames a firefight is using. The crowd handler was
// doing that walk -- allUnits + allDeadMen, once per emptied town -- for want of anywhere to keep
// the list.
//
// Dead men stay on it. A corpse is still the site's to collect, and the count below asks about the
// living, so nothing has to be removed at the moment of death. What does have to leave is anything
// that changes hands -- a recruited civilian is the player's now, and a teardown that still held it
// would delete a man standing in their squad.
//
// Held outside the occupant record because a roster is object references, and the record is the half
// of this that has to survive a save.
// One derivation of the name, because two readers spell it: the roster itself and the retirement
// below, which has to unset the variable the roster created.
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

// Takes an occupant's men off the map along with everything they leave behind.
//
// By roster, never by proximity: a radius sweep took a neighbouring town's garrison with it, and
// that town then measured its survivors against its own baseline, recorded a mauling nobody
// inflicted, and came back thinned for the rest of the campaign.
//
// A vehicle goes only once nothing living is aboard, so a transport the site crewed leaves with its
// crew while one the player parked in the ring is not on this roster and stays. Groups are swept
// because not every spawner sets deleteGroupWhenEmpty, and an empty group left behind on every
// teardown of every site shows up only as a slow drift across a long campaign.
//
// A composition member is never taken this way, and the persistent flag is what says so: a zone's
// turret gunner is on this roster and the thing he is sitting in is the zone's own emplacement, so
// collecting "the vehicle he was in" once he is gone deletes a gun that was about to be stowed --
// and a stow skips nulls, so the zone comes back without it, permanently, from its first teardown
// on. The flag is set by fnc_duws_keep on everything a composition owns and by nothing else.
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

// The freeze, as a disposal mode. Nothing is rebuilt and nothing is deleted: every registered
// occupant of the site has its simulation switched off where it stands, and switched back on when
// anybody arrives.
//
// This is why a base is the exception to streaming. A zone garrison belongs to OPFOR and is rebuilt
// from a table, so deleting it loses nothing. A base's belongs to the player: rebuilding it would
// hand back every soldier who had been killed, which is a free version of the redeploy they would
// otherwise pay for, and its buildings carry damage a table cannot reproduce. A base is also a
// respawn point, so it has to be able to receive somebody who arrives in an instant with no approach
// to notice. Freezing satisfies all three, and simulation is where nearly all of an idle soldier's
// cost sits.
//
// enableSimulationGlobal, not enableSimulation: the latter is local, so a server-side freeze would
// leave every client still simulating them.
//
// Only registered occupants freeze. A vehicle the player parked at base is their property and not
// the site's, which also keeps this off anything the base-keep radius already exists to protect.
//
// The roster is read each pass rather than captured: a redeploy replaces a garrison wholesale, and a
// watcher holding the old men would thaw units that no longer exist while the new ones stayed
// frozen. Only units whose state actually differs are touched, because the command broadcasts.
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

// [_players, _pos, _ring, _airRing] call fnc_site_nearOrAir -> is anybody present.
//
// The ground ring answers for everyone; the air ring, when an occupant declares one (0 = none),
// answers additionally for players in aircraft only. An AA emplacement has to wake for a jet passing
// high overhead, out where its ground ring would never reach, without every distant foot patrol
// waking it too. Shared by the poller and the hardpoint raise worker so both judge presence the same
// way -- a wake and its confirmation reaching opposite answers would strand the emplacement.
fnc_site_nearOrAir = {
    params ["_players", "_pos", "_ring", ["_airRing", 0]];
    if ((_players findIf { _x distance _pos < _ring }) >= 0) exitWith { true };
    if (_airRing <= 0) exitWith { false };
    (_players findIf { (vehicle _x) isKindOf "Air" && {_x distance _pos < _airRing} }) >= 0
};

// One thread for every site, replacing a thread per zone plus a sleeper per FOB plus two town loops.
//
// The saving is the shared pre-gate rather than the thread count. Each zone thread called
// fnc_duws_bluforNear every tick unconditionally, and that runs a nearEntities over radius + buffer
// as well as a player-list build: forty zones at six ticks a minute is 240 spatial queries a minute
// across a map that is empty of players almost everywhere. Here the player list is built once and
// every site is distance-tested against it, and the spatial query is only paid where somebody
// actually is. The crowd handler already did this and stated the principle; zones never got it
// because each had a thread of its own and nothing to share a list with.
//
// The risk this shape takes on is one long pass. Scheduled scripts share about 3 ms a frame between
// them, so a pass that outgrows the budget is split across frames and the sites at the tail are
// serviced later than those at the head. Two hundred and fifty distance tests sit well inside it;
// what would not is per-site work done inline. Hence the rule this poller is written to:
// **gate, then dispatch -- never do real work here.** Every hook below either answers a question or
// spawns a worker.
fnc_site_poller = {
    if (!isServer) exitWith {};
    while {true} do {
        sleep SITE_TICK;

        private _players = (call BIS_fnc_listPlayers) select { alive _x };
        // Both lists built once for the whole pass, which is the point of the shared thread. A crowd
        // is held up by a player and a garrison by any BLUFOR, so the two answers differ and each
        // occupant says which it wants -- but neither costs a spatial query until somebody is
        // actually within reach of the site being asked about.
        private _west = (allUnits select { side _x == WEST }) apply { getPosATL _x };
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
                    // The cheap list gates the expensive helper rather than answering in its
                    // place: fnc_duws_bluforNear still decides every arrival, so zones and towns go
                    // on deciding it the same way. What the gate removes is a spatial query per
                    // site per pass across a map that is nearly always empty of anyone.
                    // Fewer AI hold a site than raise one. That hysteresis stops a zone flickering
                    // off around the edges of the force that just took it.
                    private _min = if (_o get "awake") then {
                        _o getOrDefault ["minAIHold", _o get "minAI"]
                    } else { _o get "minAI" };
                    if ((_west findIf { _x distance _pos < _ring }) >= 0) then {
                        [_pos, _ring, _min] call fnc_duws_bluforNear
                    } else { false }
                } else {
                    [_players, _pos, _ring, _o getOrDefault ["airRing", 0]] call fnc_site_nearOrAir
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

        // Logged rather than assumed. This is the figure that decides whether the shape still holds:
        // a pass approaching a frame means per-site work has crept back inline.
        if (duws_log_level >= 4) then {
            ["DEBUG", "STREAM", format ["site pass: %1 sites in %2 ms",
                count DUWS_sites, round ((diag_tickTime - _t0) * 1000)]] call fnc_log;
        };
    };
};
