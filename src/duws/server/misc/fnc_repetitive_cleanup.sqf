// Locality: server -- inherited from server/server_init.sqf.
// Deletes what play leaves behind -- bodies, wrecks, empty or immobilised vehicles, dropped weapons, spent
// smoke, crates, parachutes -- on one lifetime (DUWS_CleanupLifetime). Always on: teardowns hand it their
// live leftovers, so it can never be off. Anything flagged persistent (fnc_duws_keep, dropped by
// fnc_duws_release) is never touched. Planted explosives are excluded on purpose -- player-placed and
// meant to be returned to, not litter.

if (!isServer) exitWith {};

// Nothing inside this of a player is deleted, however old it is. A wreck or a body blinking out on
// screen reads as a bug, and the point of a lifetime is that it expires out of sight. Expired but
// watched stays and is retried, so it goes once they leave rather than never.
#define KEEP_RADIUS 300

// Bases are cleanup exclusion zones: an intact vehicle parked within DUWS_base_keep_radius of the HQ,
// a FOB or the MHQ is never collected. This is the supported way to keep a vehicle, which is why no
// vehicle carries the persistence flag any more -- drive it home instead of tagging it in script.
// Deliberately narrower than "nothing inside is collected": wrecks, bodies and dropped kit still go,
// or a base that gets attacked would silt up with exactly what the sweep exists to remove. The radius
// is a global rather than a #define here because fnc_baseRangeMarker.sqf draws it on the map, and the
// ring and the sweep must not be able to name different distances.

// Passes between census log lines. The census is the one part of this that cannot be checked
// offline -- allMissionObjects is documented around mission- and script-created objects, and a
// dropped rifle's holder is created by the engine. A zero here with combat behind you means the
// census does not see them and discovery has to go back to searching from unit positions.
#define LOG_EVERY 30

private _lifetime = [_this, 0, 0, [0]] call BIS_fnc_param;
// Never disabled: teardowns hand their live leftovers to this sweep, so a stopped one would strand
// them for good. A stray 0 from an old param or save is floored to the shortest real option.
_lifetime = _lifetime max 300;

// Collected by class, and spared only by the persistent flag. Opt out rather than opt in, so a drop
// added later is swept without anyone having to remember to register it. Bodybags are listed by every
// name they go by rather than one base class, and the ACE one is listed unconditionally: a class no
// loaded mod defines simply censuses to nothing, so naming it costs a query when ACE is absent and
// catches the bags when it is not.
private _litterClasses = ["WeaponHolder", "GroundWeaponHolder", "WeaponHolderSimulated",
    "SmokeShell", "ReammoBox_F", "ParachuteBase",
    "Land_BodyBag_01_base_F", "Land_BodyBag_01_F", "Land_BodyBag_01_black_F",
    "Land_BodyBag_01_blue_F", "ACE_bodyBagObject"];

// A building never reaches the sweep by census -- it is Static, not AllVehicles. The engine also
// never damages one in place: it deletes the object and spawns a replacement, so the tracked member
// goes null and its key with it. The replacement has to be re-filed as it appears or the building
// drops out of its composition -- orphaned on the map, neither stowable nor releasable with the zone.
addMissionEventHandler ["BuildingChanged", {
    params ["_old", "_new", "_isRuin"];
    private _key = _old getVariable "DUWS_compKey";
    if (isNil "_key") exitWith {};
    // Re-file the replacement under the same key, for a damage stage and a ruin alike: it stays
    // persistent and streams and releases with the zone, and re-filing prunes the null slot _old
    // left behind. A building's ruin is part of the zone, not litter -- a central structure blinking
    // out reads worse than its wreck left standing.
    [_new, _key] call fnc_duws_keep;
    if (_isRuin) then { _new setVariable ["DUWS_ruin", true] };
}];

// Objects handed over explicitly, chiefly by fnc_duws_release retiring a composition. A standing
// list rather than part of the census: a released hardpoint core is a static weapon, and the
// abandoned-vehicle clause below deliberately never collects those, so nothing would look at it
// again. Small by nature -- it holds retired compositions, not litter.
private _disposed = [];
private _pass = 0;

while {true} do {
    // Interruptible interval, not a flat sleep: a forced sweep asked for just after a pass began
    // waiting would otherwise sit out the whole interval, and a debug button that does nothing
    // for ten seconds reads as broken.
    private _nextPass = time + 10;
    waitUntil { sleep 0.5; DUWS_cleanup_force || {time >= _nextPass} };

    // Only cleanup thread in the campaign: an unhandled throw in a spawned loop terminates it for the
    // whole session, so one poisoned object would stop all deletion -- bodies and wrecks included.
    // Catch per pass instead, so a bad object costs a single sweep, not the thread. Body runs inside
    // this try at its existing indent.
    try {
    private _now = time;
    private _candidates = [];

    // Rebuilt every pass rather than cached: FOBs are raised and lost mid-campaign, and the MHQ
    // is a vehicle that drives around. PosOfBLUHQ is empty until the player places the HQ.
    private _bases = [];
    if (count PosOfBLUHQ > 0) then { _bases pushBack PosOfBLUHQ };
    { _bases pushBack _x } forEach Array_of_FOBpos;
    private _mhq = missionNamespace getVariable ["MHQ1", objNull];
    if (!isNull _mhq) then { _bases pushBack (getPos _mhq) };

    // Timed because each allMissionObjects walks every mission object in one engine call, a frame stall
    // the scheduler cannot slice.
    private _t0 = diag_tickTime;
    {
        private _type = _x;
        _candidates append (allMissionObjects _type);
    } forEach _litterClasses;
    private _censusMs = round ((diag_tickTime - _t0) * 1000);
    // Deduped in one engine call rather than by a unique insert per element: pushBackUnique rescans
    // the list it is building on every insert, so the cost was quadratic in the litter lying on the
    // map -- a few hundred holders and bodies after a firefight is tens of thousands of comparisons a
    // pass. The census has to come after it -- the bodybag classes are listed beside their own base
    // class, so a raw append reports those objects more than once.
    _candidates = _candidates arrayIntersect _candidates;
    private _census = count _candidates;

    _candidates append allDeadMen;
    _candidates append ((allDead - allDeadMen) select { _x == vehicle _x });

    // A vehicle counts as in use -- and so is spared -- when a living player, or a player's AI
    // squadmate, is aboard, or when living AI crew still has a mobile hull under them. A crewed hull
    // that cannot move is wreckage its crew never bailed from, not a vehicle in service, so it ages
    // out on the clock like an empty one, which is what collects an immobilised-but-manned vehicle.
    // A static is never mobile, so it is spared on any living crew instead: collecting a manned
    // emplacement would strip a held zone.
    private _inUse = {
        params ["_v"];
        if ((crew _v) findIf {alive _x && {isPlayer _x || {(units group _x) findIf {isPlayer _x} >= 0}}} >= 0) exitWith { true };
        ({alive _x} count crew _v > 0) && {_v isKindOf "StaticWeapon" || {canMove _v}}
    };

    // Idling and immobilised vehicles: not-in-use is the whole test now. They are still held by
    // DUWS_base_keep_radius and by the persistent flag, the same two things that hold everything
    // else. Statics stay excluded: a turret is unmanned by design, and collecting those would take a
    // zone's emplacements the moment its captor steps away. Returning to service clears the clock,
    // unless the vehicle was retired deliberately.
    {
        if (!(_x isKindOf "StaticWeapon") && {!(_x call _inUse)}) then {
            _candidates pushBack _x;
        } else {
            // A flagged vehicle carries a delete order; returning to service must not clear its clock
            // (that reset exists to spare a vehicle put back into use, the opposite case).
            if (!(_x in _disposed) && {!(_x getVariable ["DUWS_binMe", false])}) then {
                _x setVariable ["DUWS_binAt", nil];
            };
        };
    } forEach vehicles;

    { if (count units _x == 0) then { deleteGroup _x } } forEach allGroups;

    // Explicit lifetimes win over the shared one: fnc_duws_release asks for its own.
    {
        _x params ["_obj", "_ttd"];
        if (!isNull _obj) then {
            _obj setVariable ["DUWS_binAt", _now + _ttd];
            _disposed pushBackUnique _obj;
        };
    } forEach DUWS_disposables;
    DUWS_disposables = [];
    _disposed = _disposed select {!isNull _x};

    // Read before the walk and cleared here rather than by the setter: the pass it woke is the only
    // place that knows it was served, and leaving it set would wake every pass from now on. A forced
    // pass treats every deadline as elapsed, which is the whole point of it -- waiting out the
    // lifetime is what the tester is trying to skip. KEEP_RADIUS and persistent still hold: the first
    // stops litter blinking out in front of someone, the second tells a supply drop from the HQ crate
    // of the same class.
    private _force = DUWS_cleanup_force;
    DUWS_cleanup_force = false;
    private _tracked = 0;
    private _binned = 0;

    // One dedupe over the union rather than a unique insert per element upstream. It also
    // collapses what the separate censuses overlap on -- a dead unmanned vehicle is reported by
    // allDead and by vehicles both -- which the per-element form was absorbing silently.
    private _sweep = _candidates + _disposed;
    _sweep = _sweep arrayIntersect _sweep;

    // The deadline lives on the object rather than in a list beside it. A list costs a linear
    // search per object per pass to find its entry, and has to be compacted afterwards; a
    // variable is a direct read and is deleted along with the object it belongs to.
    {
        private _obj = _x;
        // Destruction outranks the flag. Persistence protects a standing composition, and a
        // wreck is not one -- a burnt-out turret left forever is worse than the gap where it
        // stood. This does not replace composition tracking: the undamaged sandbags around
        // that turret are still collected by their key on release, never by their own state.
        if (!isNull _obj && {!alive _obj || {!(_obj getVariable ["persistent", false])}}) then {
            // Stamped even on a forced pass, so litter spared by KEEP_RADIUS still carries a
            // deadline and expires normally once the player moves off.
            private _binAt = _obj getVariable "DUWS_binAt";
            if (isNil "_binAt") then {
                _binAt = _now + _lifetime;
                _obj setVariable ["DUWS_binAt", _binAt];
            };
            // In-use spares it as surely as a nearby player does (see _inUse): a mobile AI-crewed
            // vehicle, or a released emplacement a squadmate mans, stays. A crewed hull that cannot
            // move no longer counts, so it is collectable here. Corpses, wrecks and litter report no
            // living crew and drop straight through.
            if ((_force || {_binAt <= _now})
                && {(allPlayers findIf {_x distance _obj < KEEP_RADIUS}) < 0}
                && {!(_obj call _inUse)}) then {
                // Checked last: it is the only test that walks a list, and by here everything
                // else has already agreed the object should go. Intact vehicles only, so a
                // player can park anything driveable at a base and keep it.
                private _parked = alive _obj && {_obj isKindOf "AllVehicles"}
                    && {(_bases findIf {_obj distance _x < DUWS_base_keep_radius}) >= 0};
                if (_parked) then {
                    _tracked = _tracked + 1;
                } else {
                    // Clear any AI still seated before the hull -- an immobilised vehicle reaches
                    // here manned, and deleteVehicle alone would strand its crew in a null vehicle.
                    if (!(_obj isKindOf "CAManBase") && {count crew _obj > 0}) then { deleteVehicleCrew _obj };
                    deleteVehicle _obj;
                    _binned = _binned + 1;
                };
            } else {
                _tracked = _tracked + 1;
            };
        };
    } forEach _sweep;

    // Orphan: a living entity owned by a mission no longer live. It spawned on a stagger that outran the
    // win, after fnc_mission_cleanup's single pass, so no teardown will ever flag it. Swept on the same
    // clock as a flagged unit, so KEEP_RADIUS still holds it off-screen. Units handed to the player are
    // never claimed (owner -1), so this never reaches them.
    private _liveTok = missionNamespace getVariable ["DUWS_mission_token", 0];
    private _noLiveMission = missionNamespace getVariable ["Mission_available", true];
    private _deadOwner = {
        private _t = _this getVariable ["DUWS_missionOwner", -1];
        _t >= 0 && {_noLiveMission || {_t != _liveTok}}
    };

    // Flagged living entities: a delete order stamped by a teardown, not litter found by class. Own
    // pass because every shared-sweep spare would protect them -- a living man is his own crew, and a
    // man and a mission vehicle both read as AllVehicles the base-keep radius would hold. Only
    // KEEP_RADIUS, the deadline and a forced sweep apply; the flag is itself the not-persistent
    // decision. Dead flagged men ride the allDeadMen census above.
    {
        private _unit = _x;
        if (!isNull _unit && {alive _unit} && {(_unit getVariable ["DUWS_binMe", false]) || {_unit call _deadOwner}}) then {
            private _binAt = _unit getVariable "DUWS_binAt";
            if (isNil "_binAt") then { _binAt = _now + _lifetime; _unit setVariable ["DUWS_binAt", _binAt] };
            // _unit, not _x, inside findIf: the engine binds _x to the player per element there.
            if ((_force || {_binAt <= _now})
                && {(allPlayers findIf {_x distance _unit < KEEP_RADIUS}) < 0}
                && {(units group _unit) findIf {isPlayer _x} < 0}) then {
                if (_unit isKindOf "CAManBase") then { deleteVehicle _unit }
                    else { deleteVehicleCrew _unit; deleteVehicle _unit };
                _binned = _binned + 1;
            } else {
                _tracked = _tracked + 1;
            };
        };
    } forEach (allUnits + vehicles);

    if (_force) then {
        ["INFO", "CLEANUP", format ["forced sweep: %1 deleted, %2 held inside %3 m",
            _binned, _tracked, KEEP_RADIUS]] call fnc_log;
    };

    _pass = _pass + 1;
    if (_pass % LOG_EVERY == 0) then {
        ["INFO", "CLEANUP", format ["litter census %1, %2 tracked, census %3 ms", _census, _tracked, _censusMs]] call fnc_log;
    };
    } catch {
        ["ERROR", "CLEANUP", format ["pass threw, thread held alive: %1", _exception]] call fnc_log;
    };
};
