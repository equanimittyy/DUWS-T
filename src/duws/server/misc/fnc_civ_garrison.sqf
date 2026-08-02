// Locality: server -- registered once for all towns by server/misc/fnc_civ_init_Tomata.sqf.
/*
    fnc_civ_garrison.sqf
    Owns every town's OPFOR garrison: raise one when BLUFOR arrive at a town the enemy holds,
    reinforce it as the commander buys, stream it out once the town has been empty long enough,
    and settle up when it is cleared. No params. Returns once the hooks are in place.

    The clock is fnc_site_poller's, which services every site on one thread. What stays here is the
    part a garrison does not share with a crowd or a zone: the reputation band that makes a town
    enemy ground at all, the commander's purchases, and the clear.

    The raise is the one part that cannot run inline -- it confirms over five seconds, then waits on
    the spawners and on the men actually appearing, up to a minute -- so it is dispatched to a
    short-lived worker per town and adopted on a later pass. The poller holds the clock of every
    other site and must not stall on one.
*/
if (!isServer) exitWith {};

// RAVAGE and WBK register no town reputation, so no town ever enters the OPFOR band and this
// thread would spin for the campaign doing nothing.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _count = count _locations;
if (_count == 0) exitWith {};
private _radii = missionNamespace getVariable ["civ_radii", []];
private _centres = _locations apply { getPos _x };

// The groups a raise hands back, flattened to the men in them. A roster is a unit list -- the same
// shape a zone's is -- so a garrison can be counted, thinned and collected without every caller
// having to know whether it is holding groups or men.
private _fnc_menOf = {
    params ["_grps"];
    private _men = [];
    { _men append (units _x) } forEach _grps;
    _men
};

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

// How far outside a town a garrison notices an arrival. The zone gate's figure, not the crowd's 200:
// a garrison is expensive enough to want the longer warning, and the raise below is written against
// the same ring.
#define STREAM_BUFFER 400

// Where a raise files its result for the poll to adopt. Unset while the worker is in flight, [] if
// it gave up, otherwise the garrison it stood up.
#define RAISE_SLOT(I) format ["DUWS_townRaise_%1", I]

// Spawned per raise. Nothing from this scope reaches it -- spawn breaks the scope chain -- so it
// takes everything it needs as parameters and hands its result back through the mission namespace.
private _fnc_raise = {
    params ["_i", "_centre", "_radius", "_tier", "_strength"];

    // Presence is decided the way zones decide it: a five-second re-test after first contact, so
    // grazing the perimeter does not commit a garrison for someone already leaving.
    sleep 5;
    if !([_centre, _radius + STREAM_BUFFER] call fnc_duws_bluforNear) exitWith {
        missionNamespace setVariable [RAISE_SLOT(_i), []];
    };

    // Filtered before it is thinned, so attrition reduces the force the side can actually field
    // rather than a composition that is about to lose entries to a campaign setting anyway.
    // Thinned by what the town has left, the way a zone's band is. A town beaten once fields a
    // fraction of its tier from then on, so the composition is the ceiling rather than the promise.
    private _want = [[DUWS_townSpawnTiers select (_tier - 1)] call DUWS_fnc_spawnFilter, _strength] call DUWS_fnc_thinComposition;
    private _men = [[_want, _centre, _radius, _strength] call DUWS_fnc_raiseGarrison] call _fnc_menOf;

    // OPFOR standing inside the trigger's own area, which is what makes the town clearable. SEIZED
    // is satisfied by an empty town as readily as by a fought-out one, so nothing else can tell the
    // two apart.
    private _fnc_opforPresent = {
        ({side _x == EAST} count (_centre nearEntities [["CAManBase"], _radius])) > 0
    };

    // Armed only once the garrison is standing in it. Each spawner resolves a safe position before
    // it places anything, and one that fails leaves the town holding the player and nobody else --
    // which is precisely what WEST SEIZED reports as cleared. A trigger armed beside the spawn
    // therefore hands the town its whole reputation debt back for a garrison nobody fought, which
    // reads in play as reputation climbing out of the negative band from standing in the town.
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
        ["WARN", "CIV", format ["Garrison tier %1 at town %2 placed no OPFOR within %3 m in 60 s; not armed",
            _tier, _i, _radius]] call fnc_log;
    };

    // SEIZED is the engine's own "this side present, the opposing side absent" test, and it decides
    // the clear rather than the roster does: a garrison that withdrew has cleared the town as surely
    // as one that was wiped, and only the trigger sees both. The roster is read for strength alone.
    // The interruptable timeout restarts if OPFOR walk back in, so the town has to be held clear
    // rather than sprinted through.
    // Whether CIVILIAN-side units block SEIZED is unconfirmed; if they do, this needs a plain
    // condition trigger counting hostile units in thisList instead.
    private _trg = createTrigger ["EmptyDetector", _centre, false];
    _trg setTriggerArea [_radius, _radius, 0, false];
    _trg setTriggerActivation ["WEST SEIZED", "PRESENT", true];
    _trg setTriggerTimeout [30, 40, 50, true];
    _trg setTriggerStatements ["this", "", ""];

    missionNamespace setVariable [RAISE_SLOT(_i), [_men, _want, _tier, _strength, _trg]];
};

// One record per town, held in the shared site store: the town garrison is an occupant of the same
// site its crowd is, so both are reached the same way and neither can go missing when the poller
// takes them over. Keyed rather than kept as parallel arrays because eleven fields indexed the same
// way are one transposition away from a town reinforcing against another's composition.
//
// awaitVacate is set whenever a hold is armed, and held until the town has been empty of BLUFOR
// once since. The hold expiring is not enough on its own: a player who took or cleared the town and
// stayed in it is still standing there when the clock lapses, and the arrival test would read them
// as having just walked up. Waiting for one empty cycle is what makes leaving and coming back the
// only way to meet the garrison, whichever hold put it off. It starts latched for the same reason
// at the other end: a town seeded into the band at campaign start would raise its garrison on
// sight. The first cycle clears it for any town nobody is near.
//
// emptySince is the diag_tickTime from which the town has been empty, or -1 while somebody is in
// it. The garrison streams out on this, so a step outside the radius does not tear it down and walk
// it back.
//
// deployed, deployedStrength and deployedList are what is standing, against what the town owes. The
// list is held beside the numbers because reinforcement is the difference between two compositions,
// not between two tiers -- a table retuned mid-campaign would otherwise have a standing garrison
// reinforced from a row it was never raised against. Tier and strength are separate purchases: a
// reinforcement moves the strength and not the tier, and an upgrade the reverse.
private _towns = [];
for "_i" from 0 to (_count - 1) do {
    private _key = [_i] call fnc_town_site_key;
    [_key, _centres select _i, _radii param [_i, 500]] call fnc_site_register;
    _towns pushBack ([_key, "garrison", EAST, STREAM_BUFFER, DESPAWN_GRACE] call fnc_site_occupant_register);
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
    // Read once per cycle beside the tier, because both branches below need it and they must
    // agree: the spawn thins its composition by this, and the reinforcement test compares it
    // against what the standing garrison was raised at.
    private _strength = [_i] call fnc_town_garrison_strengthAt;

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
            _res params ["_gotRoster", "_gotWant", "_gotTier", "_gotStrength", "_gotTrg"];
            ([[_i] call fnc_town_site_key] call fnc_site_roster) append _gotRoster;
            // Anchored to the men the town's first garrison placed, not re-measured from what
            // just arrived. A garrison that comes back at six tenths is still measured against
            // the ten, so the men killed last visit stay killed -- re-basing on the reduced
            // garrison restores the whole figure to beat on every visit, which is the refund
            // attrition exists to stop. The zone's rule, applied to towns.
            if ((_t get "baseline") <= 0) then {
                _t set ["baseline", {alive _x} count _gotRoster];
            };
            _t set ["tier", _gotTier];
            _t set ["deployedList", _gotWant];
            _t set ["deployedStrength", _gotStrength];
            _t set ["trg", _gotTrg];
            _t set ["awake", true];
            ["INFO", "CIV", format ["Garrison tier %1 spawned at town %2 (rep %3), %4 men",
                _gotTier, _i, _rep, _t get "baseline"]] call fnc_log;
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
            [_i, _centre, _radius, _tier, _strength] spawn (missionNamespace getVariable "DUWS_town_raise");
        };
    };

    // Streamed out once the town has been empty for DESPAWN_GRACE. Town garrisons used to stand
    // for the rest of the campaign wherever the player had ever been, so a long session left
    // live men in every town on the map; this makes a town cost what a zone costs.
    //
    // What it took is recorded first, against the strength the town will come back at. Without
    // that, streaming would hand back every casualty: grind a garrison to one man, walk away,
    // and the town rebuilds whole. Falls only -- the setter floors it and this never raises it
    // -- so damage accumulates across visits the way a zone's does.
    if (!_here && {(_t get "emptySince") >= 0}
        && {diag_tickTime > (_t get "emptySince") + DESPAWN_GRACE}) exitWith {
        private _left = [[_i] call fnc_town_site_key] call fnc_site_alive;
        if ((_t get "baseline") > 0) then {
            private _was = [_i] call fnc_town_garrison_strengthAt;
            [_i, (_left / (_t get "baseline")) min _was] call fnc_town_garrison_setStrength;
        };
        // The trigger goes with the men. Left armed over an empty town it would read WEST
        // SEIZED the moment a player walked back into ground the garrison had streamed out of,
        // and pay them a clear for a fight that never happened.
        deleteVehicle (_t get "trg");
        // The men, and the groups they leave behind. Most spawners set deleteGroupWhenEmpty but
        // not all do, and an empty group left on every stream-out of every town is a leak that
        // only shows as a slow drift over a long campaign.
        private _key = [_i] call fnc_town_site_key;
        private _grps = [];
        {
            if (!isNull _x) then { _grps pushBackUnique (group _x); deleteVehicle _x };
        } forEach ([_key] call fnc_site_roster);
        { if (count units _x == 0) then { deleteGroup _x } } forEach _grps;
        [_key] call fnc_site_roster_clear;
        ["INFO", "CIV", format ["Town %1 garrison streamed out holding %2 of %3; returns at %4 strength",
            _i, _left, _t get "baseline", [_i] call fnc_town_garrison_strengthAt]] call fnc_log;
        _t set ["awake", false];
        _t set ["trg", objNull];
        // The baseline is not cleared here: it is what the next visit is measured against.
        _t set ["tier", 0];
        _t set ["deployedStrength", 0];
        _t set ["deployedList", []];
        // Nothing below this describes a town that no longer has a garrison, and the
        // reinforcement test in particular would read the emptied deployed tier against a live
        // one and raise the whole composition again -- streaming the garrison out and straight
        // back in, on the one cycle nobody is there to see either.
    };

    // Bought while the garrison stands, so only what the new composition has and the standing
    // one does not is raised -- reinforcement arrives beside the survivors rather than as a
    // second garrison beside the first. Counting duplicates is the whole point: a tier that
    // goes from one team to two owes one team, not two.
    //
    // INVARIANT: this is downstream of the hold gate and must stay there. Only the gated branch
    // above raises a garrison, so a tier bought while a town is held cannot reach here -- it
    // raises the stored tier and the first spawn reads it whole once the hold and the latch are
    // both clear. A second spawn path that set garrisoned without that gate would silently let
    // an upgrade land on a town captured seconds ago, which is what MOBILISING exists to stop.
    //
    // Refused while BLUFOR are near, because reinforcement that materialises around the player
    // mid-fight is the pop-in the holds exist to prevent, and worse here -- men appearing behind
    // someone in contact reads as the mission cheating.
    // Buying and arriving are separate acts: the commander may raise a contested town's tier at
    // any time, and the men walk in once nobody is watching. The tier stays owed either way, so
    // it lands on a later cycle rather than being lost, the way a hold defers a first garrison.
    //
    // Tested against the stored pair rather than by diffing recomputed lists. The composition is
    // deterministic now, so the two agree -- but strength no longer shows in the list at all: a
    // town ground down and then recovered fields the same tokens at a different share, and a
    // diff of token lists cannot see that. The stored pair can.
    if ((_tier > (_t get "tier") || _strength > (_t get "deployedStrength"))
        && {!_here}) then {
        private _want = [[DUWS_townSpawnTiers select (_tier - 1)] call DUWS_fnc_spawnFilter, _strength] call DUWS_fnc_thinComposition;
        private _added = [[_t get "deployedList", _want] call DUWS_fnc_spawnDiff, _centre, _radius, _strength] call DUWS_fnc_raiseGarrison;
        private _addedMen = [_added] call _fnc_menOf;
        ([[_i] call fnc_town_site_key] call fnc_site_roster) append _addedMen;
        // Added to the baseline rather than re-measured from the roster. A garrison ground down
        // to three men and then reinforced by six is nine men against a baseline that still
        // counts the dead; re-basing on the alive count would refund every casualty the player
        // has already paid for.
        _t set ["baseline", (_t get "baseline") + ({alive _x} count _addedMen)];
        _t set ["tier", _tier];
        _t set ["deployedList", _want];
        _t set ["deployedStrength", _strength];
        ["INFO", "CIV", format ["Town %1 garrison reinforced to tier %2; baseline now %3 men",
            _i, _tier, _t get "baseline"]] call fnc_log;
    };

    // Tier 0 is the town no longer being OPFOR ground -- the band test above zeroes it when aid
    // or heals lift the town out, and the commander may zero it directly. Either way there is
    // nothing left to hold, so the garrison goes with the trigger that armed it.
    if (_tier == 0) then {
        deleteVehicle (_t get "trg");
        _t set ["trg", objNull];
        _t set ["awake", false];
        { deleteVehicle _x } forEach (([[_i] call fnc_town_site_key] call fnc_site_roster) select { alive _x });
        [[_i] call fnc_town_site_key] call fnc_site_roster_clear;
        // The one place the anchor goes, because the town is no longer enemy ground: whatever
        // it holds next is a new garrison rather than the remains of this one.
        _t set ["baseline", 0];
        _t set ["tier", 0];
        _t set ["deployedStrength", 0];
        _t set ["deployedList", []];
        ["INFO", "CIV", format ["Town %1 left the OPFOR band at rep %2; garrison cleared",
            _i, _rep]] call fnc_log;
    } else {
        if (!isNull (_t get "trg") && {triggerActivated (_t get "trg")}) then {
            deleteVehicle (_t get "trg");
            _t set ["trg", objNull];
            _t set ["awake", false];
            [[_i] call fnc_town_site_key] call fnc_site_roster_clear;
            // Baseline survives a clear too -- what was beaten is the purchase, not the anchor.
            _t set ["tier", 0];
            _t set ["deployedStrength", 0];
            _t set ["deployedList", []];
            // Clearing destroys the purchase but not the ownership. The tier files back down to
            // I rather than to 0: the town is still enemy ground, and it is the commander's
            // spending that was beaten, not the enemy's claim. No refund either -- with one, a
            // player clearing towns would hand the enemy its AP back and it would never climb.
            [_i, 1, "garrison cleared"] call fnc_town_garrison_setTier;
            // An instalment, not absolution. Discharging the whole debt let a player ruin a town
            // to -20 and walk away square on one fight, which made the reputation the garrison
            // was supposed to be the price of effectively free. A clear is worth a fixed step
            // back toward neutral, so a town driven to the floor takes four of them.
            // Self-limiting: only a town at or below the band can hold a garrison to clear, so
            // the most this can ever reach is one step above the band and it can never turn a
            // town friendly by force.
            [_i, CLEAR_REP, "garrison_cleared"] call fnc_town_rep_adjust;
            // Beaten to the floor and left there. Nothing restores it, so what comes back is a
            // shell for the rest of the campaign -- the lasting half of what clearing a town
            // buys, against the reputation step which is only an instalment.
            [_i, 0.3] call fnc_town_garrison_setStrength;
            // Left alone afterwards, and the hold is per-town state rather than a local because
            // two other things read it: fnc_town_garrison_setTier refuses a purchase through it,
            // so the commander cannot buy a beaten town up to IV while nobody is looking, and
            // the map readout prints the town as regrouping.
            [_i, "REGROUPING"] call fnc_town_garrison_setHold;
            // The player is standing in the town they just cleared. Nothing may spawn here
            // until they have left once, or the garrison the hold expires into would appear
            // around them.
            _t set ["awaitVacate", true];
            ["INFO", "CIV", format ["Town %1 cleared at tier %2; rep %3 + %4, garrison broken to 0.3 and regrouping",
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
