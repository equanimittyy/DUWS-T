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

// Raises an explicit token list and hands back what it placed. One driver seeds a garrison from a
// tier's whole composition and reinforces a standing one from the difference, so a tier bought
// mid-fight cannot raise something the town already fields.
// The position and radius are passed in rather than read from the enclosing scope: a spawned block
// sees no locals from where it was written, and this one is called for its return value anyway --
// the roster is what lets the garrison be counted and ordered out.
//
// DUWS_fnc_zoneSpawnOne comes from fnc_zone_spawn_sizes, which is ordered ahead of this by zone
// build-out: fnc_civ_init_Tomata waits on every zone being built before it starts these threads,
// and no zone can be built before the table that spawns its garrison exists.
private _fnc_spawnList = {
    params ["_tokens", "_pos", "_rad"];
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
// waits for the garrison to catch up, and after a spawn that placed nothing. The list is held beside
// the number because reinforcement is the difference between two compositions, not between two tiers
// -- a table retuned mid-campaign would otherwise have a standing garrison reinforced from a row it
// was never raised against.
private _deployed = 0;
// The strength the standing garrison was raised at. Held beside the tier because the two are
// separate purchases: a reinforcement moves this and not the tier, and an upgrade the reverse.
private _deployedStrength = 0;
private _deployedList = [];
// Set whenever a hold is armed, and held until the town has been empty of BLUFOR once since. The
// hold expiring is not enough on its own: a player who took or cleared the town and stayed in it
// is still standing there when the clock lapses, and the arrival test would read them as having
// just walked up. Waiting for one empty cycle is what makes leaving and coming back the only way
// to meet the garrison, whichever hold put it off.
//
// Starts latched for the same reason at the other end: a town seeded into the band at campaign
// start raises its garrison on sight, and the arrival test cannot tell somebody walking up from
// somebody already standing in it. The first cycle clears this for any town nobody is near.
private _awaitVacate = true;
// diag_tickTime from which the town has been empty, or -1 while somebody is in it. The garrison
// streams out on this, so a step outside the radius does not tear it down and walk it back.
private _emptySince = -1;

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

// What one cleared garrison is worth against the town's debt. Deliberately a step rather than the
// whole balance: see the clear branch below.
#define CLEAR_REP 5

// How long the town has to stay empty before its garrison streams out. The same purpose as the
// zone streaming grace and roughly its length: a player who steps outside the radius to flank has
// not left, and tearing the garrison down and rebuilding it around them when they step back is both
// a visible pop and a free reset of everything they had ground down.
#define DESPAWN_GRACE 120

while {true} do {
    sleep 30;

    private _rep = [_townIndex] call fnc_civ_repAt;
    private _tier = [_townIndex] call fnc_town_garrison_tierAt;
    // Read once per cycle beside the tier, because both branches below need it and they must agree:
    // the spawn thins its composition by this, and the reinforcement test compares it against what
    // the standing garrison was raised at.
    private _strength = [_townIndex] call fnc_town_garrison_strengthAt;

    // The gate, and the only place reputation writes a tier. Seeded whether or not anyone is near:
    // a town is OPFOR ground from the moment it crosses the band, which is what lets the commander
    // buy it up while the player is on the other side of the map. Only the men wait for an arrival.
    if (_rep <= OPFOR_BAND && _tier == 0) then {
        [_townIndex, 1, "reputation band"] call fnc_town_garrison_setTier;
        _tier = 1;
        // Re-armed on every crossing, so a town taken, cleared and taken again is held each time.
        // The latch goes with it: the player who spent the reputation is standing in the town, so
        // the hold lapsing is not on its own permission to spawn around them.
        // Logged once here rather than on each deferred cycle -- sixty lines a town saying the same
        // thing is not a readable log, and this one carries the figure a tester needs.
        private _held = [_townIndex, "TAKEN"] call fnc_town_garrison_setHold;
        _awaitVacate = true;
        ["INFO", "CIV", format ["Town %1 taken at rep %2; first garrison held for %3 s and until the town is left",
            _townIndex, _rep, _held]] call fnc_log;
    };
    // Out of the band by aid or heals rather than by a fight. The band is the condition, so
    // whatever the commander had bought here goes with it -- there is no town left to hold.
    if (_rep > OPFOR_BAND && _tier > 0) then {
        [_townIndex, 0, "left the OPFOR band"] call fnc_town_garrison_setTier;
        _tier = 0;
        // The claim is gone, so the hold goes with it. A town the player has worked back to neutral
        // is neutral, not regrouping -- and leaving the hold armed would also refuse the tier raise
        // if they ruined the same town again inside the window.
        [_townIndex] call fnc_town_garrison_clearHold;
    };

    // One presence read per cycle, shared by everything below: the arrival test, the vacate latch
    // and the streaming teardown all have to mean the same thing by "somebody is here", and three
    // separate calls could disagree across the seconds between them.
    private _near = [_centre, _radius + 400] call fnc_duws_bluforNear;
    if (_near) then { _emptySince = -1 } else {
        if (_emptySince < 0) then { _emptySince = diag_tickTime };
        // One empty cycle is all the latch wants. It is not a timer: the point is only that the
        // player left at some stage, not how long for.
        _awaitVacate = false;
    };

    // One hold of either kind, plus the latch. Both clocks answer the same question -- may this town
    // raise men yet -- so they are one piece of state read one way, and the latch is what stops
    // either of them expiring into a spawn around a player who never left.
    if (!_garrisoned) then {
        if (_tier > 0
            && {!_awaitVacate}
            && {([_townIndex] call fnc_town_garrison_holdAt) <= 0}) then {
            // Presence is decided the way zones decide it: a five-second re-test after first
            // contact, so grazing the perimeter does not commit a garrison for someone already
            // leaving. Waiting for arrival at all is what keeps the map free of standing units.
            if (_near) then {
                sleep 5;
                if ([_centre, _radius + 400] call fnc_duws_bluforNear) then {
                    // Thinned by what the town has left, the way a zone's band is. A town beaten
                    // once fields a fraction of its tier from then on, so the composition is the
                    // ceiling rather than the promise.
                    private _want = [DUWS_townSpawnTiers select (_tier - 1), _strength] call fnc_zone_thin;
                    _roster = [_want, _centre, _radius] call _fnc_spawnList;
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
                        _deployedList = _want;
                        _deployedStrength = _strength;
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
        // Bought while the garrison stands, so only what the new composition has and the standing one
        // does not is raised -- reinforcement arrives beside the survivors rather than as a second
        // garrison beside the first. Counting duplicates is the whole point: a tier that goes from
        // one team to two owes one team, not two.
        //
        // INVARIANT: this branch is downstream of the hold gate and must stay there. Only the gated
        // branch above sets _garrisoned, so a tier bought while a town is held cannot reach here --
        // it raises the stored tier and the first spawn reads it whole once the hold and the latch
        // are both clear. A second spawn path that set _garrisoned without that gate would silently
        // let an upgrade land on a town captured seconds ago, which is what the TAKEN hold exists
        // to prevent.
        // Refused twice over, and the tier stays owed either way -- it lands on a later cycle rather
        // than being lost, the same way a hold defers a first garrison.
        //
        // Streamed out once the town has been empty for DESPAWN_GRACE. Town garrisons used to stand for
        // the rest of the campaign wherever the player had ever been, so a long session left live
        // men in every town on the map; this makes a town cost what a zone costs.
        //
        // What it took is recorded first, against the strength the town will come back at. Without
        // that, streaming would hand back every casualty: grind a garrison to one man, walk away,
        // and the town rebuilds whole. Falls only -- the setter floors it and this never raises it
        // -- so damage accumulates across visits the way a zone's does.
        //
        // Deletion rather than fnc_opfor_retreat: nobody is within the radius plus 400 by
        // definition here, so there is no one to watch men vanish, and walking them out would be a
        // withdrawal the player never sees and the engine pays for.
        if (!_near && {_emptySince >= 0} && {diag_tickTime > _emptySince + DESPAWN_GRACE}) then {
            private _left = [_roster] call _fnc_rosterAlive;
            if (_baseline > 0) then {
                private _was = [_townIndex] call fnc_town_garrison_strengthAt;
                [_townIndex, (_left / _baseline) min _was] call fnc_town_garrison_setStrength;
            };
            // The trigger goes with the men. Left armed over an empty town it would read WEST
            // SEIZED the moment a player walked back into ground the garrison had streamed out of,
            // and pay them a clear for a fight that never happened.
            deleteVehicle _trg;
            // The group goes with its men. Most of these spawners set deleteGroupWhenEmpty, but not
            // all of them do, and an empty group left behind on every stream-out of every town is a
            // leak that only shows up as a slow drift over a long campaign.
            { { deleteVehicle _x } forEach units _x; deleteGroup _x } forEach _roster;
            ["INFO", "CIV", format ["Town %1 garrison streamed out holding %2 of %3; returns at %4 strength",
                _townIndex, _left, _baseline, [_townIndex] call fnc_town_garrison_strengthAt]] call fnc_log;
            _garrisoned = false;
            _retreating = false;
            _roster = [];
            _baseline = 0;
            _deployed = 0;
            _deployedStrength = 0;
            _deployedList = [];
            // Nothing below this describes a town that no longer has a garrison, and the
            // reinforcement test in particular would read the emptied _deployed against a live tier
            // and raise the whole composition again -- streaming the garrison out and straight back
            // in, on the one cycle nobody is there to see either.
            continue;
        };

        // While the remnant is withdrawing: units walking in behind it would hold the trigger area
        // open, and a town whose garrison keeps being topped up mid-withdrawal never reads as
        // cleared at all.
        //
        // While BLUFOR are near: reinforcement that materialises around the player mid-fight is the
        // pop-in the holds above exist to prevent, and worse here -- the player is in contact, so men
        // appearing behind them reads as the mission cheating rather than as the enemy committing.
        // Buying and arriving are separate acts: the commander may raise a contested town's tier at
        // any time, and the men walk in once nobody is watching. The same radius the arrival test
        // uses, so "present" means one thing in this file.
        // Either purchase owes men, and both arrive the same way. An upgrade widens the composition,
        // a reinforcement raises the fraction of it that stands; what the town should be fielding is
        // the two together, and the difference against what it already has is what gets raised.
        //
        // Tested against the stored pair rather than by recomputing the wanted list each cycle and
        // diffing that: fnc_zone_thin drops entries at random, so the same tier and strength yield a
        // different list every call, and an unchanged town would appear to owe men forever.
        if ((_tier > _deployed || _strength > _deployedStrength) && !_retreating && {!_near}) then {
            private _want = [DUWS_townSpawnTiers select (_tier - 1), _strength] call fnc_zone_thin;
            private _added = [[_deployedList, _want] call DUWS_fnc_spawnDiff, _centre, _radius] call _fnc_spawnList;
            _roster append _added;
            // Added to the baseline rather than re-measured from the roster. A garrison ground down
            // to three men and then reinforced by six is nine men against a baseline that still
            // counts the dead; re-basing on the alive count would refund every casualty the player
            // has already paid for and reset the withdrawal threshold with it.
            _baseline = _baseline + ([_added] call _fnc_rosterAlive);
            _deployed = _tier;
            _deployedList = _want;
            _deployedStrength = _strength;
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
            _deployedStrength = 0;
            _deployedList = [];
            ["INFO", "CIV", format ["Town %1 left the OPFOR band at rep %2; garrison withdrawing", _townIndex, _rep]] call fnc_log;
        } else {
            if (!isNull _trg && {triggerActivated _trg}) then {
                deleteVehicle _trg;
                _garrisoned = false;
                _roster = [];
                _baseline = 0;
                _deployed = 0;
                _deployedStrength = 0;
                _deployedList = [];
                // Clearing destroys the purchase but not the ownership. The tier files back down to
                // I rather than to 0: the town is still enemy ground, and it is the commander's
                // spending that was beaten, not the enemy's claim. No refund either -- with one, a
                // player clearing towns would hand the enemy its AP back and the enemy would never
                // climb.
                [_townIndex, 1, "garrison cleared"] call fnc_town_garrison_setTier;
                // An instalment, not absolution. Discharging the whole debt let a player ruin a town
                // to -20 and walk away square on one fight, which made the reputation the garrison
                // was supposed to be the price of effectively free. A clear is worth a fixed step
                // back toward neutral, so a town driven to the floor takes four of them.
                // Self-limiting: only a town at or below the band can hold a garrison to clear, so
                // the most this can ever reach is one step above the band and it can never turn a
                // town friendly by force.
                [_townIndex, CLEAR_REP, "garrison_cleared"] call fnc_town_rep_adjust;
                // Beaten to the floor and left there. Nothing restores it, so what comes back is a
                // shell for the rest of the campaign -- the lasting half of what clearing a town
                // buys, against the reputation step which is only an instalment.
                [_townIndex, 0.3] call fnc_town_garrison_setStrength;
                // Left alone afterwards, and the hold is per-town state rather than a local because
                // two other things read it: fnc_town_garrison_setTier refuses a purchase through it,
                // so the commander cannot buy a beaten town up to IV while nobody is looking, and
                // the map readout prints the town as regrouping.
                [_townIndex, "REGROUP"] call fnc_town_garrison_setHold;
                // The player is standing in the town they just cleared. Nothing may spawn here
                // until they have left once, or the garrison the hold expires into would appear
                // around them.
                _awaitVacate = true;
                ["INFO", "CIV", format ["Town %1 cleared at tier %2; rep %3 + %4, garrison broken to 0.3 and regrouping",
                    _townIndex, _tier, _rep, CLEAR_REP]] call fnc_log;
            };
        };
    };
};
