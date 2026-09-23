// Server-only. Called once from server_fnc_init, after the site store and the zone state file it reads.
// One hook set shared by every zone (key, position, radius as args) replaces two permanent threads
// per zone -- the streaming loop and fnc_createzone's tail poll; the raise flag is their handshake, kept.
if (!isServer) exitWith {};

// Where a raise files its result for the tick to adopt. Unset while the worker is in flight.
#define ZONE_RAISE_SLOT(K) format ["DUWS_zoneRaise_%1", K]

#define STATIC_DROP_ATTEMPTS 5
#define STATIC_SETTLE_WAIT 2

// Clearance is not slack: drops are measured from the composition-recorded centre, and a gun
// recorded lying on its side has that centre roughly half its standing height lower -- without it, early attempts drop an upright gun into ground it still has to clear.
#define STATIC_DROP_BASE 0.25
#define STATIC_DROP_STEP 0.1

// A gun that settled tipped is on ground that tips it, not merely sunk -- a straight-down re-drop
// lands on the same edge, so each failed round widens the re-drop position instead.
#define STATIC_SHUFFLE_STEP 0.6

// Lean threshold (~26 degrees off vertical): past this the shuffle re-drops on a nudged x/y rather
// than forcing the gun upright where it landed. Looser than vertical on purpose -- siting caps ground at ~19 degrees, and a gun on that legal slope must still read as standing.
#define STATIC_STANDING_DOT 0.9

// Cosine of ~45 degrees: below it the engine won't keep a gunner seated. Looser than
// STATIC_STANDING_DOT on purpose -- it only guards the prefab crewing path, whose guns are placed on prepared ground and never shuffle-hunted.
#define STATIC_UPRIGHT_DOT 0.7

// Dropped rather than placed: a gun settled into terrain/clutter refuses its gunner memory point
// silently, and one that goes over is emptied by the engine and stays that way. Starting higher each attempt walks it out of whatever it sank into; standing it up first means it never begins the fall on its side.
DUWS_fnc_dropStatic = {
    params ["_gun", "_base", "_height"];
    // No heal here: the caller holds the gun undamageable for the whole run, so a landing that once wrecked it now only shoves it.
    // Only heading survives a fall worth keeping; a gun that went over has none -- its dir points into
    // the ground, and setVectorDirAndUp against a vertical up gets two near-parallel vectors it can't orient from. North is an arbitrary but safe fallback -- a gun facing the wrong way still traverses onto targets.
    private _dir = vectorDir _gun;
    private _flat = [_dir select 0, _dir select 1, 0];
    if (vectorMagnitude _flat < 0.1) then { _flat = [0, 1, 0] };
    _gun setVectorDirAndUp [vectorNormalized _flat, [0, 0, 1]];
    // Set after the rotation, which displaces the object -- same order fnc_duws_deploy uses. World
    // coordinates throughout, so a gun on a bunker roof is lifted off it rather than dropped through to the terrain.
    _gun setPosWorld (_base vectorAdd [0, 0, _height]);
    // Enabled last, so the fall starts from the position just written, not wherever a frame boundary
    // left the gun mid-placement. Needed because prefabs build weapons with simulation off and re-enable only listed classnames -- one missed would hang at drop height instead of falling.
    _gun enableSimulationGlobal true;
};

// moveInGunner reports nothing, so the readback off the gun is the only proof it worked -- refused
// silently by a settled/clutter-clipped gun, or one on its side. This once left soldiers standing beside spawned, rostered, uncrewed guns for a whole campaign: garrisoned on paper but not in fact.
DUWS_fnc_seatStatic = {
    params ["_gun", "_unit"];
    // Freeze, seat, thaw -- not seat into a running gun. A gunner moved into an already-simulated static
    // keeps a dead turret that only fires down its placed heading. Zone prefabs crew in this order for the same reason; the drop above needs simulation on to fall, so the settled gun is re-frozen for the seat and thawed right after.
    if (((vectorUp _gun) select 2) > STATIC_UPRIGHT_DOT) then {
        _gun enableSimulationGlobal false;
        // Snapped dead upright before the gunner takes it: the gate above passes leans up to 45 degrees,
        // and thawing a crewed gun at that lean is what leaves it lying on its side. Done while frozen -- the thaw below settles the small gap the rotation opens under the base, settling vertical rather than back onto the old lean.
        _gun setVectorUp [0, 0, 1];
        _unit moveInGunner _gun;
        _gun enableSimulationGlobal true;
    };
    !isNull _unit && {gunner _gun isEqualTo _unit}
};

// Rounds over every gun, not gun by gun: a drop can only be read once settled, so one wait covers
// every gun in the air -- a six-gun zone costs the same seconds as one gun. The lean is read after the settle, not the seat: a snapped-upright gun on tipping ground would otherwise read as seated and then fall over crewed.
DUWS_fnc_manStatics = {
    params ["_guns", "_grp"];
    // Indexed off the spawned group, not assumed one-to-one: a group that came back short would
    // otherwise throw here every despawn cycle for the rest of the campaign.
    private _men = units _grp;
    private _pending = [];
    {
        // Undamageable for the whole run of drops, so a hard landing only shoves the gun instead of
        // wrecking it and forcing a rebuild.
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
            // Replaced rather than abandoned: the gun is a defence the zone still counts on, and the
            // man may have been shot over the seconds the drops take.
            if (!alive _unit) then {
                _unit = _grp createUnit [opfor_SOLDIER_X, getPos _gun, [], 0, "NONE"];
            };
            private _placed = ((vectorUp _gun) select 2) > STATIC_STANDING_DOT
                && {[_gun, _unit] call DUWS_fnc_seatStatic};
            if (!_placed) then {
                // findEmptyPosition tests both object collision and terrain slope, so probing it hunts
                // a spot the gun actually stands on. Keeps the world Z so drop-height math holds; [] (nothing clear nearby) leaves the base rather than trade down to worse ground.
                private _shuffle = [_base select 0, _base select 1] findEmptyPosition [0.5, STATIC_SHUFFLE_STEP * _drop, typeOf _gun];
                if !(_shuffle isEqualTo []) then { _base = [_shuffle select 0, _shuffle select 1, _base select 2] };
                _next pushBack [_gun, _base, _unit];
            };
        } forEach _pending;
        _pending = _next;
    };

    // Damageable again regardless of seated: an emplacement the player can't destroy is worse than one
    // that placed badly, and an unmanned gun is still ground to fight over.
    { _x allowDamage true } forEach _guns;

    {
        _x params ["_gun", "_base", "_unit"];
        ["WARN", "ZONES", format ["emplacement %1 took no gunner; left unmanned",
            typeOf _gun]] call fnc_log;
        // The gun stays -- an empty emplacement is still ground the player can use. The man doesn't:
        // he's about to join the roster, and an unrostered man beside a gun he never entered denies the zone its capture while reading as a bug.
        if (!isNull _unit) then { deleteVehicle _unit };
    } forEach _pending;
};

// Seats through DUWS_fnc_seatStatic -- the same seat-then-thaw the stream re-crew uses, so gunner
// entry order can't drift between the two and leave a dead turret. Guns stand on the prefab's own prepared ground, so each is thawed in place rather than dropped from height like DUWS_fnc_manStatics does -- the one difference between the two paths.
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

// The prefab crews guns at build time and never runs again, so a stowed-then-redeployed composition
// comes back with empty guns unless re-crewed here. Skipped once BLUFOR holds the zone: the emplacements are then the player's, the same reason zone compositions persist rather than release on capture.
DUWS_fnc_zoneManStatics = {
    params ["_pos", "_key"];
    if !(_pos in WARCOM_zones_controled_by_OPFOR) exitWith {};
    private _roster = [_key] call fnc_zone_roster;
    private _statics = (DUWS_compositions getOrDefault [_key, []]) select {
        !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"}
    };

    // A gun still carrying the prefab's crew is garrison as much as a spawned one, so its gunner joins
    // the roster: that is what collects him when the zone streams out or falls.
    { _roster append (crew _x) } forEach (_statics select {count crew _x > 0});

    private _guns = _statics select {count crew _x == 0};
    if (count _guns == 0) exitWith {};
    // Every empty gun is crewed regardless of attrition: attrition thins what a garrison can field
    // (men, vehicles), and a static weapon is neither -- it's already standing. A worn-down zone therefore keeps the same guns and fewer of everything else.
    private _types = _guns apply {opfor_SOLDIER_X};
    private _spawn = _pos findEmptyPosition [0, 30, opfor_SOLDIER_X];
    if (count _spawn == 0) then { _spawn = _pos };
    private _grp = [_spawn, EAST, _types, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _grp deleteGroupWhenEmpty true;
    [_guns, _grp] call DUWS_fnc_manStatics;
    // Appended to the roster like everything DUWS_fnc_raiseGarrison raises: a blunt radius sweep has
    // no other way to know these men are garrison.
    _roster append (units _grp);
    [_grp, _pos] call bis_fnc_taskDefend;
};

// The gun is campaign property belonging to whoever holds the ground, so it stows; the man is a
// defender, so he goes -- the model divides by object type, not side.
// Crewing out happens here rather than in the garrison sweep because that sweep's man clause tests
// vehicle _x == _x, so a gunner sitting in a static keeps his seat, and stow refuses while any member is crewed.
DUWS_zoneEmplacementHooks = createHashMapFromArray [
    ["wake", { params ["_key", "_o"]; [([_key] call fnc_site_at) get "pos", _key] call DUWS_fnc_zoneManStatics }],
    ["sleep", { params ["_key", "_o"];
        {
            if (_x isKindOf "StaticWeapon") then { deleteVehicleCrew _x };
        } forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
    }]
];

// Stowed, never deleted: rebuilding from scratch would restore the damage the player did, and the
// emplacements become the player's own the moment they take the ground.
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

// Driven, not polled, because it's ordered: crews must be out of the guns before the composition
// holding them can be stowed.
DUWS_fnc_zoneStow = {
    params ["_key"];
    [_key, [_key, "emplacement"] call fnc_site_occupant] call (DUWS_zoneEmplacementHooks get "sleep");
    [_key, [_key, "structure"] call fnc_site_occupant] call (DUWS_zoneStructureHooks get "sleep");
    // Reserve pool is per-awake-session: losses were recorded live as groups fell, so there's nothing
    // to fold in on the way out. Reseeded by fnc_zone_spawn on the next raise, so a stowed zone reads no owed reserve and comes back consistent with the ledger it packed up with.
    [_key] call DUWS_fnc_garrisonReserveClear;
};

// Dispatched, not run inline: a full composition takes up to a couple of minutes to place, and the
// poller holds the clock of every other site.
DUWS_fnc_zoneRaiseWorker = {
    params ["_key", "_pos", "_size"];
    // Confirmed after a 5s pause rather than on first perimeter contact, so a transiting helicopter or
    // a patrol that turns back doesn't trigger a full rebuild for someone already leaving. Air uses the same terms the poller's wake does: a committed aircraft holds the raise, where discounting anything airborne would confirm an air wake straight back off.
    sleep 5;
    private _reach = _size + DUWS_streamArrivalMargin;
    private _confirmed = [_pos, _reach, 2, DUWS_zoneAirRing, DUWS_zoneAirCommitSpeed, true] call fnc_site_bluforOrAir;
    // The same second reading the poller's wake took, so the two cannot disagree and strand the site.
    if (!_confirmed && {([_key] call DUWS_fnc_garrisonSideOf) isEqualTo "BLU"}) then {
        _confirmed = ([_pos, _reach, EAST] call fnc_side_count_at) > 0;
    };
    if (!_confirmed) exitWith {
        missionNamespace setVariable [ZONE_RAISE_SLOT(_key), false];
    };

    // Cleared here rather than where the band is raised: the turret crews below are garrison too, and
    // clearing after them would drop them.
    [_key] call fnc_site_roster_clear;
    // Structure, then emplacement, then men: units must not spawn into ground about to have a bunker
    // on it, and turrets must exist before anyone mans them.
    [_key, [_key, "structure"] call fnc_site_occupant] call (DUWS_zoneStructureHooks get "wake");
    [_key, [_key, "emplacement"] call fnc_site_occupant] call (DUWS_zoneEmplacementHooks get "wake");
    [_pos, _size, _key] call fnc_zone_spawn;
    missionNamespace setVariable [ZONE_RAISE_SLOT(_key), true];
};

// Each branch below ends the pass for this zone: they're mutually exclusive states of one garrison.
DUWS_zoneHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    private _size = _site get "radius";
    // Who the ground answers to now, against "holder" -- who the men standing on it were raised for.
    private _holder = [_key] call DUWS_fnc_garrisonSideOf;

    // Not a garrison state, so it ends nothing: a retake raises the new garrison beside the old one's survivors.
    [_key] call DUWS_fnc_garrisonLeftoverSweep;

    // A raise in flight owns this zone until it reports.
    if (_o get "raising") exitWith {
        private _res = missionNamespace getVariable [ZONE_RAISE_SLOT(_key), nil];
        if (isNil "_res") exitWith {};
        missionNamespace setVariable [ZONE_RAISE_SLOT(_key), nil];
        _o set ["raising", false];
        _o set ["awake", _res];
    };

    if !(_o get "awake") exitWith {
        // Tier, not ownership: tier 0 is ground with no garrison on it, which is where BLUFOR start.
        if (_here && {!(_o get "awaitVacate")} && {([_key] call fnc_zone_tier) > 0}) then {
            _o set ["holder", _holder];
            _o set ["raising", true];
            missionNamespace setVariable [ZONE_RAISE_SLOT(_key), nil];
            [_key, _pos, _size] spawn DUWS_fnc_zoneRaiseWorker;
        };
    };

    // The ground changed hands under a standing garrison, in either direction. Composition isn't
    // despawned -- the emplacements belong to whoever holds the ground now.
    if ((_o getOrDefault ["holder", "OPF"]) isNotEqualTo _holder) exitWith {
        // Called before the release: the zone has changed hands, and a live flag surviving past this
        // reads a pack-up as a garrison beaten.
        [_key] call fnc_zone_garrison_dropped;
        // The men who held it no longer own this ground, so there's nothing to reinforce.
        [_key] call DUWS_fnc_garrisonReserveClear;
        private _left = [_key] call DUWS_fnc_garrisonRelease;
        _o set ["awake", false];
        // Re-latched because a retake isn't a clean start: a player backed off the objective but still
        // on approach can be within the wider arrival test and would see the new garrison raise in front of them.
        _o set ["awaitVacate", true];
        // Attrition is left as-is, not reset: resetting it here would hand the player's grinding
        // straight back the moment they lose the ground again -- fnc_opfor_cap floors it when the flip actually happens.
        if (_left > 0) then {
            ["INFO", "STREAM", format ["%1 lost; %2 surviving garrison man/men fight on", _key, _left]] call fnc_log;
        };
    };

    // Grace restarts every time BLUFOR are seen: testing once at the timer mark would pin the zone
    // permanently if anyone happened to be inside at that instant. An assault lasting longer than the timer would otherwise leave the zone standing for the rest of the campaign.
    if (!_here && {(_o get "emptySince") >= 0}
        && {diag_tickTime > (_o get "emptySince") + (_o get "grace")}) exitWith {
        // Nothing to record here: each wiped group already recorded its token as it fell, and
        // survivors of groups not wiped come back whole -- this just marks the garrison no longer live.
        [_key] call fnc_zone_garrison_dropped;
        // Shared with the town streaming path, so the collection rules live in one place rather than
        // two copies that can drift.
        [_key] call fnc_site_collect;
        [_key] call DUWS_fnc_zoneStow;
        _o set ["awake", false];
    };
}]];
