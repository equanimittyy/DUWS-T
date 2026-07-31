// Locality: server -- spawned per town from server/misc/fnc_civ_init_Tomata.sqf.
if (!isServer) exitWith {};

params ["_townIndex"];

// RAVAGE and WBK register no town reputation, so no town ever enters the OPFOR band and this
// thread would spin for the campaign doing nothing.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
if (_townIndex >= count _locations) exitWith {};

private _centre = getPos (_locations select _townIndex);
private _radius = (missionNamespace getVariable ["civ_radii", []]) param [_townIndex, 300];

// Raises the DUWS_townSpawnTiers rows above _from up to and including _to, and hands back what they
// placed. One driver seeds a garrison from nothing (_from 0) and reinforces a standing one, so a
// tier bought mid-fight cannot raise a row the town already fields.
// The position and radius are passed in rather than read from the enclosing scope: a spawned block
// sees no locals from where it was written, and this one is called for its return value anyway --
// the roster is what lets the garrison be counted and ordered out.
//
// DUWS_fnc_zoneSpawnOne comes from fnc_zone_spawn_sizes, which is ordered ahead of this by zone
// build-out: fnc_civ_init_Tomata waits on every zone being built before it starts these threads,
// and no zone can be built before the table that spawns its garrison exists.
private _fnc_spawnRows = {
    params ["_from", "_to", "_pos", "_rad"];
    private _tokens = [];
    for "_t" from (_from + 1) to _to do { _tokens append (DUWS_townSpawnTiers select (_t - 1)) };

    private _grps = [];
    {
        private _grp = if (_x == "buildings") then {
            // The zone benchmark tier IV climbs to -- fnc_createopfortified holds up to eight
            // buildings at three men each. Flagged and looted inside, unlike everything below:
            // rolling the search flag over these men a second time would quietly raise the rate
            // a town garrison pays out at above a zone's.
            [_pos, _rad, 8, 3] call fnc_garrisonBuildings
        } else {
            private _g = [_x, _pos, _rad] call DUWS_fnc_zoneSpawnOne;
            // A town garrison is a garrison: it pays the same search rate a zone's does. The
            // spawners it shares with the zone band carry the loot pass and not this one, so it
            // has to be asked for.
            if (!isNull _g) then { [_g, "garrison"] call fnc_search_flag_group };
            _g
        };
        if (!isNull _grp) then { _grps pushBack _grp };
        // Staggered, not batched: each of these raises a group, and firing a whole tier in one
        // frame is what the per-call sleep this replaces existed to avoid. None after the last.
        if (_forEachIndex < (count _tokens) - 1) then { sleep 5 };
    } forEach _tokens;
    _grps
};

private _fnc_rosterAlive = {
    params ["_grps"];
    private _n = 0;
    { _n = _n + ({alive _x} count units _x) } forEach _grps;
    _n
};

// SEIZED is the engine's own "this side present, the opposing side absent" test, and it decides the
// clear rather than the roster below does: a garrison that withdrew has cleared the town as surely
// as one that was wiped, and only the trigger sees both. The roster is read for strength alone.
// The interruptable timeout restarts if OPFOR walk back in, so the town has to be held clear rather
// than sprinted through.
// Whether CIVILIAN-side units block SEIZED is unconfirmed; if they do, this needs a plain
// condition trigger counting hostile units in thisList instead.
private _fnc_makeClearTrigger = {
    private _trg = createTrigger ["EmptyDetector", _centre, false];
    _trg setTriggerArea [_radius, _radius, 0, false];
    _trg setTriggerActivation ["WEST SEIZED", "PRESENT", true];
    _trg setTriggerTimeout [30, 40, 50, true];
    _trg setTriggerStatements ["this", "", ""];
    _trg
};

// OPFOR standing inside the trigger's own area, which is what makes the town clearable. SEIZED is
// satisfied by an empty town as readily as by a fought-out one, so nothing else can tell the two
// apart.
private _fnc_opforPresent = {
    ({side _x == EAST} count (_centre nearEntities [["CAManBase"], _radius])) > 0
};

private _garrisoned = false;
private _trg = objNull;
private _roster = [];
private _baseline = 0;
private _retreating = false;
// What is standing in the town, against the tier the town owes. The two differ while a purchase
// waits for the garrison to catch up, and after a spawn that placed nothing.
private _deployed = 0;
// When this town was taken, or -1 for one that is not under the capture grace. Towns seeded into
// the band at campaign start hold -1 and garrison on sight: they are pre-existing enemy ground
// rather than something the player has just turned.
private _capturedAt = -1;

// A garrison broken this far is not going to hold the town, and standing the remnant in it until
// the last man dies is what makes clearing a town a sweep rather than a fight. Counted against the
// strength the town was actually given, so a tier IV garrison may lose more men than a tier I has.
#define BREAK_FRACTION 0.2

// The band the map markers, the OPFOR AP income and the disguise gate all read as ownership, and
// the whole reputation input to a garrison. Crossing it makes the town OPFOR ground at tier I and
// leaving it discharges the town; nothing deeper in the negative buys the enemy anything further.
// Tiers II to IV are the OPFOR commander's to purchase, so a town the player has merely ruined is
// not automatically a hard one -- the enemy has to have spent on it.
#define OPFOR_BAND -10

// A town's first garrison must not appear on top of the player who has just pushed it into the
// band. They are standing in it -- that is how the reputation got spent -- and a tier materialising
// around them is the same pop-in the zone spawners scatter their men on a ring to avoid. The enemy
// is moving a garrison in and that takes time; the town is theirs on paper from the moment it
// crosses, which is what the tier records.
// Wall-clock, so the mission's time multiplier cannot shorten it, and one-shot: it arms on the
// crossing and is spent, so leaving a garrisoned town and coming back re-spawns at once.
// diag_tickTime counts from process start and a savegame does not restore it. Accepted here rather
// than worked around -- the worst a reload inside the window does is let one garrison in early, and
// nothing outside this thread reads the stamp.
#define CAPTURE_GRACE 1800

while {true} do {
    sleep 30;

    private _rep = [_townIndex] call fnc_civ_repAt;
    private _tier = [_townIndex] call fnc_town_garrison_tierAt;

    // The gate, and the only place reputation writes a tier. Seeded whether or not anyone is near:
    // a town is OPFOR ground from the moment it crosses the band, which is what lets the commander
    // buy it up while the player is on the other side of the map. Only the men wait for an arrival.
    if (_rep <= OPFOR_BAND && _tier == 0) then {
        [_townIndex, 1, "reputation band"] call fnc_town_garrison_setTier;
        _tier = 1;
        // Re-armed on every crossing, so a town taken, cleared and taken again gets the grace each
        // time. Logged once here rather than on each deferred cycle: sixty lines a town saying the
        // same thing is not a readable log, and this one carries the figure a tester needs.
        _capturedAt = diag_tickTime;
        ["INFO", "CIV", format ["Town %1 taken at rep %2; first garrison held for %3 s", _townIndex, _rep, CAPTURE_GRACE]] call fnc_log;
    };
    // Out of the band by aid or heals rather than by a fight. The band is the condition, so
    // whatever the commander had bought here goes with it -- there is no town left to hold.
    if (_rep > OPFOR_BAND && _tier > 0) then {
        [_townIndex, 0, "left the OPFOR band"] call fnc_town_garrison_setTier;
        _tier = 0;
    };

    if (!_garrisoned) then {
        if (_tier > 0 && {_capturedAt < 0 || {diag_tickTime > _capturedAt + CAPTURE_GRACE}}) then {
            // Presence is decided the way zones decide it: a five-second re-test after first
            // contact, so grazing the perimeter does not commit a garrison for someone already
            // leaving. Waiting for arrival at all is what keeps the map free of standing units.
            if ([_centre, _radius + 400] call fnc_duws_bluforNear) then {
                sleep 5;
                if ([_centre, _radius + 400] call fnc_duws_bluforNear) then {
                    _roster = [0, _tier, _centre, _radius] call _fnc_spawnRows;
                    // Armed only once the garrison is standing in it. Each spawner resolves a safe
                    // position before it places anything, and one that fails leaves the town
                    // holding the player and nobody else -- which is precisely what WEST SEIZED
                    // reports as cleared. A trigger armed beside the spawn therefore hands the town
                    // its whole reputation debt back for a garrison nobody fought, which reads in
                    // play as reputation climbing out of the negative band on its own from standing
                    // in the town.
                    private _deadline = diag_tickTime + 60;
                    waitUntil { sleep 2; (call _fnc_opforPresent) || {diag_tickTime > _deadline} };
                    if (call _fnc_opforPresent) then {
                        _trg = call _fnc_makeClearTrigger;
                        _garrisoned = true;
                        _retreating = false;
                        _deployed = _tier;
                        _baseline = [_roster] call _fnc_rosterAlive;
                        ["INFO", "CIV", format ["Garrison tier %1 spawned at town %2 (rep %3), %4 men", _tier, _townIndex, _rep, _baseline]] call fnc_log;
                    } else {
                        // Left un-garrisoned rather than credited: the band is still the condition,
                        // so the next pass tries again. Whatever the spawners did place is ordered
                        // out rather than abandoned, or every retry would silt the map up with
                        // another tier's worth of units nothing is counting.
                        [_roster, _centre] spawn fnc_opfor_retreat;
                        _roster = [];
                        ["WARN", "CIV", format ["Garrison tier %1 at town %2 placed no OPFOR within %3 m in 60 s; not armed", _tier, _townIndex, _radius]] call fnc_log;
                    };
                };
            };
        };
    } else {
        // Bought while the garrison stands, so only the rows between what is deployed and what the
        // town now owes are raised -- reinforcement arrives beside the survivors rather than as a
        // second garrison beside the first.
        // Refused while the remnant is withdrawing: units walking in behind it would hold the
        // trigger area open, and a town whose garrison keeps being topped up mid-withdrawal never
        // reads as cleared at all. The tier stays owed and lands on the next spawn instead.
        if (_tier > _deployed && !_retreating) then {
            private _added = [_deployed, _tier, _centre, _radius] call _fnc_spawnRows;
            _roster append _added;
            // Added to the baseline rather than re-measured from the roster. A garrison ground down
            // to three men and then reinforced by six is nine men against a baseline that still
            // counts the dead; re-basing on the alive count would refund every casualty the player
            // has already paid for and reset the withdrawal threshold with it.
            _baseline = _baseline + ([_added] call _fnc_rosterAlive);
            _deployed = _tier;
            ["INFO", "CIV", format ["Town %1 garrison reinforced to tier %2; baseline now %3 men", _townIndex, _tier, _baseline]] call fnc_log;
        };

        // Ordered out on strength rather than left to be finished off. The withdrawal is also what
        // clears the trigger area, so this and the WEST SEIZED test below run in sequence rather
        // than competing: the remnant walks out, and the town reads as cleared once it has.
        private _left = [_roster] call _fnc_rosterAlive;
        if (!_retreating && {_baseline > 0} && {_left > 0} && {_left <= BREAK_FRACTION * _baseline}) then {
            _retreating = true;
            [_roster, _centre] spawn fnc_opfor_retreat;
            ["INFO", "CIV", format ["Town %1 garrison broken at %2 of %3 men; withdrawing", _townIndex, _left, _baseline]] call fnc_log;
        };

        // Tier 0 is the town no longer being OPFOR ground -- the band test above zeroes it when aid
        // or heals lift the town out, and the commander may zero it directly. Either way there is
        // nothing left to hold, and the garrison leaves the way a broken one does.
        if (_tier == 0) then {
            deleteVehicle _trg;
            _garrisoned = false;
            if (!_retreating) then {
                _retreating = true;
                [_roster, _centre] spawn fnc_opfor_retreat;
            };
            _roster = [];
            _baseline = 0;
            _deployed = 0;
            ["INFO", "CIV", format ["Town %1 left the OPFOR band at rep %2; garrison withdrawing", _townIndex, _rep]] call fnc_log;
        } else {
            if (!isNull _trg && {triggerActivated _trg}) then {
                deleteVehicle _trg;
                _garrisoned = false;
                _roster = [];
                _baseline = 0;
                _deployed = 0;
                // Clearing destroys the purchase with the debt. No refund, and the commander must
                // spend again: with a refund a player clearing towns would hand the enemy its AP
                // back and the enemy would never climb, and with a tier that survived clearing,
                // clearing would stop meaning anything.
                [_townIndex, 0, "garrison cleared"] call fnc_town_garrison_setTier;
                // Clearing the garrison discharges the whole debt at once. That is deliberate:
                // the alternative is a town the player can permanently ruin with no route back,
                // which is what passive recovery used to prevent. The garrison is the price.
                [_townIndex, -_rep, "garrison_cleared"] call fnc_town_rep_adjust;
                ["INFO", "CIV", format ["Town %1 cleared at tier %2; reputation reset from %3", _townIndex, _tier, _rep]] call fnc_log;
            };
        };
    };
};
