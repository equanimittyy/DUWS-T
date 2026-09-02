// Locality: server -- registered once for all towns by server/civilian/fnc_civ_init_Tomata.sqf.
// Owns every town's OPFOR garrison: raise one when BLUFOR arrive at an enemy-held town, reinforce as the
// commander buys, stream it out once empty long enough, settle up when cleared. The clock is
// fnc_site_poller's; what stays here is the part a garrison does not share with a crowd or zone -- the
// reputation band, the commander's purchases, the clear. The raise is dispatched to a per-town worker (it
// confirms over 5 s then waits up to a minute for men to appear), since the poller must not stall on one.
if (!isServer) exitWith {};

// RAVAGE and WBK register no town reputation, so no town ever enters the OPFOR band and this
// thread would spin for the campaign doing nothing.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _count = count _locations;
if (_count == 0) exitWith {};
private _radii = missionNamespace getVariable ["civ_radii", []];
private _centres = _locations apply { getPos _x };

// The band the map markers, the OPFOR AP income and the disguise gate all read as ownership, and
// the whole reputation input to a garrison. Crossing it makes the town OPFOR ground at tier I and
// leaving it discharges the town; nothing deeper in the negative buys the enemy anything further.
// Tiers II to IV are the OPFOR commander's to purchase, so a town the player has merely ruined is
// not automatically a hard one -- the enemy has to have spent on it.
#define OPFOR_BAND -10

// What one cleared garrison is worth against the town's debt. Deliberately a step rather than the
// whole balance: see the clear branch below.
#define CLEAR_REP 5

// The garrison streams on the "town_gar" profile in DUWS_streamProfiles -- the zone's figures, not the
// crowd's. Its grace, 120, serves the same purpose as the zone streaming grace and runs roughly its
// length: a player who steps outside the radius to flank has not left, and tearing the garrison down
// and rebuilding it around them when they step back is both a visible pop and a free reset of
// everything they had ground down. Its buffer, 400, is the zone gate's figure and not the crowd's 200:
// a garrison is expensive enough to want the longer warning, and the gate and tick below are written
// against the same ring.

// Where a raise files its result for the poll to adopt. Unset while the worker is in flight, [] if
// it gave up, otherwise the garrison it stood up.
#define RAISE_SLOT(I) format ["DUWS_townRaise_%1", I]

// Spawned per raise. Nothing from this scope reaches it -- spawn breaks the scope chain -- so it
// takes everything it needs as parameters and hands its result back through the mission namespace.
private _fnc_raise = {
    params ["_i", "_centre", "_radius", "_tier"];
    private _key = [_i] call fnc_town_site_key;

    // Presence is decided the way zones decide it: a five-second re-test after first contact, so
    // grazing the perimeter does not commit a garrison for someone already leaving.
    sleep 5;
    if !([_centre, _radius + ((DUWS_streamProfiles get "town_gar") select 0)] call fnc_duws_bluforNear) exitWith {
        missionNamespace setVariable [RAISE_SLOT(_i), []];
    };

    // Reserve depth, the zone's model: the filtered x1 town tier, thinned to garrison_density, stands up
    // as the garrison; the surplus (the patrols density held back, plus the mult-1 copies) waits as the
    // pool, less whatever the loss ledger says the town has lost across its visits. Filtered before the
    // derivation, so a token the side cannot field is not counted into full and later chased by the
    // refill. Density defers force to the pool rather than removing it; attrition is the ledger.
    private _x1 = [DUWS_townSpawnTiers select (_tier - 1)] call DUWS_fnc_spawnFilter;
    private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
    private _stand = [_x1] call DUWS_fnc_zoneDensityStand;
    ([_key, _x1, _mult, _stand] call DUWS_fnc_garrisonDerive) params ["_garrison", "_pool"];
    missionNamespace setVariable [format ["DUWS_zoneCeiling_%1", _key], count _stand];
    private _grps = [_garrison, _centre, _radius] call DUWS_fnc_raiseGarrison;
    private _men = [_grps] call fnc_site_men_of;

    // OPFOR actually standing inside the town: the confirmation that the raise placed men before the
    // tick adopts it. A spawner that failed to find a safe position leaves the town holding the player
    // and nobody else, and a garrison nobody can field is not one to roster.
    private _fnc_opforPresent = {
        ({side _x == EAST} count (_centre nearEntities [["CAManBase"], _radius])) > 0
    };

    // Adopted only once the garrison is standing. Each spawner resolves a safe position before it places
    // anything, and one that fails would file a garrison of nobody; the tick would then roster an empty
    // town and read it, on the next capture check, as already beaten. So the raise waits up to a minute
    // for men to appear and files nothing if none do.
    private _deadline = diag_tickTime + 60;
    waitUntil { sleep 2; (call _fnc_opforPresent) || {diag_tickTime > _deadline} };
    if !(call _fnc_opforPresent) exitWith {
        // Left un-garrisoned rather than credited: the band is still the condition, so a later
        // cycle tries again. Whatever the spawners did place is deleted rather than abandoned, or
        // every retry would silt the map up with another tier's worth of units nothing counts.
        // Nothing landed inside the town radius -- that is the condition being handled -- so there
        // is nobody there to watch it go.
        { deleteVehicle _x } forEach _men;
        missionNamespace setVariable [RAISE_SLOT(_i), []];
        ["WARN", "CIV", format ["Garrison tier %1 at town %2 placed no OPFOR within %3 m in 60 s; not adopted",
            _tier, _i, _radius]] call fnc_log;
    };

    // Filed for the tick to adopt: the groups it raised (the tick rosters them, hangs the killed watch
    // and marks the site live) and the tier they were raised at. No SEIZED trigger any more -- a town is
    // cleared on the shared garrisonBeaten break test now, evaluated on the poller tick, not by an engine
    // detector, so a town has to be beaten rather than merely emptied.
    missionNamespace setVariable [RAISE_SLOT(_i), [_grps, _tier]];
};

// One record per town in the shared site store (the garrison is an occupant of the same site as the
// crowd, so both are reached the same way). Keyed, not parallel arrays -- eleven same-indexed fields are
// one transposition from a town reinforcing against another's composition.
// awaitVacate is held until the town has been empty of BLUFOR once since a hold armed, so a player who
// cleared it and stayed is not read as freshly arrived; it starts latched so a band-seeded town does not
// raise on sight. emptySince is the diag_tickTime the town went empty (-1 while occupied); the garrison
// streams out on it, so a step outside the radius does not tear it down. tier is the deployed tier,
// distinct from the owned tier the band and commander set; the rest of the garrison state is shared
// (fnc_garrison_strength_init), keyed the same, so a town wears down by a zone's rules.
private _towns = [];
for "_i" from 0 to (_count - 1) do {
    private _key = [_i] call fnc_town_site_key;
    [_key, _centres select _i, _radii param [_i, 500]] call fnc_site_register;
    _towns pushBack ([_key, "garrison", EAST, "town_gar"] call fnc_site_occupant_register_profile);
};
// The town garrison's own cycle, run for it by fnc_site_poller once every pass. Presence, the empty
// clock and the vacate latch arrive already answered; what is left is everything a garrison responds
// to that a crowd does not -- the reputation band, the commander's purchases, and the clear.
//
// It stays cheap on purpose. The poller services every site on one thread against a ~3 ms frame
// budget, so the one expensive act here -- raising men -- is dispatched to a worker and adopted on a
// later pass, exactly as it was when this had a thread of its own.
//
// Each guarded block below exits the whole tick rather than falling through to the next: they are
// mutually exclusive states of one garrison, and the reinforcement test in particular must never see
// a town that is mid-raise or has just streamed out.
private _fnc_tick = {
    params ["_key", "_t", "_here", "_now"];
    private _i = _t get "townIndex";

    private _site = [_key] call fnc_site_at;
    private _centre = _site get "pos";
    private _radius = _site get "radius";

    private _rep = [_i] call fnc_civ_repAt;
    private _tier = [_i] call fnc_town_garrison_tierAt;

    // The gate, and the only place reputation writes a tier. Seeded whether or not anyone is
    // near: a town is OPFOR ground from the moment it crosses the band, which is what lets the
    // commander buy it up while the player is on the other side of the map. Only the men wait
    // for an arrival.
    if (_rep <= OPFOR_BAND && _tier == 0) then {
        [_i, 1, "reputation band"] call fnc_town_garrison_setTier;
        _tier = 1;
        // Re-armed on every crossing, so a town taken, cleared and taken again is held each
        // time. The latch goes with it: the player who spent the reputation is standing in the
        // town, so the hold lapsing is not on its own permission to spawn around them.
        // Logged once here rather than on each deferred cycle -- sixty lines a town saying the
        // same thing is not a readable log, and this one carries the figure a tester needs.
        private _held = [_i, "MOBILISING"] call fnc_town_garrison_setHold;
        _t set ["awaitVacate", true];
        ["INFO", "CIV", format ["Town %1 taken at rep %2; first garrison held for %3 s and until the town is left",
            _i, _rep, _held]] call fnc_log;
    };
    // Out of the band by aid or heals rather than by a fight. The band is the condition, so
    // whatever the commander had bought here goes with it -- there is no town left to hold.
    if (_rep > OPFOR_BAND && _tier > 0) then {
        [_i, 0, "left the OPFOR band"] call fnc_town_garrison_setTier;
        _tier = 0;
        // The claim is gone, so the hold goes with it. A town the player has worked back to
        // neutral is neutral, not regrouping -- and leaving the hold armed would also refuse
        // the tier raise if they ruined the same town again inside the window.
        [_i] call fnc_town_garrison_clearHold;
    };

    // Presence, the empty clock and the vacate latch are the poller's: the arrival test, the
    // latch and the streaming teardown all have to mean the same thing by "somebody is here",
    // and separate calls could disagree across the seconds between them. This asks once.

    // A raise in flight owns this town until it reports. Nothing below may run against a
    // garrison that is halfway through being placed: the reinforcement test would read the
    // still-empty roster as owing the whole composition and raise it a second time.
    if (_t get "raising") exitWith {
        private _res = missionNamespace getVariable [RAISE_SLOT(_i), nil];
        if (isNil "_res") exitWith {};
        _t set ["raising", false];
        missionNamespace setVariable [RAISE_SLOT(_i), nil];
        if !(_res isEqualTo []) then {
            _res params ["_gotGrps", "_gotTier"];
            private _roster = [_key] call fnc_site_roster;
            { _roster append (units _x) } forEach _gotGrps;
            // The garrison is real: mark the site live -- which also enlists it in the reserve pass -- and
            // hang the killed watch, so the town reinforces in hunt waves and records each wiped group's
            // token into the ledger, exactly as a zone does. Losses live in the ledger from here on.
            [_key, _gotGrps] call DUWS_fnc_garrisonReserveWatch;
            [_key, true] call DUWS_fnc_garrisonSetLive;
            _t set ["tier", _gotTier];
            _t set ["awake", true];
            ["INFO", "CIV", format ["Garrison tier %1 spawned at town %2 (rep %3), %4 men",
                _gotTier, _i, _rep, [_key] call fnc_site_alive]] call fnc_log;
        };
    };

    // One hold of either kind, plus the latch. Both clocks answer the same question -- may this
    // town raise men yet -- so they are one piece of state read one way, and the latch is what
    // stops either of them expiring into a spawn around a player who never left.
    if !(_t get "awake") exitWith {
        if (_tier > 0
            && {!(_t get "awaitVacate")}
            && {([_i] call fnc_town_garrison_holdAt) <= 0}
            && {_here}) then {
            _t set ["raising", true];
            missionNamespace setVariable [RAISE_SLOT(_i), nil];
            [_i, _centre, _radius, _tier] spawn (missionNamespace getVariable "DUWS_town_raise");
        };
    };

    // Streamed out once the town has been empty for the town_gar grace, so a town costs what a zone
    // costs: a garrison left standing for the rest of the campaign wherever the player had ever been
    // would leave live men in every town on the map over a long session.
    //
    // What it took is recorded first, against the strength the town will come back at. Without
    // that, streaming would hand back every casualty: grind a garrison to one man, walk away,
    // and the town rebuilds whole. Falls only -- the setter floors it and this never raises it
    // -- so damage accumulates across visits the way a zone's does.
    if (!_here && {(_t get "emptySince") >= 0}
        && {diag_tickTime > (_t get "emptySince") + ((DUWS_streamProfiles get "town_gar") select 1)}) exitWith {
        private _left = [_key] call fnc_site_alive;
        // Losses were recorded live as groups fell, and the survivors of groups that were not wiped come
        // back whole -- so the teardown records nothing. It marks the town no longer live (which also
        // deregisters it from the reserve pass), clears its per-session pool, and collects the men, on the
        // same rules a zone streams out by. The ledger persists, so the town redeploys at what it was worn
        // to. The vehicle half of the collection matters: a town tier fields a car and an APC, and
        // deleting only the crew left both standing in an emptied town for the litter sweep.
        [_key, false] call DUWS_fnc_garrisonSetLive;
        [_key] call DUWS_fnc_garrisonReserveClear;
        [_key] call fnc_site_collect;
        ["INFO", "CIV", format ["Town %1 garrison streamed out holding %2 men; redeploys at %3 strength",
            _i, _left, [_i] call fnc_town_garrison_strengthAt]] call fnc_log;
        _t set ["awake", false];
        // Deployed tier back to nothing standing; the owned tier (reputation/commander) is untouched, so
        // the next visit raises it whole again. The reinforcement test below must not read a live deployed
        // tier against an emptied town and re-derive, which is why this exits the tick.
        _t set ["tier", 0];
    };

    // A commander tier buy grows the town's composition. Re-derive its full potential and reserve pool at
    // the new tier -- the same whole-token split the raise uses -- and raise the ceiling; the refill pass
    // then delivers the growth as hunt waves when the town is fought, exactly as a mauled garrison is
    // topped back up. No bespoke reinforcement raise: a town reinforces the way a zone does now, and the
    // strength half of a purchase is fnc_town_garrison_reinforce un-losing tokens back into the pool.
    //
    // INVARIANT: downstream of the hold gate, and must stay there. Only the gated branch above raises the
    // first garrison, so a tier bought while a town is still held cannot reach here -- it raises the owned
    // tier and the first spawn reads it whole once the hold and latch clear. Guarded on awake so a town
    // that has streamed out (deployed tier zeroed above) re-raises whole rather than re-deriving a pool
    // against a garrison that is not standing.
    if (_tier > (_t get "tier") && {_t get "awake"}) then {
        private _x1 = [DUWS_townSpawnTiers select (_tier - 1)] call DUWS_fnc_spawnFilter;
        private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
        private _stand = [_x1] call DUWS_fnc_zoneDensityStand;
        [_key, _x1, _mult, _stand] call DUWS_fnc_garrisonDerive;
        missionNamespace setVariable [format ["DUWS_zoneCeiling_%1", _key], count _stand];
        _t set ["tier", _tier];
        ["INFO", "CIV", format ["Town %1 garrison tier raised to %2; refill brings it up in waves",
            _i, _tier]] call fnc_log;
    };

    // Tier 0 is the town no longer being OPFOR ground -- the band test above zeroes it when aid
    // or heals lift the town out, and the commander may zero it directly. Either way there is
    // nothing left to hold, so the garrison goes with the trigger that armed it: the same
    // collection the stream-out uses, so the vehicles go with their crews here too. This branch can
    // fire with the player standing in the town, and it already took living men out of their sight
    // to get here -- leaving the transport those men were sitting in would be the odd half.
    if (_tier == 0) then {
        [_key, false] call DUWS_fnc_garrisonSetLive;
        [_key] call DUWS_fnc_garrisonReserveClear;
        _t set ["awake", false];
        [_key] call fnc_site_collect;
        // The town is no longer enemy ground: forget its garrison entirely, so if it crosses back into
        // the band it starts fresh rather than redeploying the remains of a garrison the ground no longer
        // holds. Whatever it holds next is a new garrison.
        [_key] call DUWS_fnc_garrisonForget;
        _t set ["tier", 0];
        ["INFO", "CIV", format ["Town %1 left the OPFOR band at rep %2; garrison cleared",
            _i, _rep]] call fnc_log;
    } else {
        // Cleared when its garrison and owed reserves are beaten to a tenth of full potential -- the same
        // break test a zone falls on, owed reserves included, so a town is not finished while its waves
        // are still inbound. What being beaten *does* stays the town's own: a reputation credit, the
        // garrison seeded to a scratch 0.3, and a REGROUPING hold, rather than a change of owner.
        if (_t get "awake" && {[_key] call DUWS_fnc_garrisonBeaten}) then {
            [_key, false] call DUWS_fnc_garrisonSetLive;
            [_key] call DUWS_fnc_garrisonReserveClear;
            [_key] call fnc_site_roster_clear;
            _t set ["awake", false];
            _t set ["tier", 0];
            // Clearing destroys the purchase but not the ownership. The tier files back down to I rather
            // than to 0: the town is still enemy ground, and it is the commander's spending that was
            // beaten, not the enemy's claim. No refund either -- a player clearing towns would otherwise
            // hand the enemy its AP back and it would never climb.
            [_i, 1, "garrison cleared"] call fnc_town_garrison_setTier;
            // An instalment, not absolution. Discharging the whole debt let a player ruin a town to -20
            // and walk away square on one fight. A clear is worth a fixed step back toward neutral, so a
            // town driven to the floor takes four of them. Self-limiting: only a town at or below the band
            // can hold a garrison to clear, so it can never turn a town friendly by force.
            [_i, CLEAR_REP, "garrison_cleared"] call fnc_town_rep_adjust;
            // Seeded to a scratch 0.3 survival -- a thin garrison with no reserve depth, the seed spending
            // the pool copies first -- and left there. Nothing restores it but a paid reinforcement, so
            // what comes back is a shell: the lasting half of what clearing a town buys, against the
            // reputation step which is only an instalment.
            [_key, 0.3] call DUWS_fnc_garrisonSeed;
            // Read by two others: fnc_town_garrison_setTier refuses a purchase through it, so the commander
            // cannot buy a beaten town up while nobody looks, and the map readout prints it regrouping.
            [_i, "REGROUPING"] call fnc_town_garrison_setHold;
            // The player is standing in the town they just cleared. Nothing may spawn here until they have
            // left once, or the garrison the hold expires into would appear around them.
            _t set ["awaitVacate", true];
            ["INFO", "CIV", format ["Town %1 cleared at tier %2; rep %3 + %4, garrison seeded to 0.3 and regrouping",
                _i, _tier, _rep, CLEAR_REP]] call fnc_log;
        };
    };
};

// Reached through the mission namespace because the hooks run from the poller's scope, not this one.
missionNamespace setVariable ["DUWS_town_raise", _fnc_raise];

{
    private _key = [_forEachIndex] call fnc_town_site_key;
    _x set ["townIndex", _forEachIndex];
    [_key, "garrison", createHashMapFromArray [["tick", _fnc_tick]]] call fnc_site_hooks_set;
} forEach _towns;

["INFO", "CIV", format ["%1 town garrisons registered with the site poller", _count]] call fnc_log;
