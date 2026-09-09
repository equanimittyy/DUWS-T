// Locality: server, [] call'd at load (before any zone raises) so the zone-raise hook can resolve it.
// Reconciles a zone's reserve pool + ceiling with OPCOM's recruited `garrison` units, so a recruit reinforces
// through the existing garrison-reserve wave (docs/plans/opcom/opcom_plan.md). The base re-seeds pool + ceiling
// on every raise, so the raise hook re-runs this to re-inject from the OPCOM store (the source of truth).
//
// Each unit contributes one marked token "opcomdef<id>:<name>" -- thrown away by the refill's hunt order, kept
// out of DUWS_garrisonFull so a loss is ignored by the base ledger, and identifiable for an idempotent
// strip-and-re-add. The base ceiling is recovered as current-ceiling minus OPCOM's tokens in the pool, so a
// re-sync never compounds and a re-seed (pool wiped -> 0 markers) self-corrects.
if (!isServer) exitWith {};

DUWS_fnc_opcom_zoneReserveSync = {
    params ["_key"];
    if (isNil "DUWS_opcom_taskings") exitWith {};
    private _units = DUWS_opcom_taskings select { (_x get "homeZone") isEqualTo _key && {(_x get "order") isEqualTo "garrison"} };
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

// The marked pool token a given tasking contributes, for locating its reserve-spawned group on a draw.
DUWS_fnc_opcom_reserveToken = {
    params ["_t"];
    format ["opcomdef%1:%2", _t get "id", [(_t get "comp") select 0] call DUWS_fnc_tokenName]
};
