// Locality: server -- publishes the zone streaming hooks. Called once from server_fnc_init, after
// the site store and the zone state file it reads.
//
// One hook set shared by every zone: a zone differs from another only in its key, its position and
// its radius, all of which arrive as arguments. This replaces two permanent threads per zone -- the
// streaming loop and fnc_createzone's tail loop, which polled a shared array slot the first one set.
// The handshake between them goes with them: the tick below raises directly and adopts the result,
// which is what the raise flag is for.
if (!isServer) exitWith {};

// How far a fallen zone's survivors are sent. Past the streaming ring, so a group that actually
// walks it ends up outside the radius the player who just took the zone is likely to still be in.
#define WITHDRAW_DISTANCE 800

// No player within this of a survivor before it is collected. Wider than the litter sweep's 300 m
// because these are live men: a body blinking out at 300 m goes unnoticed and a soldier doing it
// does not.
#define WITHDRAW_KEEP_RADIUS 500

// Where a raise files its result for the tick to adopt. Unset while the worker is in flight.
#define ZONE_RAISE_SLOT(K) format ["DUWS_zoneRaise_%1", K]

// How many times an emplacement is dropped before it is given up on, and how long it is given to
// fall and come to rest before its lean is read.
#define STATIC_DROP_ATTEMPTS 5
#define STATIC_SETTLE_WAIT 2

// Drop height, as clearance plus a step per attempt -- 0.35 m on the first, 0.75 m on the last. The
// clearance is not slack: the position a drop is measured from is the one the composition recorded,
// which is the object's own centre, and a gun recorded lying on its side has a centre roughly half
// its height below the one it will have standing. Without it the first attempts would drop an
// upright gun into the ground it has to clear, spending half the budget getting back to zero.
#define STATIC_DROP_BASE 0.25
#define STATIC_DROP_STEP 0.1

// A gun that did not settle standing is on ground that tips it, not merely sunk -- a straight-down
// re-drop lands it back on the same edge. Each failed round widens a findEmptyPosition probe by this
// much and re-drops onto whatever clear ground it finds, hunting a spot the gun stands on, up to ~3 m.
#define STATIC_SHUFFLE_STEP 0.6

// The lean the shuffle hunts to beat: a gun that came to rest steeper than this off vertical (~26
// degrees) is not force-stood where it landed but re-dropped on a nudged x/y, so its gunner ends up
// on a gun that actually stands rather than one snapped upright on ground that tips it back. Looser
// than truly vertical on purpose -- siting caps ground at ~19 degrees, and a gun resting on that legal
// slope must still read as standing or every slope emplacement would shuffle itself unmanned.
#define STATIC_STANDING_DOT 0.9

// The seat-time floor, the cosine of ~45 degrees. Below it a gun is on its side and the engine will
// not keep a gunner in it. STATIC_STANDING_DOT is the stricter bar the drop loop holds guns to; this
// looser one still guards the prefab crewing path (DUWS_fnc_crewCompositionStatics), whose guns are
// placed on prepared ground and never dropped, so they are not shuffle-hunted for a standing spot.
#define STATIC_UPRIGHT_DOT 0.7

// Stand a gun upright and drop it from _height above where its composition put it.
//
// Dropped rather than placed, because both ways a rebuilt emplacement fails come from the ground it
// lands on. A gun settled into terrain or composition clutter refuses its gunner memory point
// silently; a gun that goes over is emptied by the engine and refuses a new man for as long as it
// lies there. Starting higher on each attempt walks the gun out of whatever it sank into, and
// standing it up first means it never begins the fall on its side.
DUWS_fnc_dropStatic = {
    params ["_gun", "_base", "_height"];
    // No heal here: the caller holds the gun undamageable for the whole run of drops, so a landing
    // that once wrecked it now only shoves it.
    // Only the heading survives a fall worth keeping, and a gun that went over its nose has not even
    // that: its dir points into the ground, and handing that to setVectorDirAndUp against a vertical
    // up gives the engine two near-parallel vectors and an orientation it can make nothing of. North
    // is arbitrary and deliberately so -- a gun facing the wrong way still traverses onto targets.
    private _dir = vectorDir _gun;
    private _flat = [_dir select 0, _dir select 1, 0];
    if (vectorMagnitude _flat < 0.1) then { _flat = [0, 1, 0] };
    _gun setVectorDirAndUp [vectorNormalized _flat, [0, 0, 1]];
    // After the rotation, which displaces the object -- the order fnc_duws_deploy places props in,
    // for the same reason. World coordinates throughout, so a gun standing on a composition's
    // bunker roof is lifted off the roof rather than dropped through it to the terrain.
    _gun setPosWorld (_base vectorAdd [0, 0, _height]);
    // Enabled last, so the fall starts from the position just written rather than from wherever a
    // frame boundary mid-placement left the gun. Needed at all because the prefabs build their
    // weapons with simulation off and re-enable only the classnames they list: one they miss stows
    // and comes back that way, and would hang at the drop height instead of falling.
    _gun enableSimulationGlobal true;
};

// Seat one man on one gun that has come to rest, and answer whether he took it.
//
// moveInGunner reports nothing either way, so the only proof is read back off the gun. It is refused
// silently by a static settled into the terrain or composition clutter around it, and by one lying on
// its side -- the engine empties a gun that goes over and keeps it empty for as long as it lies
// there. Between them that is what left a pair of soldiers standing beside their guns for the rest of
// a campaign: each had been spawned, rostered and counted toward the garrison's peak, so the failure
// both weakened the zone and left a statue for the player to walk up to.
DUWS_fnc_seatStatic = {
    params ["_gun", "_unit"];
    // Freeze, seat, thaw -- not seat into a running gun. A gunner moved into an already-simulated
    // static keeps a dead turret: it fires only down its placed heading and never traverses onto a
    // target. The zone prefabs crew their guns in this order for the same reason. The drop above needs
    // simulation on to fall, so the settled gun is re-frozen for the seat and thawed straight after.
    if (((vectorUp _gun) select 2) > STATIC_UPRIGHT_DOT) then {
        _gun enableSimulationGlobal false;
        // Stand it dead upright before the gunner takes it. The gate above passes a gun that came to
        // rest leaning up to 45 degrees, and thawing a crewed gun at that lean is what leaves a manned
        // gun lying on its side. Snapped square while frozen -- the thaw below settles the small gap the
        // rotation opens under the base, and it settles vertical rather than back onto the old lean.
        _gun setVectorUp [0, 0, 1];
        _unit moveInGunner _gun;
        _gun enableSimulationGlobal true;
    };
    !isNull _unit && {gunner _gun isEqualTo _unit}
};

// Place a composition's guns and crew the ones that come to rest standing.
//
// In rounds over every gun rather than gun by gun: a drop can only be read once the gun has fallen
// and settled, and one wait covers every gun in the air, so a six-gun zone costs the same seconds
// as a one-gun zone instead of six times as many. A gun is crewed only where it came to rest standing
// (STATIC_STANDING_DOT); one that settled leaning is not force-stood there but dropped again -- higher,
// and shuffled onto nearby clear ground -- because the spot that tipped it will tip it again, and a
// straight-down re-drop lands it back on the same edge. The lean is read after the settle, not the
// seat: a snapped-upright gun on tipping ground reads as seated and then falls over crewed.
DUWS_fnc_manStatics = {
    params ["_guns", "_grp"];
    // Indexed off the spawned group rather than assumed one-to-one: a group that came back short
    // would otherwise throw here every despawn cycle for the rest of the campaign.
    private _men = units _grp;
    private _pending = [];
    {
        // Undamageable for the whole run of drops: a landing on hard ground or a clip into composition
        // clutter can wreck the gun outright, which would make the recovery the thing that removes the
        // emplacement. Off, the same landing only shoves it, so no gun is lost to its own placement --
        // no wreck-and-rebuild path needed.
        _x allowDamage false;
        _pending pushBack [_x, getPosWorld _x, _men param [_forEachIndex, objNull]];
    } forEach _guns;

    for "_drop" from 1 to STATIC_DROP_ATTEMPTS do {
        if (count _pending == 0) exitWith {};
        {
            [_x select 0, _x select 1, STATIC_DROP_BASE + (STATIC_DROP_STEP * _drop)]
                call DUWS_fnc_dropStatic;
        } forEach _pending;
        sleep STATIC_SETTLE_WAIT;

        private _next = [];
        {
            _x params ["_gun", "_base", "_unit"];
            // Replaced rather than abandoned: the gun is a defence the zone is still counting on, and
            // the man may have been shot over the seconds the drops take.
            if (!alive _unit) then {
                _unit = _grp createUnit [opfor_SOLDIER_X, getPos _gun, [], 0, "NONE"];
            };
            // Seat only where it came to rest standing: a gun leaning past STATIC_STANDING_DOT is on
            // ground that tipped it, so snapping it square and seating there would just leave a manned
            // gun on its side. && short-circuits, so a leaning gun is never handed a gunner.
            private _placed = ((vectorUp _gun) select 2) > STATIC_STANDING_DOT
                && {[_gun, _unit] call DUWS_fnc_seatStatic};
            if (!_placed) then {
                // Hunt a spot it stands on: probe the ring around the base for ground the gun's own class
                // fits (findEmptyPosition tests object collision and terrain slope both) and re-drop there
                // next round, widening the search each time. Keeps the world Z so the drop height math
                // holds over the small step; [] (nothing clear near) leaves the base rather than trade down.
                private _shuffle = [_base select 0, _base select 1] findEmptyPosition [0.5, STATIC_SHUFFLE_STEP * _drop, typeOf _gun];
                if !(_shuffle isEqualTo []) then { _base = [_shuffle select 0, _shuffle select 1, _base select 2] };
                _next pushBack [_gun, _base, _unit];
            };
        } forEach _pending;
        _pending = _next;
    };

    // Damageable again now the drops are done: an emplacement the player cannot destroy is worse than
    // one that placed badly. Every gun, seated or not -- an unmanned gun is still ground to fight over.
    { _x allowDamage true } forEach _guns;

    {
        _x params ["_gun", "_base", "_unit"];
        ["WARN", "ZONES", format ["emplacement %1 took no gunner; left unmanned",
            typeOf _gun]] call fnc_log;
        // The gun stays: an empty emplacement is ground the player can use. The man does not -- he
        // is about to go on the roster and count toward the peak, and an unrostered-looking man
        // beside a gun he never entered denies the zone its capture while reading as a bug.
        if (!isNull _unit) then { deleteVehicle _unit };
    } forEach _pending;
};

// [_weapons, _pos] call DUWS_fnc_crewCompositionStatics -> the crew's men
//
// Crews the static weapons a prefab has just placed: one gunner per gun, seated through
// DUWS_fnc_seatStatic -- the same seat-then-thaw the stream re-crew uses, so the order a gunner enters
// a gun cannot drift between the two and leave a dead turret. The guns stand on the prefab's own
// prepared ground, so each is thawed where it is rather than dropped from height like DUWS_fnc_manStatics
// does for a gun coming back onto open terrain -- that is the one thing the two paths do differently.
DUWS_fnc_crewCompositionStatics = {
    params ["_weapons", "_pos"];
    private _guns = _weapons select {!isNull _x};
    if (_guns isEqualTo []) exitWith { [] };
    private _spawnPos = _pos findEmptyPosition [0, 30, opfor_SOLDIER_X];
    if (count _spawnPos == 0) then { _spawnPos = _pos };
    private _grp = [_spawnPos, EAST, _guns apply {opfor_SOLDIER_X}, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _grp deleteGroupWhenEmpty true;
    { [_x, (units _grp) param [_forEachIndex, objNull]] call DUWS_fnc_seatStatic } forEach _guns;
    [_grp, _pos] call bis_fnc_taskDefend;
    units _grp
};

// Zone turrets get their gunners from the prefab at build time, and the prefab never runs again --
// so a composition that has been stowed comes back with empty guns unless they are re-crewed here.
// Skipped once the zone is BLUFOR's: the emplacements are then the player's to use, which is the
// same reason zone compositions are persistent rather than released on capture.
DUWS_fnc_zoneManStatics = {
    params ["_pos", "_key"];
    if !(_pos in WARCOM_zones_controled_by_OPFOR) exitWith {};
    private _roster = [_key] call fnc_zone_roster;
    private _statics = (DUWS_compositions getOrDefault [_key, []]) select {
        !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"}
    };

    // A gun still carrying the crew the prefab gave it. That gunner is the zone's garrison as much
    // as a spawned one, so he joins the roster rather than holding the objective off the books:
    // unrostered, he denies capture through fnc_opfor_count_at while counting toward neither the
    // peak nor the break line, so killing him is progress the zone never registers.
    { _roster append (crew _x) } forEach (_statics select {count crew _x > 0});

    private _guns = _statics select {count crew _x == 0};
    if (count _guns == 0) exitWith {};
    // Every empty gun is crewed, whatever the zone's attrition. Attrition thins what a garrison can
    // field -- men out of a team, vehicles off the list -- and a static weapon is neither: it is
    // already standing on the ground, so thinning does not make the zone weaker, it makes the
    // emplacement scenery the player walks past. A worn-down zone therefore has the same guns and
    // fewer of everything else.
    private _types = _guns apply {opfor_SOLDIER_X};
    private _spawn = _pos findEmptyPosition [0, 30, opfor_SOLDIER_X];
    if (count _spawn == 0) then { _spawn = _pos };
    private _grp = [_spawn, EAST, _types, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _grp deleteGroupWhenEmpty true;
    [_guns, _grp] call DUWS_fnc_manStatics;
    // On the roster like everything DUWS_fnc_raiseGarrison raises: these are the zone's garrison
    // too, and a blunt radius sweep has no other way to know it.
    _roster append (units _grp);
    [_grp, _pos] call bis_fnc_taskDefend;
};

// The emplacement kind: a static weapon and the man on it, which do not stream the same way. The gun is
// campaign property that belongs to whoever holds the ground, so it stows; the man is a defender, so he
// goes. That split is the reason the model divides by what is streamed rather than by side -- one object and
// one man, on the same objective, with opposite answers.
//
// Crewing out has to happen here rather than in the garrison sweep: that sweep's man clause tests vehicle _x
// == _x, so a gunner sitting in a static keeps his seat, and stow refuses while any member is crewed.
DUWS_zoneEmplacementHooks = createHashMapFromArray [
    ["wake", { params ["_key", "_o"]; [([_key] call fnc_site_at) get "pos", _key] call DUWS_fnc_zoneManStatics }],
    ["sleep", { params ["_key", "_o"];
        {
            if (_x isKindOf "StaticWeapon") then { deleteVehicleCrew _x };
        } forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
    }]
];

// The structure kind: props, walls and the prefab itself. Stowed, never deleted -- rebuilding them
// from scratch would restore the damage the player did to them, and the emplacements become the
// player's own the moment they take the ground.
DUWS_zoneStructureHooks = createHashMapFromArray [
    ["wake", { params ["_key", "_o"];
        if (_key in DUWS_stowed) then {
            [_key] call fnc_duws_deploy;
            ["INFO", "STREAM", format ["deployed %1", _key]] call fnc_log;
        };
        // The zone flag is pinned, not stowed, so it was hidden rather than deleted -- show it again.
        { if (_x isKindOf "FlagPole_F") then { _x hideObjectGlobal false } } forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
    }],
    ["sleep", { params ["_key", "_o"];
        if ([_key] call fnc_duws_stow) then {
            ["INFO", "STREAM", format ["stowed %1", _key]] call fnc_log;
        };
        // Hide the pinned flag rather than delete it, so it keeps its identity but leaves no lone pole.
        { if (_x isKindOf "FlagPole_F") then { hideObjectGlobal _x } } forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
    }]
];

// Ordered, which is why these two are driven rather than polled: the crews have to be out of the
// guns before the composition holding those guns can be stowed.
DUWS_fnc_zoneStow = {
    params ["_key"];
    [_key, [_key, "emplacement"] call fnc_site_occupant] call (DUWS_zoneEmplacementHooks get "sleep");
    [_key, [_key, "structure"] call fnc_site_occupant] call (DUWS_zoneStructureHooks get "sleep");
    // The reserve pool is per-awake-session. Cleared here -- losses were recorded live as groups fell,
    // so there is nothing to fold in on the way out -- and reseeded by fnc_zone_spawn on the next raise,
    // so a stowed zone reads no owed reserve and comes back consistent with the ledger it packed up with.
    [_key] call DUWS_fnc_garrisonReserveClear;
};

// Survivors of a zone that has fallen: ordered off the objective here, collected by the tick once nobody can
// see them go. The order is what makes the collection quiet rather than what performs it -- a group that
// cannot path is still collected on distance, so nothing is left standing whether or not the walk works.
//
// Roster-scoped, so only this zone's own garrison goes: a neighbouring town's or a side mission's guards are
// not this zone's to take. Returns the men, for the collection to work through.
//
// Locality: addWaypoint and setBehaviour are ignored unless the group is local to the machine issuing them
// (docs/info/architecture/arma_engine_gotchas.md); every group on a zone roster is server-spawned.
DUWS_fnc_zoneSendOff = {
    params ["_key", "_pos"];
    private _men = ([_key] call fnc_zone_roster) select { alive _x };
    private _grps = [];
    { _grps pushBackUnique (group _x) } forEach _men;
    // Every held post is released before a single order is issued, because a garrison man is held
    // two ways and a withdrawal has to undo both: PATH is switched off so he cannot walk out of his
    // building at all, and the shared house pass can also have him on a loop that reissues doMove,
    // which beats a waypoint added afterwards. Without this the men in the houses simply stayed in
    // them and were collected on distance instead of walking off.
    {
        _x setVariable ["DUWS_postReleased", true];
        _x enableAI "PATH";
    } forEach _men;
    {
        private _grp = _x;
        // The defend and patrol waypoints the spawners gave them would pull them straight back onto
        // the objective. Back to front: deleteWaypoint shifts every later index down, so a forward
        // pass deletes every other one.
        private _wps = waypoints _grp;
        reverse _wps;
        { deleteWaypoint _x } forEach _wps;
        // Outward on the bearing they already stand on, so a group on the far side of the zone does
        // not cross it to leave.
        private _dest = _pos getPos [WITHDRAW_DISTANCE, _pos getDir (leader _grp)];
        private _wp = _grp addWaypoint [_dest, 50];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
        _grp setBehaviour "AWARE";
        _grp setSpeedMode "FULL";
        // Saves the collection having to tidy up behind itself: the engine drops the group on the
        // last man, whether he was collected or shot.
        _grp deleteGroupWhenEmpty true;
    } forEach _grps;
    _men
};

// Dispatched rather than run inline: a full composition takes up to a couple of minutes to place,
// and the poller holds the clock of every other site. It files what it raised for the tick to adopt.
DUWS_fnc_zoneRaiseWorker = {
    params ["_key", "_pos", "_size"];
    // Confirmed after a pause rather than acted on the moment anyone clips the perimeter. A
    // helicopter transiting, or a patrol that turns back at the edge, would otherwise rebuild a
    // whole composition for someone already leaving. Air is folded in the same terms the poller's
    // wake used: a committed aircraft holds the raise, where fnc_duws_bluforNear alone -- discounting
    // anything airborne -- would confirm an air wake straight back off and never let the zone stand.
    sleep 5;
    if !([_pos, _size + DUWS_streamArrivalMargin, 2, DUWS_zoneAirRing, DUWS_zoneAirCommitSpeed, true] call fnc_site_bluforOrAir) exitWith {
        missionNamespace setVariable [ZONE_RAISE_SLOT(_key), false];
    };

    // The roster is cleared here rather than where the band is raised, because the turret crews
    // below are garrison too and a roster cleared after them would drop them.
    [_key] call fnc_site_roster_clear;
    // Structure, then emplacement, then men: units must not spawn into ground that is about to have
    // a bunker on it, and the turrets have to exist before anyone mans them.
    [_key, [_key, "structure"] call fnc_site_occupant] call (DUWS_zoneStructureHooks get "wake");
    [_key, [_key, "emplacement"] call fnc_site_occupant] call (DUWS_zoneEmplacementHooks get "wake");
    [_pos, _size, _key] call fnc_zone_spawn;
    missionNamespace setVariable [ZONE_RAISE_SLOT(_key), true];
};

// One tick per zone per pass. Presence, the empty clock and the vacate latch arrive answered.
//
// Each branch below ends the pass for this zone: they are mutually exclusive states of one
// garrison, and the raise in particular must never see a zone that is mid-withdrawal.
DUWS_zoneHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    private _size = _site get "radius";
    private _opforHolds = _pos in WARCOM_zones_controled_by_OPFOR;

    // A zone the player took, still walking its survivors off. Retried every pass rather than timed
    // out, so a man somebody is standing over is collected when they leave rather than never.
    // Nothing else would collect them -- fnc_repetitive_cleanup takes bodies, wrecks and empty
    // vehicles, never living men.
    if (_o get "withdrawing") exitWith {
        // On a roster of its own, not in the record: a record holds plain values so it can survive a
        // save, and these are object references. The kind names what they are -- men walking off
        // ground they no longer hold.
        private _left = ([_key, "withdrawing"] call fnc_site_roster) select { alive _x };
        // BIS_fnc_ListPlayers, not allPlayers: this is the streaming system's own answer to "is a
        // player here", and the whole collection turns on it. A list that came back empty where it
        // should not would delete every survivor on the first pass, which is precisely the vanishing
        // act the walk-off exists to avoid.
        private _players = call BIS_fnc_ListPlayers;
        {
            private _man = _x;
            if ((_players findIf { _x distance _man < WITHDRAW_KEEP_RADIUS }) < 0) then {
                deleteVehicle _man;
            };
        } forEach _left;
        private _roster = [_key, "withdrawing"] call fnc_site_roster;
        _roster resize 0;
        _roster append (_left select { alive _x });
        // Whatever is still walking goes with BLUFOR's tenure. A retake means they left the zone, so
        // there is nobody to watch it happen, and the garrison that arrives files a roster of its own
        // these men would not be on -- left alive, nothing would collect them.
        if (_opforHolds) then {
            { deleteVehicle _x } forEach _roster;
            [_key, "withdrawing"] call fnc_site_roster_clear;
            _o set ["withdrawing", false];
        };
    };

    // A raise in flight owns this zone until it reports.
    if (_o get "raising") exitWith {
        private _res = missionNamespace getVariable [ZONE_RAISE_SLOT(_key), nil];
        if (isNil "_res") exitWith {};
        missionNamespace setVariable [ZONE_RAISE_SLOT(_key), nil];
        _o set ["raising", false];
        _o set ["awake", _res];
    };

    if !(_o get "awake") exitWith {
        if (_here && {!(_o get "awaitVacate")} && {_opforHolds}) then {
            _o set ["raising", true];
            missionNamespace setVariable [ZONE_RAISE_SLOT(_key), nil];
            [_key, _pos, _size] spawn DUWS_fnc_zoneRaiseWorker;
        };
    };

    // The zone changed hands. The composition is not despawned -- the emplacements are the player's
    // now -- but its surviving OPFOR are a different question. The capture trigger tests over the
    // radius while streaming reaches 400 m further, so the zone can flip with everything in that
    // ring still alive: those units were never inside the test. Bounded rather than open-ended:
    // fnc_zone_capture_ready refuses while more than its break fraction of the peak is alive on the
    // roster anywhere, so this is a tenth of a garrison at worst.
    if !(_opforHolds) exitWith {
        // Before the split: the garrison is about to be walked off and the zone has changed hands, and
        // either ends what the capture test was judging. A live flag surviving into this reads a pack-up
        // as a garrison beaten.
        [_key] call fnc_zone_garrison_dropped;
        // The pool goes with the live flag: OPFOR no longer own this ground, so there is nothing to
        // reinforce and no owed reserve to count. A retake reseeds it from the scratch ledger
        // fnc_opfor_cap seeds to 0.3 survival.
        [_key] call DUWS_fnc_garrisonReserveClear;
        private _leftovers = [_key, _pos] call DUWS_fnc_zoneSendOff;
        [_key, "withdrawing"] call fnc_site_roster_clear;
        ([_key, "withdrawing"] call fnc_site_roster) append _leftovers;
        _o set ["withdrawing", true];
        _o set ["awake", false];
        // Re-latched, because a retake is not the clean start it looks like. EAST SEIZED only
        // promises BLUFOR are outside the trigger radius; the arrival test reaches 400 m further, so
        // a player who has backed off the objective but is still on the approach is near by its
        // reckoning and would have the new garrison raised in front of them.
        _o set ["awaitVacate", true];
        // The attrition this zone carried is left as it stands. Resetting it to full here handed the
        // player's grinding straight back the moment they lost the ground again; fnc_opfor_cap
        // floors the figure when the flip actually happens.
        if (count _leftovers > 0) then {
            ["INFO", "STREAM", format ["%1 lost; %2 surviving garrison man/men ordered off",
                _key, count _leftovers]] call fnc_log;
        };
    };

    // Streamed out once the ring has been empty for the grace period. The grace restarts every time
    // BLUFOR are seen: testing once at the timer mark would pin the zone permanently if anyone
    // happened to be inside at that instant, so an assault lasting longer than the timer would leave
    // the zone standing for the rest of the campaign.
    if (!_here && {(_o get "emptySince") >= 0}
        && {diag_tickTime > (_o get "emptySince") + (_o get "grace")}) exitWith {
        // What the player left is already in the ledger -- each wiped group recorded its token as it
        // fell, and the survivors of groups that were not wiped come back whole. So the teardown only
        // marks the garrison no longer live and collects the men; there is nothing to record here.
        [_key] call fnc_zone_garrison_dropped;
        // The shared collection: men by roster, their vehicles once nothing living is aboard, and
        // the groups they empty. A town streams out by the same rules, so the rules live in one
        // place rather than in two copies that can drift.
        [_key] call fnc_site_collect;
        [_key] call DUWS_fnc_zoneStow;
        _o set ["awake", false];
    };
}]];
