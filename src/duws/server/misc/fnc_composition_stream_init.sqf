// Composition membership and the stow/deploy streaming gate.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

// Hand an object to the map cleanup, to be deleted _ttd seconds from now once no player is
// near it. Opt-in by whoever created the object, because class cannot tell these apart: a
// supply drop and the HQ arsenal crate are both B_supplyCrate_F, and three side missions use
// crate classes for their objectives. Only the code that made the thing knows it is litter.
// Callable from anywhere -- a client call forwards itself to the server, which owns the sweep.
fnc_duws_disposeAfter = {
    params ["_obj", ["_ttd", 1800]];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_disposeAfter", 2] };
    // Living entities are out of scope here -- they have their own spawn and despawn logic.
    // Refused rather than trusted to callers: the sweep spares anything with living crew, and
    // crew of a man on foot is the man, so one reaching the disposal list would never leave it.
    if (_obj isKindOf "CAManBase") exitWith {};
    DUWS_disposables pushBack [_obj, _ttd];
};

// Mark an object as part of a standing composition -- the BLUFOR HQ, a FOB, a zone prefab, a
// hardpoint. Tagged persistent so no cleanup sweep touches it, and filed under _key so the
// whole composition can be released together.
// Membership is tracked rather than inferred, because inference cannot work: when a hardpoint
// is wrecked its sandbags and camo net are undamaged props, and no test applied to those
// objects -- dead, immobile, litter class -- would ever collect them. Only the key knows they
// belonged to something that is now gone.
// One object, one key. Nothing enforces it, but release drops the persistent flag
// unconditionally, so filing something under two keys means retiring either of them strips the
// protection while the other still lists it as a member.
// _pinned marks a member whose effect depends on its existing rather than on being looked at --
// an artillery piece, a mortar, an AA gun. Streaming those removes a capability instead of
// deferring a cost: an aircraft crosses the gate's radius in a few seconds, so a stowed AA gun
// would never engage anything. Declared by the caller rather than tested by class at stow time,
// because only the code that placed the object knows why it is there, and a class test would have
// to be kept in step with every faction mod's turret names. Local: only the server stows.
fnc_duws_keep = {
    params ["_obj", ["_key", "world"], ["_pinned", false]];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_keep", 2] };
    // Props and vehicles only. A unit's presence on the map is decided by its own spawn and
    // despawn logic, and a composition that owned one could not release it without fighting
    // that logic for control of the same entity.
    if (_obj isKindOf "CAManBase") exitWith {};
    _obj setVariable ["persistent", true, true];
    if (_pinned) then { _obj setVariable ["DUWS_noStow", true] };
    // Filing anything under a retired key revives it, so a hardpoint rebuilt at the same rounded
    // coordinates as a cleared one does not inherit its predecessor's retirement.
    private _wasRetired = DUWS_retired find _key;
    if (_wasRetired >= 0) then { DUWS_retired deleteAt _wasRetired };
    // Nulls pruned on the way in: a FOB rebuild deletes its old ring outright rather than
    // releasing it, so without this the key accumulates dead references for the whole campaign.
    private _members = (DUWS_compositions getOrDefault [_key, []]) select {!isNull _x};
    _members pushBackUnique _obj;
    DUWS_compositions set [_key, _members];
};

// The composition is gone: drop the protection from every part and hand the lot to the sweep.
// Deletion still respects the keep-radius, so a hardpoint wrecked under the player's nose
// clears once they leave rather than in front of them.
fnc_duws_release = {
    params ["_key", ["_ttd", 300]];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_release", 2] };
    {
        _x setVariable ["persistent", false, true];
        [_x, _ttd] call fnc_duws_disposeAfter;
    } forEach (DUWS_compositions getOrDefault [_key, []]);
    DUWS_compositions deleteAt _key;
    // Stowed members do not exist, so there is nothing to hand the sweep -- but the records have to
    // go, or a retired composition redeploys intact the next time someone walks up to it.
    DUWS_stowed deleteAt _key;
    // Terminal, and readable as such. A gate cycling this composition needs to know it is finished
    // rather than infer it from the key being absent, which is equally true before build-out ran.
    DUWS_retired pushBackUnique _key;
};

// Take a composition off the map, holding the data needed to put it back. Distinct from
// fnc_duws_release: release retires a composition for good and drops its key, where stow keeps the
// key so the same one can return.
// Deletion is immediate rather than handed to the sweep, because removing the entity is the whole
// point -- a stowed member has to leave allMissionObjects, the curator's editable set and the
// spatial index at once, and the sweep's keep-radius would hold it instead.
// Refuses while a streamable member is crewed. The zone stow leaves gunners sitting in static
// weapons alive (its despawn pass tests vehicle _x == _x), so stowing regardless would delete a
// manned gun and strand the AI where its turret was. Retrying on the next cycle is the safe
// failure. Pinned members are excluded from that test on purpose: they keep their crew by design,
// so counting them would block their composition from ever stowing.
fnc_duws_stow = {
    params ["_key"];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_stow", 2] };
    if !(_key in DUWS_compositions) exitWith { false };
    private _members = (DUWS_compositions getOrDefault [_key, []]) select {!isNull _x};
    private _pinned = _members select {_x getVariable ["DUWS_noStow", false]};
    private _streamable = _members - _pinned;
    // Logged where the reason is known: the streaming caller only sees a bare false, and a
    // composition that refuses stays on the map for a whole spawn/despawn cycle with nothing to
    // say why. Unreachable through the zone path -- DUWS_fnc_zoneStow crews out its statics first and
    // nothing else in a composition takes crew -- so a line here means something unmodelled put a
    // man in one, which is worth a WARN rather than a routine note.
    private _crewed = _streamable findIf {({alive _x} count crew _x) > 0};
    if (_crewed >= 0) exitWith {
        ["WARN", "STREAM", format ["stow %1 refused: %2 still crewed",
            _key, typeOf (_streamable select _crewed)]] call fnc_log;
        false
    };
    private _records = [];
    {
        // Dead members go unrecorded, so what a player destroyed stays destroyed. A ruined
        // building is a separate object the BuildingChanged handler has already claimed.
        if (alive _x) then {
            // Cargo travels with the crate. Contents are rolled by fnc_fill_ammobox and drawn down
            // by players, so replaying the classname alone hands back a crate someone emptied.
            private _cargo = [];
            if (_x isKindOf "ReammoBox_F") then {
                _cargo = [getWeaponCargo _x, getMagazineCargo _x,
                    getItemCargo _x, getBackpackCargo _x];
            };
            // Simulation and damage state are recorded because the prefabs set them per object --
            // props ship with simulation off and several are invulnerable. A deploy that guessed
            // would quietly re-simulate every prop on the map.
            _records pushBack [typeOf _x, getPosWorld _x, [vectorDir _x, vectorUp _x],
                simulationEnabled _x, isDamageAllowed _x, _cargo];
        };
        deleteVehicle _x;
    } forEach _streamable;
    // Pinned members never left, so the key keeps its place in DUWS_compositions holding just
    // them. Dropped entirely when nothing was pinned, so the common case stays a single entry.
    if (count _pinned == 0) then {
        DUWS_compositions deleteAt _key;
    } else {
        DUWS_compositions set [_key, _pinned];
    };
    DUWS_stowed set [_key, _records];
    true
};

// Rebuild a stowed composition. Members come back as new objects, so nothing holding a reference
// to the old ones survives a stow -- the key is the only identity a composition has across one,
// which is why membership is re-filed through fnc_duws_keep rather than restored.
fnc_duws_deploy = {
    params ["_key"];
    if (!isServer) exitWith { _this remoteExec ["fnc_duws_deploy", 2] };
    {
        _x params ["_class", "_pos", "_vectorDirUp", "_sim", "_damageAllowed", "_cargo"];
        private _obj = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
        // Frozen across the placement whatever it was stowed as, and restored once it stands where
        // the record puts it. This loop is scheduled code, so the engine can suspend it between any
        // two statements, and a member still simulated over a frame boundary settles or slides off
        // the position just written to it. A member that keeps its simulation -- a static weapon,
        // a watchtower -- is a live physics body while that happens, and one resolving a teleport
        // against what it now intersects can go over: a gun on its side costs the zone the
        // emplacement and leaves its gunner sitting in it.
        _obj enableSimulationGlobal false;
        // Placed again after creation: createVehicle reads its position as AGL, and the record
        // holds world coordinates. Without this a prop on a slope returns metres into the hill.
        _obj setPosWorld _pos;
        _obj setVectorDirAndUp _vectorDirUp;
        // Rotating displaces the object, so the position has to be written a second time after it.
        // The prefabs that place these props do the same around their setDir for the same reason.
        _obj setPosWorld _pos;
        _obj enableSimulationGlobal _sim;
        _obj allowDamage _damageAllowed;
        if (count _cargo > 0) then {
            clearWeaponCargoGlobal _obj;
            clearMagazineCargoGlobal _obj;
            clearItemCargoGlobal _obj;
            clearBackpackCargoGlobal _obj;
            (_cargo select 0) params ["_wTypes", "_wCounts"];
            (_cargo select 1) params ["_mTypes", "_mCounts"];
            (_cargo select 2) params ["_iTypes", "_iCounts"];
            (_cargo select 3) params ["_bTypes", "_bCounts"];
            { _obj addWeaponCargoGlobal [_x, _wCounts select _forEachIndex] } forEach _wTypes;
            { _obj addMagazineCargoGlobal [_x, _mCounts select _forEachIndex] } forEach _mTypes;
            { _obj addItemCargoGlobal [_x, _iCounts select _forEachIndex] } forEach _iTypes;
            { _obj addBackpackCargoGlobal [_x, _bCounts select _forEachIndex] } forEach _bTypes;
        };
        [_obj, _key] call fnc_duws_keep;
    } forEach (DUWS_stowed getOrDefault [_key, []]);
    DUWS_stowed deleteAt _key;
};

// Debug-menu entry point for the map cleanup: sweep now, with every lifetime treated as elapsed,
// so a tester does not wait 30 min to see collection happen. The sweep's interval wait breaks on
// this flag, so it lands within half a second. Bounded by what it cannot skip -- KEEP_RADIUS and
// the persistent flag -- so the worst a client reaching it can do is bin distant litter early.
// Not published, because nothing calls it locally: the menu remoteExecs it to the server, the
// only machine holding the deadlines.
fnc_duws_forceCleanup = {
    DUWS_cleanup_force = true;
    ["INFO", "CLEANUP", "Forced sweep requested from the debug menu."] call fnc_log;
};

// Debug-menu entry point for composition streaming: stow the nearest zone, or deploy it if it is
// already stowed. Takes the caller's position because the server has no player of its own to
// measure from. Not published, for the same reason fnc_duws_forceCleanup is not.
fnc_duws_toggleNearestZone = {
    params ["_pos"];
    if (count zone_meta_array == 0) exitWith {};
    private _best = [];
    {
        private _zonePos = _x select 1;
        if (_best isEqualTo [] || {_pos distance _zonePos < _pos distance _best}) then {
            _best = _zonePos;
        };
    } forEach zone_meta_array;
    private _key = format ["zone_%1_%2", round (_best select 0), round (_best select 1)];
    if (_key in DUWS_stowed) then {
        [_key] call fnc_duws_deploy;
        ["INFO", "STREAM", format ["deployed %1", _key]] call fnc_log;
    } else {
        private _stowed = [_key] call fnc_duws_stow;
        ["INFO", "STREAM", format ["stow %1: %2", _key,
            ["refused", "done"] select _stowed]] call fnc_log;
    };
};
