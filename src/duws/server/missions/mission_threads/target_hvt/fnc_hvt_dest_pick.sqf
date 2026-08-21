// Locality: server + all clients (publicVariable'd). Unscheduled-safe -- a pure call with no suspension.
// The client-side offer picker's HVT site-finder (fnc_target_hvt_site) calls it to prove a haven exists
// before offering; the server thread (fnc_target_hvt_mission) calls it to choose the haven the convoys
// actually run for. One source, so the offer and the launched mission never disagree on whether -- or
// where -- a destination exists.
//
// Given a convoy spawn, pick the OPFOR-held haven the columns flee to: the nearest held zone 3-10 km out
// whose straight-line corridor crosses no water and skims no BLUFOR ground. If every clean zone sits past
// 10 km, keep the 3 km floor and drop the ceiling -- take the nearest clean zone anyway, so a spawn with
// only distant havens still runs rather than aborting. No clean zone at all (a captured haven, a water-
// locked or friendly-ringed spawn) -> [], and the caller drops the offer or aborts the launch.
//
// Reads only broadcast state, so it is valid inside the client picker: WARCOM_zones_controled_by_*,
// zone_namePOS_pairs, PosOfBLUHQ and Array_of_FOBpos are all publicVariable'd, and fnc_route_has_water is
// too (for this call site).
//
// Contract: [_spawnPos] -> [_destPos, _destName] | [].
params ["_spawnPos"];

private _spawnMin = 3000;
private _spawnMax = 10000;
private _corridorReach = 1200;   // keep the spawn->haven run this far off BLUFOR ground

private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];

// Friendly ground the corridor must avoid: held BLUFOR zones, the HQ and every FOB. A haven run heads into
// enemy territory; one skimming our lines would be met at home, not out in the field.
private _friendly = +(missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []]);
private _hq = missionNamespace getVariable ["PosOfBLUHQ", []];
if !(_hq isEqualTo []) then { _friendly pushBack _hq };
{ _friendly pushBack _x } forEach (missionNamespace getVariable ["Array_of_FOBpos", []]);

// A corridor _spawnPos -> zone is usable only if it crosses no water and stays clear of friendly ground.
// Water via the shared probe; BLUFOR via interior samples against _friendly at _corridorReach.
private _corridorClear = {
    params ["_zp"];
    if ([_spawnPos, _zp] call fnc_route_has_water) exitWith { false };
    if (_friendly isEqualTo []) exitWith { true };
    private _d = _spawnPos distance2D _zp;
    private _steps = ceil (_d / 250);
    private _ok = true;
    for "_i" from 1 to (_steps - 1) do {
        private _t = _i / _steps;
        private _px = (_spawnPos select 0) + ((_zp select 0) - (_spawnPos select 0)) * _t;
        private _py = (_spawnPos select 1) + ((_zp select 1) - (_spawnPos select 1)) * _t;
        if ((_friendly findIf { [_px, _py] distance2D _x < _corridorReach }) >= 0) exitWith { _ok = false };
    };
    _ok
};

// Held OPFOR zones at least the minimum out with a clean corridor, tagged by distance.
private _cands = [];
{
    _x params ["_zn", "_zp"];
    if ((_enemyZones findIf { _x distance2D _zp < 50 }) >= 0) then {
        private _dz = _zp distance2D _spawnPos;
        if (_dz >= _spawnMin && {[_zp] call _corridorClear}) then { _cands pushBack [_dz, _zp, _zn] };
    };
} forEach _pairs;
if (_cands isEqualTo []) exitWith { [] };

// Prefer a haven in the 3-10 km band (nearest of them); if every clean zone sits past 10 km, take the
// nearest clean zone anyway -- keep the 3 km floor, drop only the ceiling.
private _inBand = _cands select { (_x select 0) <= _spawnMax };
private _pool = if (_inBand isEqualTo []) then { _cands } else { _inBand };
private _pick = [_pool, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy select 0;
[_pick select 1, _pick select 2]
