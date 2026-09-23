// Locality: server -- registered once for all towns by server/civilian/fnc_civ_init_Tomata.sqf.
// Owns each town's garrison for fnc_site_poller, whichever side the reputation bands put the town on: raises on arrival, reinforces on purchase, streams out when empty, settles on clear.
// The raise is dispatched to a per-town worker (5 s confirm, then up to 60 s for men) so the poller thread never stalls on one town.
if (!isServer) exitWith {};

// RAVAGE/WBK register no town reputation, so no town ever crosses the OPFOR band; this thread would otherwise spin doing nothing.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _count = count _locations;
if (_count == 0) exitWith {};
private _radii = missionNamespace getVariable ["civ_radii", []];
private _centres = _locations apply { getPos _x };

// Ownership is the reputation bands (fnc_civ_townOwner). Crossing into the OPFOR band sets tier I; leaving either band discharges the town.
// Tiers II-IV are the commander's purchase, so a merely-ruined town isn't automatically hard -- the enemy has to have spent on it.
// BLUFOR cross into their band with nothing: a friendly town's garrison is bought whole, tier I included.

// Value of one cleared garrison against the town's debt -- deliberately a step, not the whole balance (see clear branch below).
#define CLEAR_REP 10

// Streams on the "town_gar" profile (DUWS_streamProfiles): grace 120 matches the zone's, since stepping outside to flank isn't leaving and rebuilding around a returning player would reset their damage for free.
// Buffer 400 (vs the crowd's 200): a garrison is expensive enough to want the longer warning; the gate and tick below assume this ring.

// Slot a raise files its result in: nil while in flight, [] if it gave up, otherwise the garrison stood up.
#define RAISE_SLOT(I) format ["DUWS_townRaise_%1", I]

// spawn breaks the scope chain, so this takes everything it needs as params and returns via the mission namespace.
private _fnc_raise = {
    params ["_i", "_centre", "_radius", "_tier"];
    private _key = [_i] call fnc_town_site_key;
    private _side = [_key] call DUWS_fnc_garrisonSideOf;
    private _army = [EAST, WEST] select (_side isEqualTo "BLU");

    // Five-second re-test (as zones do), so grazing the perimeter doesn't commit a garrison for someone already leaving.
    // A town BLUFOR hold woke for its attacker as readily as for its owner, so it re-tests for either.
    sleep 5;
    private _reach = _radius + ((DUWS_streamProfiles get "town_gar") select 0);
    private _blu = _side isEqualTo "BLU";
    private _confirmed = [_centre, _reach, 2, _blu] call fnc_duws_bluforNear;
    if (!_confirmed && _blu) then { _confirmed = [_centre, _reach] call fnc_site_hostileNear };
    if (!_confirmed) exitWith {
        missionNamespace setVariable [RAISE_SLOT(_i), []];
    };

    // Zone's reserve model: filtered x1 tier thins to garrison_density on stand, surplus + mult-1 copies wait in the pool, less the loss ledger.
    private _garrison = [_key, [_key, [_tier, _side] call DUWS_fnc_townSpawnList] call DUWS_fnc_garrisonRestand] call DUWS_fnc_garrisonStandFill;
    // Adopted though empty, or a player standing in the town would re-raise it every tick.
    if (_garrison isEqualTo []) exitWith { missionNamespace setVariable [RAISE_SLOT(_i), [[], _tier]] };
    private _grps = [_garrison, _centre, _radius, _side] call DUWS_fnc_raiseGarrison;
    private _men = [_grps] call fnc_site_men_of;

    // Confirms the raise actually placed men before the tick adopts it -- a spawner that fails to find a safe position would otherwise leave nobody there to roster.
    private _fnc_garrisonPresent = {
        ({side _x == _army} count (_centre nearEntities [["CAManBase"], _radius])) > 0
    };

    // Waits up to a minute so a raise isn't adopted empty -- an empty roster would read as already beaten on the next capture check.
    private _deadline = diag_tickTime + 60;
    waitUntil { sleep 2; (call _fnc_garrisonPresent) || {diag_tickTime > _deadline} };
    if !(call _fnc_garrisonPresent) exitWith {
        // Deleted, not abandoned, or every retry would silt the map with units nothing tracks; the band still holds so a later cycle retries the raise.
        { deleteVehicle _x } forEach _men;
        missionNamespace setVariable [RAISE_SLOT(_i), []];
        ["WARN", "CIV", format ["Garrison tier %1 at town %2 placed no %3 within %4 m in 60 s; not adopted",
            _tier, _i, _side, _radius]] call fnc_log;
    };

    // Filed for the tick to adopt: raised groups (rostered, killed-watch hung, site marked live), the tier raised at, and the tokens raised.
    missionNamespace setVariable [RAISE_SLOT(_i), [_grps, _tier, _garrison]];
};

// One record per town, keyed (not parallel arrays) -- eleven same-indexed fields risk a transposition between towns.
// awaitVacate latches until BLUFOR leave once after the town flips or is cleared; emptySince (-1 while occupied) gates the stream-out; tier is the deployed tier, distinct from the owned tier the band/commander set.
private _towns = [];
for "_i" from 0 to (_count - 1) do {
    private _key = [_i] call fnc_town_site_key;
    [_key, _centres select _i, _radii param [_i, 500]] call fnc_site_register;
    private _occ = [_key, "garrison", EAST, "town_gar"] call fnc_site_occupant_register_profile;
    // Once the bands put the town on BLUFOR, the arrival that matters is the attacker's: see fnc_site_poller.
    _occ set ["enemyAware", true];
    _towns pushBack _occ;
};
// Poller runs this per site on one thread against a ~3 ms budget, so the expensive act (raising men) is dispatched to a worker and adopted on a later pass.
// Each block below exits the whole tick -- mutually exclusive garrison states, and the reinforcement test must never see a town mid-raise or freshly streamed out.
private _fnc_tick = {
    params ["_key", "_t", "_here", "_now"];
    private _i = _t get "townIndex";

    private _site = [_key] call fnc_site_at;
    private _centre = _site get "pos";
    private _radius = _site get "radius";

    private _rep = [_i] call fnc_civ_repAt;
    private _tier = [_i] call fnc_town_garrison_tierAt;

    // Presence/empty-clock/vacate-latch are computed once by the poller and passed in, so the arrival test, latch and streaming teardown can't disagree on "somebody is here" a few seconds apart.

    // Not a garrison state, so it ends nothing: a cleared town's survivors are collected while its next garrison raises.
    [_key] call DUWS_fnc_garrisonLeftoverSweep;

    // Raise in flight owns the town until it reports -- otherwise the reinforcement test would read the still-empty roster as owing the whole composition and raise it a second time.
    if (_t get "raising") exitWith {
        private _res = missionNamespace getVariable [RAISE_SLOT(_i), nil];
        if (isNil "_res") exitWith {};
        _t set ["raising", false];
        missionNamespace setVariable [RAISE_SLOT(_i), nil];
        if !(_res isEqualTo []) then {
            _res params ["_gotGrps", "_gotTier", "_gotTokens"];
            private _roster = [_key] call fnc_site_roster;
            { _roster append (units _x) } forEach _gotGrps;
            // Site live also enlists it in the reserve pass; the killed watch reinforces in hunt waves and records each wiped group's token into the ledger, same as a zone. Losses live in the ledger from here on.
            // An empty raise stays off live, so the clear pays only for a garrison that stood; a purchase or an OPCOM defender lands on the next raise.
            if (_gotGrps isNotEqualTo []) then {
                [_key, _gotTokens, _gotGrps] call DUWS_fnc_garrisonRefundUnplaced;
                [_key, _gotGrps] call DUWS_fnc_garrisonReserveWatch;
                [_key, true] call DUWS_fnc_garrisonSetLive;
            };
            _t set ["tier", _gotTier];
            _t set ["awake", true];
            ["INFO", "CIV", format ["Garrison tier %1 spawned at town %2 (rep %3), %4 men",
                _gotTier, _i, _rep, [_key] call fnc_site_alive]] call fnc_log;
        };
    };

    // Hold + latch answer one question (may this town raise yet) as one gate; the latch stops the hold expiring, or a clear, into a spawn around a player who never left.
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

    // Streams out after the town_gar grace, same as a zone -- otherwise every town the player ever visited would leave live men standing for the rest of the campaign.
    if (!_here && {(_t get "emptySince") >= 0}
        && {diag_tickTime > (_t get "emptySince") + ((DUWS_streamProfiles get "town_gar") select 1)}) exitWith {
        private _left = [_key] call fnc_site_alive;
        // Losses were recorded live as groups fell (survivors of unwiped groups come back whole), so the teardown itself records nothing -- the ledger persists so the town redeploys at what it was worn to.
        // Vehicles matter too: a town tier fields a car and an APC, and deleting only the crew would leave both stranded for the litter sweep.
        [_key, false] call DUWS_fnc_garrisonSetLive;
        [_key] call DUWS_fnc_garrisonReserveClear;
        [_key] call fnc_site_collect;
        ["INFO", "CIV", format ["Town %1 garrison streamed out holding %2 men; redeploys at %3 strength",
            _i, _left, [_i] call fnc_town_garrison_strengthAt]] call fnc_log;
        _t set ["awake", false];
        // Deployed tier resets to 0; owned tier (reputation/commander) is untouched so the next visit raises it whole again. exitWith matters: the reinforcement test below must not re-derive against a live deployed tier for an emptied town.
        _t set ["tier", 0];
    };

    // Commander tier buy re-stands the garrison at the new tier; the refill pass delivers the growth as hunt waves, same as topping up a mauled garrison.
    // No bespoke reinforcement raise -- a town reinforces like a zone now; fnc_town_garrison_reinforce handles the strength half by un-losing tokens back into the pool.
    //
    // INVARIANT: must stay downstream of the hold gate above -- a tier bought while held can't reach here; it raises the owned tier, and the first spawn reads it whole once hold/latch clear.
    // Guarded on awake so a streamed-out town (deployed tier zeroed) re-raises whole instead of re-deriving a pool against a garrison that isn't standing.
    if (_tier > (_t get "tier") && {_t get "awake"}) then {
        [_key, [_tier, [_key] call DUWS_fnc_garrisonSideOf] call DUWS_fnc_townSpawnList] call DUWS_fnc_garrisonRestand;
        _t set ["tier", _tier];
        ["INFO", "CIV", format ["Town %1 garrison tier raised to %2; refill brings it up in waves",
            _i, _tier]] call fnc_log;
    };

    // Tier 0 means the town is nobody's ground any more (the band, a commander, or a garrison beaten) -- nothing left to hold, so the garrison goes with the same collection the stream-out uses, vehicles included.
    // Can fire with the player standing in the town; having already taken the men out of sight, leaving their transport behind would be the odd half.
    if (_tier == 0) then {
        [_key, false] call DUWS_fnc_garrisonSetLive;
        [_key] call DUWS_fnc_garrisonReserveClear;
        _t set ["awake", false];
        [_key] call fnc_site_collect;
        // Forgets the garrison entirely so a town that crosses back into the band starts fresh, not redeploying the remains of one the ground no longer holds.
        [_key] call DUWS_fnc_garrisonForget;
        // OPCOM's resting non-combatants go with the garrison they were attached to, as at a captured zone.
        if (!isNil "DUWS_fnc_opcom_siteLost") then { [_key] call DUWS_fnc_opcom_siteLost };
        _t set ["tier", 0];
        ["INFO", "CIV", format ["Town %1 holds no tier at rep %2; garrison cleared", _i, _rep]] call fnc_log;
    };
};

// Runs for whichever side held the town: BLUFOR beating the enemy's garrison, or OPFOR beating the player's.
private _fnc_clear = {
    params ["_i"];
    private _key = [_i] call fnc_town_site_key;
    private _t = [_key, "garrison"] call fnc_site_occupant;
    private _tier = [_i] call fnc_town_garrison_tierAt;
    private _rep = [_i] call fnc_civ_repAt;
    private _owner = [_i] call fnc_town_garrison_ownerAt;
    [_key, false] call DUWS_fnc_garrisonSetLive;
    [_key] call DUWS_fnc_garrisonReserveClear;
    [_key] call DUWS_fnc_garrisonRelease;
    _t set ["awake", false];
    _t set ["tier", 0];
    if (_owner isEqualTo "BLU") then {
        // BLUFOR are left with nothing, not a tier I to rebuild from: they were handed no first tier when they
        // took the town, so a beaten garrison cannot leave them one. Every tier is bought, this one again.
        [_i, 0, "garrison cleared"] call fnc_town_garrison_setTier;
        [_key] call DUWS_fnc_garrisonForget;
    } else {
        // Clearing destroys the purchase, not the ownership -- tier files back to I, not 0: the commander's spending was beaten, not the enemy's claim to the ground.
        // No refund either, or a player clearing towns would hand the enemy its AP back and the OPFOR economy would never climb.
        [_i, 1, "garrison cleared"] call fnc_town_garrison_setTier;
        // Tier I with every token lost: the town fields nothing, and cannot be cleared again, until the commander resupplies it.
        private _full = [[1] call DUWS_fnc_townSpawnList, missionNamespace getVariable ["enemyunitMultiplier", 1]] call DUWS_fnc_scaleComposition;
        [_key, _full] call DUWS_fnc_garrisonSetFull;
        [_key, 0] call DUWS_fnc_garrisonSeed;
    };
    // Instalment, not absolution -- a full discharge would let a player ruin a town to -20 and walk away square in one fight; a town at the floor takes two clears to recover.
    // Toward the middle whichever side was beaten, so neither can be shoved past neutral by force alone.
    private _step = [CLEAR_REP, -CLEAR_REP] select (_owner isEqualTo "BLU");
    [_i, _step, "garrison_cleared"] call fnc_town_rep_adjust;
    if (!isNil "DUWS_fnc_opcom_siteLost") then { [_key] call DUWS_fnc_opcom_siteLost };
    _t set ["awaitVacate", true];
    ["INFO", "CIV", format ["Town %1 %2 garrison cleared at tier %3; rep %4 %5",
        _i, _owner, _tier, _rep, _step]] call fnc_log;
};

// Called by fnc_town_rep_adjust on the crossing itself, so the tier changes with the map colour rather than on the next poller pass.
private _fnc_band = {
    params ["_i"];
    private _key = [_i] call fnc_town_site_key;
    private _rep = [_i] call fnc_civ_repAt;
    private _tier = [_i] call fnc_town_garrison_tierAt;

    private _owner = [_rep] call fnc_civ_townOwner;

    // Leaving a band takes whatever was bought with it, and so does crossing straight to the other side,
    // which one reputation step can do. There is no town left to hold either way.
    if (_tier > 0 && {_owner isNotEqualTo ([_i] call fnc_town_garrison_ownerAt)}) then {
        [_i, 0, "town changed hands"] call fnc_town_garrison_setTier;
        [_i] call fnc_town_garrison_clearHold;
        // Also done by the tick's teardown, which a town with no garrison standing never reaches; unlisting now keeps a
        // refill wave out of the gap before that tick.
        [_key, false] call DUWS_fnc_garrisonSetLive;
        [_key] call DUWS_fnc_garrisonReserveClear;
        [_key] call DUWS_fnc_garrisonForget;
        if (!isNil "DUWS_fnc_opcom_siteLost") then { [_key] call DUWS_fnc_opcom_siteLost };
        _tier = 0;
    };

    // The one place reputation writes a tier, and OPFOR's alone -- BLUFOR buy every tier of theirs.
    // Seeded regardless of proximity, so the commander can buy a town up while the player is elsewhere;
    // only the men wait for an arrival.
    if (_owner isEqualTo "OPF" && {_tier == 0}) then {
        [_i, 1, "reputation band"] call fnc_town_garrison_setTier;
        [_key, [1] call DUWS_fnc_townSpawnList] call DUWS_fnc_garrisonSeedOpforCap;
        // Re-armed on every crossing so a retaken town is held again each time; the latch goes with it since the player who spent the reputation is standing right there.
        private _held = [_i] call fnc_town_garrison_setHold;
        ([_key, "garrison"] call fnc_site_occupant) set ["awaitVacate", true];
        ["INFO", "CIV", format ["Town %1 taken at rep %2; first garrison held for %3 s and until the town is left",
            _i, _rep, _held]] call fnc_log;
    };
};

// Reached through the mission namespace because the hooks and triggers run outside this scope.
missionNamespace setVariable ["DUWS_town_raise", _fnc_raise];
missionNamespace setVariable ["DUWS_town_clear", _fnc_clear];
missionNamespace setVariable ["DUWS_town_band", _fnc_band];

{
    private _key = [_forEachIndex] call fnc_town_site_key;
    _x set ["townIndex", _forEachIndex];
    [_key, "garrison", createHashMapFromArray [["tick", _fnc_tick]]] call fnc_site_hooks_set;
    // A trigger rather than the 10 s tick, so the capture hold is timed at the zones' 0.5 s instead of sampled.
    // The tier gate comes first because a tier 0 town has nothing to clear, and siteTaken would otherwise run a spatial query on it twice a second.
    // The clear is called, not spawned: run unscheduled, it cannot interleave with the poller's tick on the same town.
    private _trg = createTrigger ["EmptyDetector", _centres select _forEachIndex, false];
    _trg setVariable ["DUWS_townIndex", _forEachIndex];
    _trg setTriggerActivation ["NONE", "PRESENT", true];
    // Direction is read off the owner: a town's garrison is taken by the other side, whichever side holds it.
    _trg setTriggerStatements [
        "private _i = thisTrigger getVariable 'DUWS_townIndex'; private _blu = ([_i] call fnc_town_garrison_ownerAt) isEqualTo 'BLU'; ([_i] call fnc_town_garrison_tierAt) > 0 && {[[_i] call fnc_town_site_key, 'town_gar', [WEST, EAST] select _blu, [EAST, WEST] select _blu] call DUWS_fnc_siteTaken}",
        "[thisTrigger getVariable 'DUWS_townIndex'] call DUWS_town_clear",
        ""
    ];
} forEach _towns;

["INFO", "CIV", format ["%1 town garrisons registered with the site poller", _count]] call fnc_log;
