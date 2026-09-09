// Locality: server -- registered once for all towns by server/civilian/fnc_civ_init_Tomata.sqf.
// Owns each town's OPFOR garrison for fnc_site_poller: raises on BLUFOR arrival, reinforces on purchase, streams out when empty, settles on clear.
// The raise is dispatched to a per-town worker (5 s confirm, then up to 60 s for men) so the poller thread never stalls on one town.
if (!isServer) exitWith {};

// RAVAGE/WBK register no town reputation, so no town ever crosses the OPFOR band; this thread would otherwise spin doing nothing.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _count = count _locations;
if (_count == 0) exitWith {};
private _radii = missionNamespace getVariable ["civ_radii", []];
private _centres = _locations apply { getPos _x };

// Read as town ownership by the map markers, OPFOR AP income and disguise gate: crossing it sets tier I OPFOR ground, leaving it discharges the town.
// Tiers II-IV are the commander's purchase, so a merely-ruined town isn't automatically hard -- the enemy has to have spent on it.
#define OPFOR_BAND -10

// Value of one cleared garrison against the town's debt -- deliberately a step, not the whole balance (see clear branch below).
#define CLEAR_REP 5

// Streams on the "town_gar" profile (DUWS_streamProfiles): grace 120 matches the zone's, since stepping outside to flank isn't leaving and rebuilding around a returning player would reset their damage for free.
// Buffer 400 (vs the crowd's 200): a garrison is expensive enough to want the longer warning; the gate and tick below assume this ring.

// Slot a raise files its result in: nil while in flight, [] if it gave up, otherwise the garrison stood up.
#define RAISE_SLOT(I) format ["DUWS_townRaise_%1", I]

// spawn breaks the scope chain, so this takes everything it needs as params and returns via the mission namespace.
private _fnc_raise = {
    params ["_i", "_centre", "_radius", "_tier"];
    private _key = [_i] call fnc_town_site_key;

    // Five-second re-test (as zones do), so grazing the perimeter doesn't commit a garrison for someone already leaving.
    sleep 5;
    if !([_centre, _radius + ((DUWS_streamProfiles get "town_gar") select 0)] call fnc_duws_bluforNear) exitWith {
        missionNamespace setVariable [RAISE_SLOT(_i), []];
    };

    // Zone's reserve model: filtered x1 tier thins to garrison_density on stand, surplus + mult-1 copies wait in the pool, less the loss ledger.
    // Filtered before deriving so a token the side can't field isn't counted into full and later chased by refill.
    private _x1 = [DUWS_townSpawnTiers select (_tier - 1)] call DUWS_fnc_spawnFilter;
    private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
    private _stand = [_x1] call DUWS_fnc_zoneDensityStand;
    ([_key, _x1, _mult, _stand] call DUWS_fnc_garrisonDerive) params ["_garrison", "_pool"];
    missionNamespace setVariable [format ["DUWS_zoneCeiling_%1", _key], count _stand];
    private _grps = [_garrison, _centre, _radius] call DUWS_fnc_raiseGarrison;
    private _men = [_grps] call fnc_site_men_of;

    // Confirms the raise actually placed men before the tick adopts it -- a spawner that fails to find a safe position would otherwise leave nobody there to roster.
    private _fnc_opforPresent = {
        ({side _x == EAST} count (_centre nearEntities [["CAManBase"], _radius])) > 0
    };

    // Waits up to a minute so a raise isn't adopted empty -- an empty roster would read as already beaten on the next capture check.
    private _deadline = diag_tickTime + 60;
    waitUntil { sleep 2; (call _fnc_opforPresent) || {diag_tickTime > _deadline} };
    if !(call _fnc_opforPresent) exitWith {
        // Deleted, not abandoned, or every retry would silt the map with units nothing tracks; the band still holds so a later cycle retries the raise.
        { deleteVehicle _x } forEach _men;
        missionNamespace setVariable [RAISE_SLOT(_i), []];
        ["WARN", "CIV", format ["Garrison tier %1 at town %2 placed no OPFOR within %3 m in 60 s; not adopted",
            _tier, _i, _radius]] call fnc_log;
    };

    // Filed for the tick to adopt: raised groups (rostered, killed-watch hung, site marked live) and the tier raised at.
    // No SEIZED trigger any more -- clearing is decided by the shared garrisonBeaten test on the poller tick, so a town must be beaten, not merely emptied.
    missionNamespace setVariable [RAISE_SLOT(_i), [_grps, _tier]];
};

// One record per town, keyed (not parallel arrays) -- eleven same-indexed fields risk a transposition between towns.
// awaitVacate latches until BLUFOR leave once after a hold arms; emptySince (-1 while occupied) gates the stream-out; tier is the deployed tier, distinct from the owned tier the band/commander set.
private _towns = [];
for "_i" from 0 to (_count - 1) do {
    private _key = [_i] call fnc_town_site_key;
    [_key, _centres select _i, _radii param [_i, 500]] call fnc_site_register;
    _towns pushBack ([_key, "garrison", EAST, "town_gar"] call fnc_site_occupant_register_profile);
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

    // Only place reputation writes a tier; seeded regardless of proximity, so a town is OPFOR ground from the moment it crosses the band.
    // That lets the commander buy it up while the player is elsewhere -- only the men wait for an arrival.
    if (_rep <= OPFOR_BAND && _tier == 0) then {
        [_i, 1, "reputation band"] call fnc_town_garrison_setTier;
        _tier = 1;
        // Re-armed on every crossing so a retaken town is held again each time; the latch goes with it since the player who spent the reputation is standing right there.
        // Logged once here, not per deferred cycle -- sixty identical lines isn't a readable log, and this one carries the figure a tester needs.
        private _held = [_i, "MOBILISING"] call fnc_town_garrison_setHold;
        _t set ["awaitVacate", true];
        ["INFO", "CIV", format ["Town %1 taken at rep %2; first garrison held for %3 s and until the town is left",
            _i, _rep, _held]] call fnc_log;
    };
    // Band is the sole condition -- leaving it (by aid/heals, not just a fight) takes whatever the commander bought with it; there's no town left to hold.
    if (_rep > OPFOR_BAND && _tier > 0) then {
        [_i, 0, "left the OPFOR band"] call fnc_town_garrison_setTier;
        _tier = 0;
        // Claim is gone, so the hold goes with it -- a town worked back to neutral is neutral, not regrouping, and a still-armed hold would refuse the tier raise if the town were ruined again inside the window.
        [_i] call fnc_town_garrison_clearHold;
    };

    // Presence/empty-clock/vacate-latch are computed once by the poller and passed in, so the arrival test, latch and streaming teardown can't disagree on "somebody is here" a few seconds apart.

    // Raise in flight owns the town until it reports -- otherwise the reinforcement test would read the still-empty roster as owing the whole composition and raise it a second time.
    if (_t get "raising") exitWith {
        private _res = missionNamespace getVariable [RAISE_SLOT(_i), nil];
        if (isNil "_res") exitWith {};
        _t set ["raising", false];
        missionNamespace setVariable [RAISE_SLOT(_i), nil];
        if !(_res isEqualTo []) then {
            _res params ["_gotGrps", "_gotTier"];
            private _roster = [_key] call fnc_site_roster;
            { _roster append (units _x) } forEach _gotGrps;
            // Site live also enlists it in the reserve pass; the killed watch reinforces in hunt waves and records each wiped group's token into the ledger, same as a zone. Losses live in the ledger from here on.
            [_key, _gotGrps] call DUWS_fnc_garrisonReserveWatch;
            [_key, true] call DUWS_fnc_garrisonSetLive;
            _t set ["tier", _gotTier];
            _t set ["awake", true];
            ["INFO", "CIV", format ["Garrison tier %1 spawned at town %2 (rep %3), %4 men",
                _gotTier, _i, _rep, [_key] call fnc_site_alive]] call fnc_log;
        };
    };

    // Hold + latch answer one question (may this town raise yet) as one gate; the latch stops either hold from expiring into a spawn around a player who never left.
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

    // Commander tier buy re-derives full potential/reserve pool at the new tier (same split the raise uses) and raises the ceiling; the refill pass delivers the growth as hunt waves, same as topping up a mauled garrison.
    // No bespoke reinforcement raise -- a town reinforces like a zone now; fnc_town_garrison_reinforce handles the strength half by un-losing tokens back into the pool.
    //
    // INVARIANT: must stay downstream of the hold gate above -- a tier bought while held can't reach here; it raises the owned tier, and the first spawn reads it whole once hold/latch clear.
    // Guarded on awake so a streamed-out town (deployed tier zeroed) re-raises whole instead of re-deriving a pool against a garrison that isn't standing.
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

    // Tier 0 means the town is no longer OPFOR ground (band test above, or the commander directly) -- nothing left to hold, so the garrison goes with the same collection the stream-out uses, vehicles included.
    // Can fire with the player standing in the town; having already taken the men out of sight, leaving their transport behind would be the odd half.
    if (_tier == 0) then {
        [_key, false] call DUWS_fnc_garrisonSetLive;
        [_key] call DUWS_fnc_garrisonReserveClear;
        _t set ["awake", false];
        [_key] call fnc_site_collect;
        // Forgets the garrison entirely so a town that crosses back into the band starts fresh, not redeploying the remains of one the ground no longer holds.
        [_key] call DUWS_fnc_garrisonForget;
        _t set ["tier", 0];
        ["INFO", "CIV", format ["Town %1 left the OPFOR band at rep %2; garrison cleared",
            _i, _rep]] call fnc_log;
    } else {
        // Cleared at a tenth of full potential (garrison + owed reserves), the same break test a zone uses, so a town isn't finished while its waves are still inbound.
        // What clearing does differs from a zone: a reputation credit, garrison reseeded to 0.3, and a REGROUPING hold -- never a change of owner.
        if (_t get "awake" && {[_key] call DUWS_fnc_garrisonBeaten}) then {
            [_key, false] call DUWS_fnc_garrisonSetLive;
            [_key] call DUWS_fnc_garrisonReserveClear;
            [_key] call fnc_site_roster_clear;
            _t set ["awake", false];
            _t set ["tier", 0];
            // Clearing destroys the purchase, not the ownership -- tier files back to I, not 0: the commander's spending was beaten, not the enemy's claim to the ground.
            // No refund either, or a player clearing towns would hand the enemy its AP back and the OPFOR economy would never climb.
            [_i, 1, "garrison cleared"] call fnc_town_garrison_setTier;
            // Instalment, not absolution -- a full discharge would let a player ruin a town to -20 and walk away square in one fight; a town at the floor now takes four clears to recover.
            // Self-limiting too: only a town at or below the band can hold a garrison to clear, so this can never turn a town friendly by force.
            [_i, CLEAR_REP, "garrison_cleared"] call fnc_town_rep_adjust;
            // Seeded to a scratch 0.3: a thin garrison with no reserve depth (spends the pool copies first) and left there -- nothing restores it but a paid reinforcement.
            // That shell is the lasting half of what clearing buys, against the reputation step which is only an instalment.
            [_key, 0.3] call DUWS_fnc_garrisonSeed;
            // Read by two others: fnc_town_garrison_setTier refuses a purchase through it (no buying up a beaten town unseen), and the map readout prints it regrouping.
            [_i, "REGROUPING"] call fnc_town_garrison_setHold;
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
