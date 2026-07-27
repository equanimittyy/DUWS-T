// Locality: server -- inherited from server/server_init.sqf.
/*
    NAME: misc\fnc_repetitive_cleanup.sqf

    DESCRIPTION:
    Deletes what play leaves behind: bodies, wrecks, vehicles abandoned where they broke down,
    dropped weapons, spent smoke, supply crates and parachutes. One lifetime covers all of it,
    set by the DUWS_CleanupLifetime parameter.

    USAGE:
        [1800] spawn fnc_repetitive_cleanup;   // seconds; 0 or less disables the sweep

    Anything carrying the persistent flag is never touched, whatever its age. fnc_duws_keep
    sets that flag and files the object under a composition -- the HQ, a FOB, a zone prefab, a
    side-mission objective -- and fnc_duws_release drops it and hands the parts back here.

    Planted explosives are deliberately absent. They were listed and disabled; folding them
    into the shared lifetime would start deleting charges a player placed and meant to return
    to, which is a gameplay change rather than a cleanup one.
*/

if (!isServer) exitWith {};

// Nothing inside this of a player is deleted, however old it is. A wreck or a body blinking
// out on screen reads as a bug, and the point of a lifetime is that it expires out of sight.
// Expired but watched stays and is retried, so it goes once they leave rather than never.
#define KEEP_RADIUS 300

// Bases are cleanup exclusion zones: an intact vehicle parked this close to the HQ, a FOB or the
// MHQ is never collected. This is the supported way to keep a vehicle, which is why no vehicle
// carries the persistence flag any more -- drive it home instead of tagging it in script.
// Deliberately narrower than "nothing inside is collected": wrecks, bodies and dropped kit still
// go, or a base that gets attacked would silt up with exactly what the sweep exists to remove.
#define BASE_RADIUS 250

// Passes between census log lines. The census is the one part of this that cannot be checked
// offline -- allMissionObjects is documented around mission- and script-created objects, and a
// dropped rifle's holder is created by the engine. A zero here with combat behind you means the
// census does not see them and discovery has to go back to searching from unit positions.
#define LOG_EVERY 30

private _lifetime = [_this, 0, 0, [0]] call BIS_fnc_param;
if (_lifetime <= 0) exitWith {};

// Collected by class, and spared only by the persistent flag. Opt out rather than opt in, so a
// drop added later is swept without anyone having to remember to register it.
// Bodybags are listed by every name they go by rather than one base class, and the ACE one is
// listed unconditionally: a class no loaded mod defines simply censuses to nothing, so naming it
// costs a query when ACE is absent and catches the bags when it is not.
private _litterClasses = ["WeaponHolder", "GroundWeaponHolder", "WeaponHolderSimulated",
    "SmokeShell", "ReammoBox_F", "ParachuteBase",
    "Land_BodyBag_01_base_F", "Land_BodyBag_01_F", "Land_BodyBag_01_black_F",
    "Land_BodyBag_01_blue_F", "ACE_bodyBagObject"];

// Buildings reach the sweep only through here. They are Static rather than AllVehicles, so no
// census query returns them -- and the engine does not damage one in place, it deletes it and
// spawns a replacement, which is why the tracked member goes null and its flag with it. The ruin
// therefore has to be claimed as it appears or it is never seen again.
DUWS_cleanup_lifetime = _lifetime;
addMissionEventHandler ["BuildingChanged", {
    params ["_old", "_new", "_isRuin"];
    if !(_old getVariable ["persistent", false]) exitWith {};
    if (_isRuin) then {
        [_new, DUWS_cleanup_lifetime] call fnc_duws_disposeAfter;
    } else {
        // A damage stage, not destruction: the replacement is still part of the composition, and
        // dropping the flag here would leave the eventual ruin unrecognised.
        _new setVariable ["persistent", true, true];
    };
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
    // for ten seconds reads as broken. Gated on time rather than a counted poll so the interval
    // still tracks setTimeMultiplier exactly as the sleep it replaces did.
    private _nextPass = time + 10;
    waitUntil { sleep 0.5; DUWS_cleanup_force || {time >= _nextPass} };

    private _now = time;
    private _candidates = [];

    // Rebuilt every pass rather than cached: FOBs are raised and lost mid-campaign, and the MHQ
    // is a vehicle that drives around. PosOfBLUHQ is empty until the player places the HQ.
    private _bases = [];
    if (count PosOfBLUHQ > 0) then { _bases pushBack PosOfBLUHQ };
    { _bases pushBack _x } forEach Array_of_FOBpos;
    private _mhq = missionNamespace getVariable ["MHQ1", objNull];
    if (!isNull _mhq) then { _bases pushBack (getPos _mhq) };

    {
        private _type = _x;
        { _candidates pushBackUnique _x } forEach (allMissionObjects _type);
    } forEach _litterClasses;
    private _census = count _candidates;

    { _candidates pushBackUnique _x } forEach allDeadMen;
    { if (_x == vehicle _x) then { _candidates pushBackUnique _x } } forEach (allDead - allDeadMen);

    // Abandoned vehicles. Statics are excluded because the clause means "could be driven and no
    // longer can" -- a turret satisfies !canMove by being a turret, which made every unmanned
    // emplacement a false positive. One that regains crew or mobility has its clock cleared,
    // unless it was retired deliberately, whose deadline is not this clause's to reset.
    {
        if (!(_x isKindOf "StaticWeapon") && !canMove _x && {alive _x} count crew _x == 0) then {
            _candidates pushBackUnique _x;
        } else {
            if !(_x in _disposed) then { _x setVariable ["DUWS_binAt", nil] };
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

    // Read before the walk and cleared here rather than by the setter: the pass it woke is the
    // only place that knows it was served, and leaving it set would wake every pass from now on.
    // A forced pass treats every deadline as elapsed, which is the whole point of it -- waiting
    // out the lifetime is what the tester is trying to skip. KEEP_RADIUS and persistent still
    // hold: the first is what stops litter blinking out in front of someone, and the second is
    // what tells a supply drop from the HQ crate of the same class.
    private _force = DUWS_cleanup_force;
    DUWS_cleanup_force = false;
    private _tracked = 0;
    private _binned = 0;

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
            // Living crew spares it as surely as a nearby player does. A released emplacement
            // can be manned by an AI squadmate, and allPlayers cannot see one. Corpses, wrecks
            // and litter all report no living crew, so this only ever spares something in use.
            if ((_force || {_binAt <= _now})
                && {(allPlayers findIf {_x distance _obj < KEEP_RADIUS}) < 0}
                && {({alive _x} count crew _obj) == 0}) then {
                // Checked last: it is the only test that walks a list, and by here everything
                // else has already agreed the object should go. Intact vehicles only, so a
                // player can park anything driveable at a base and keep it.
                private _parked = alive _obj && {_obj isKindOf "AllVehicles"}
                    && {(_bases findIf {_obj distance _x < BASE_RADIUS}) >= 0};
                if (_parked) then {
                    _tracked = _tracked + 1;
                } else {
                    deleteVehicle _obj;
                    _binned = _binned + 1;
                };
            } else {
                _tracked = _tracked + 1;
            };
        };
    } forEach (_candidates + _disposed);

    if (_force) then {
        ["INFO", "CLEANUP", format ["forced sweep: %1 deleted, %2 held inside %3 m",
            _binned, _tracked, KEEP_RADIUS]] call fnc_log;
    };

    _pass = _pass + 1;
    if (_pass % LOG_EVERY == 0) then {
        ["INFO", "CLEANUP", format ["litter census %1, %2 tracked", _census, _tracked]] call fnc_log;
    };
};
