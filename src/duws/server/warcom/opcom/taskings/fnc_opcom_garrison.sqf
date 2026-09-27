// Locality: server, [] call'd at load (before any zone raises) so the raise hook can resolve it. Reconciles a
// site's reserve pool + ceiling -- a zone's or a town's, one key either way -- with OPCOM's recruited `garrison` units, so a recruit stands or reinforces from the
// garrison's reserve pool. A stow clears the pool and this accounting, so the raise hook re-runs this to re-inject
// from the OPCOM store.
//
// Each unit contributes one marked token "opcomdef<id>:<name>", kept out of DUWS_garrisonFull so the base ledger ignores
// its loss. A re-sync diffs against the tokens it added this awake session, not against the pool: a unit already drawn
// onto the ground is out of the pool but still homed, and re-adding its token would field it twice.
if (!isServer) exitWith {};

DUWS_fnc_opcom_zoneReserveSync = {
    params ["_key"];
    if (isNil "DUWS_opcom_taskings") exitWith {};
    private _cvar = format ["DUWS_zoneCeiling_%1", _key];
    if (isNil { missionNamespace getVariable _cvar }) exitWith {};        // site stowed -- its next wake re-syncs
    private _avar = format ["DUWS_zoneReserveOpcom_%1", _key];
    private _had = missionNamespace getVariable [_avar, []];
    // Only combatants feed the pool; a noncombat unit rests attached, never spawned to defend.
    private _want = (DUWS_opcom_taskings select {
        (_x get "homeZone") isEqualTo _key && {(_x get "order") isEqualTo "garrison"}
            && {!("noncombat" in (_x get "flags"))} && {(_x get "status") != "dead"}
    }) apply { [_x] call DUWS_fnc_opcom_reserveToken };
    if (_want isEqualTo _had) exitWith {};
    private _pool = [_key] call DUWS_fnc_garrisonReserve;
    // In place: a refill already running holds this array.
    { private _i = _pool find _x; if (_i >= 0) then { _pool deleteAt _i } } forEach (_had - _want);
    _pool append (_want - _had);
    [_key, _pool] call DUWS_fnc_garrisonReserveSet;
    missionNamespace setVariable [_avar, _want];
    missionNamespace setVariable [_cvar, (missionNamespace getVariable _cvar) - count _had + count _want];
};

// The marked pool token a tasking contributes -- used to find its reserve-spawned group on a draw.
DUWS_fnc_opcom_reserveToken = {
    params ["_t"];
    format ["opcomdef%1:%2", _t get "id", [(_t get "comp") select 0] call DUWS_fnc_tokenName]
};

// Draw a homed unit out of its zone: delete the defender its reserve token stands as, then re-sync so the pool and
// the ceiling drop by it. A unit going mobile must not also stand in the wave.
DUWS_fnc_opcom_drawOut = {
    params ["_t"];
    private _hz = _t get "homeZone";
    if (_hz isEqualTo "") exitWith {};
    private _tok = [_t] call DUWS_fnc_opcom_reserveToken;
    { if ((_x getVariable ["DUWS_garrisonToken", ""]) isEqualTo _tok) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach allGroups;
    [_hz] call DUWS_fnc_opcom_zoneReserveSync;
};

// A homed unit fights only as its reserve-spawned group, so that group's wipe is the unit's death. Left in the store,
// the next raise would stand it again.
DUWS_fnc_opcom_defenderLost = {
    params ["_key", "_token"];
    private _i = DUWS_opcom_taskings findIf {
        (_x get "homeZone") isEqualTo _key && {(_x get "order") isEqualTo "garrison"} && {(_x get "status") != "dead"}
            && {([_x] call DUWS_fnc_opcom_reserveToken) isEqualTo _token}
    };
    if (_i < 0) exitWith {};
    private _t = DUWS_opcom_taskings select _i;
    _t set ["status", "dead"];
    [_key] call DUWS_fnc_opcom_zoneReserveSync;
    ["INFO", "OPCOM", format ["tasking %1 died defending %2", _t get "id", _key]] call fnc_log;
};

// A site flipped -- a zone captured, a town's garrison cleared or worked back out of the band. Every unit garrisoned
// there dies, combatants included: the break line lets a garrison fall with tokens still unspawned in the reserve
// pool, and one turned loose would stand up inside ground OPFOR no longer hold.
DUWS_fnc_opcom_siteLost = {
    params ["_key"];
    if (isNil "DUWS_opcom_taskings") exitWith {};
    private _town = [-1, parseNumber (_key select [5])] select ((_key select [0, 5]) isEqualTo "town_");
    private _doomed = [];
    {
        private _t = _x;
        if ((_t get "homeZone") isEqualTo _key && {(_t get "order") isEqualTo "garrison"}) then {
            _doomed pushBack _t;
        } else {
            private _errand = _t getOrDefault ["errand", []];
            private _bound = (_t getOrDefault ["returnZone", ""]) isEqualTo _key
                || {(_t getOrDefault ["settleZone", ""]) isEqualTo _key}
                || {_town >= 0 && {(_errand param [0, ""]) in ["reinforce", "fortify", "rapport"]} && {(_errand param [1, -1]) isEqualTo _town}};
            if (_bound) then {
                _t set ["order", "guard"]; _t set ["route", []];
                _t set ["homeZone", ""]; _t set ["returnZone", ""]; _t set ["settleZone", ""]; _t set ["errand", []];
                private _grp = groupFromNetId (_t get "grp");
                if (!isNull _grp) then { _t set ["pos", getPosASL (leader _grp)] };
                _t set ["target", _t get "pos"];
                // A bound ferry carry keeps its waypoints: the transport owns them, and the release re-orders it.
                if (!isNull _grp && {(_t getOrDefault ["carrying", -1]) < 0} && {(_t getOrDefault ["ridingOn", -1]) < 0}) then {
                    [_grp, "guard", _t get "pos"] call DUWS_fnc_opcom_applyOrder;
                };
                ["INFO", "OPCOM", format ["tasking %1 guards where it stands -- %2 is no longer OPFOR ground", _t get "id", _key]] call fnc_log;
            };
        };
    } forEach DUWS_opcom_taskings;
    {
        if ((_x get "grp") isNotEqualTo "") then {
            private _grp = groupFromNetId (_x get "grp");
            if (!isNull _grp) then { [_grp] call DUWS_fnc_opcom_despawn };
        };
    } forEach _doomed;
    DUWS_opcom_taskings = DUWS_opcom_taskings - _doomed;
    [_key] call DUWS_fnc_opcom_zoneReserveSync;
};
