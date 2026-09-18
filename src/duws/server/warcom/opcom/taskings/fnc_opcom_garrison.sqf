// Locality: server, [] call'd at load (before any zone raises) so the raise hook can resolve it. Reconciles a
// site's reserve pool + ceiling -- a zone's or a town's, one key either way -- with OPCOM's recruited `garrison` units, so a recruit reinforces through the
// existing garrison-reserve wave. The base re-seeds pool + ceiling on every raise, so the raise hook re-runs this
// to re-inject from the OPCOM store.
//
// Each unit contributes one marked token "opcomdef<id>:<name>": kept out of DUWS_garrisonFull so a loss is ignored
// by the base ledger, and identifiable for an idempotent strip-and-re-add. The base ceiling is recovered as
// current-ceiling minus OPCOM's pool tokens, so a re-sync never compounds and a wiped pool self-corrects.
if (!isServer) exitWith {};

DUWS_fnc_opcom_zoneReserveSync = {
    params ["_key"];
    if (isNil "DUWS_opcom_taskings") exitWith {};
    // Only combatants feed the wave; a noncombat unit rests attached, never spawned to defend.
    private _units = DUWS_opcom_taskings select { (_x get "homeZone") isEqualTo _key && {(_x get "order") isEqualTo "garrison"} && {!("noncombat" in (_x get "flags"))} };
    private _pool = [_key] call DUWS_fnc_garrisonReserve;
    private _mine = _pool select { (_x select [0, 8]) == "opcomdef" };
    if (_units isEqualTo [] && {_mine isEqualTo []}) exitWith {};        // nothing OPCOM here -- base untouched
    private _cvar = format ["DUWS_zoneCeiling_%1", _key];
    if (isNil { missionNamespace getVariable _cvar }) exitWith {};        // zone stowed -- its next wake re-syncs
    private _baseCeil = (missionNamespace getVariable [_cvar, 0]) - (count _mine);
    private _want = _units apply { format ["opcomdef%1:%2", _x get "id", [(_x get "comp") select 0] call DUWS_fnc_tokenName] };
    private _kept = _pool select { (_x select [0, 8]) != "opcomdef" };    // base tokens only
    _kept append _want;
    [_key, _kept] call DUWS_fnc_garrisonReserveSet;
    missionNamespace setVariable [_cvar, _baseCeil + (count _units)];
};

// The marked pool token a tasking contributes -- used to find its reserve-spawned group on a draw.
DUWS_fnc_opcom_reserveToken = {
    params ["_t"];
    format ["opcomdef%1:%2", _t get "id", [(_t get "comp") select 0] call DUWS_fnc_tokenName]
};

// A site flipped -- a zone captured, a town's garrison cleared or worked back out of the band. Its resting
// non-combatants die with it (attached, never defenders; one borrowed onto ferry duty has left and survives), and
// every other order tied to the site drops to guard where it stands: a garrison homed there, a unit still walking in
// to settle, an errand carrying goods to it. Combatants are left to the mechanic that fought them.
DUWS_fnc_opcom_siteLost = {
    params ["_key"];
    if (isNil "DUWS_opcom_taskings") exitWith {};
    private _town = [-1, parseNumber (_key select [5])] select ((_key select [0, 5]) isEqualTo "town_");
    private _doomed = [];
    {
        private _t = _x;
        private _homed = (_t get "homeZone") isEqualTo _key && {(_t get "order") isEqualTo "garrison"};
        if (_homed && {"noncombat" in (_t get "flags")}) then {
            _doomed pushBack _t;
        } else {
            private _errand = _t getOrDefault ["errand", []];
            private _bound = _homed
                || {(_t getOrDefault ["returnZone", ""]) isEqualTo _key}
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
