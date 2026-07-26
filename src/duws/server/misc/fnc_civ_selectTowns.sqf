// Locality: server -- reads zone state published by the zone locators.
/*
    fnc_civ_selectTowns.sqf
    Picks the map towns that should carry a civilian population: real Locations near the
    fighting, ranked by size and proximity. Returns [selected, spare] -- the towns to
    register, and a replacement queue for those the caller rejects. No side effects; the
    caller does the sizing and registration.
*/
if (!isServer) exitWith {[[], []]};

// Tuning knobs. Raising _WEIGHT_PROX pulls civilians onto the front line; raising
// _WEIGHT_SIZE sends players to the population centres wherever they happen to be. Size
// leads: an even split kept picking hamlets that happened to sit nearer an anchor over the
// cities behind them, which is the opposite of where a population belongs.
private _WEIGHT_SIZE = 0.7;
private _WEIGHT_PROX = 0.3;
private _ANCHOR_RADIUS = 5000;
private _PER_ANCHOR_CAP = 3;

// An anchor is a point the fighting revolves around. FOBs are excluded: they are built after
// generation and would mean re-selecting. PosOfBLUHQ defaults to [] rather than nil, so
// isNil does not catch the unset case and a bare `select 0` would throw.
private _zones = missionNamespace getVariable ["serv_zones_array", []];
private _hq = missionNamespace getVariable ["PosOfBLUHQ", []];
private _hqPos = [];
if (count _hq >= 2) then { _hqPos = [_hq select 0, _hq select 1, 0] };

private _anchors = [];
if (count _hqPos > 0) then { _anchors pushBack _hqPos };
{
    if (count _x >= 2) then { _anchors pushBack [_x select 0, _x select 1, 0]; };
} forEach _zones;

if (count _anchors == 0) exitWith {
    ["ERROR", "CIV", "No anchors: PosOfBLUHQ unset and no zones placed. Selecting no towns."] call fnc_log;
    [[], []]
};

// One config-backed engine call, not a terrain scan. NameLocal is kept for portability to
// maps that use it for settlements; on Altis it also names quarries and salt flats, which
// the caller's building-count filter removes.
private _candidates = nearestLocations [
    [worldSize / 2, worldSize / 2, 0],
    ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"],
    worldSize
];

// [location, position, extent] for every town inside some anchor's disc. The union of the
// discs, not their intersection: a strict intersection is empty in any campaign whose zones
// sit more than twice _ANCHOR_RADIUS apart, which is most of them.
private _pool = [];
{
    private _loc = _x;
    // getPos, not locationPosition: the runtime centres triggers and markers on
    // getPos (fnc_civ_handler.sqf:26), and eligibility must measure the same point.
    private _pos = getPos _loc;

    if ((_anchors findIf { _pos distance2D _x <= _ANCHOR_RADIUS }) >= 0) then {
        // radiusA/radiusB out of CfgWorlds, already half-extents, so no halving. Typed
        // defensively because the engine's return shape here is easy to get wrong, and a
        // wrong assumption would silently flatten every size score to the fallback.
        private _sz = size _loc;
        private _extent = 0;
        if (_sz isEqualType []) then {
            if (count _sz >= 2) then { _extent = (_sz select 0) max (_sz select 1) };
        } else {
            if (_sz isEqualType 0) then { _extent = _sz };
        };
        // Some map entries define no radius. The type is always present.
        if (_extent <= 0) then {
            _extent = switch (type _loc) do {
                case "NameCityCapital": { 300 };
                case "NameCity": { 200 };
                case "NameVillage": { 120 };
                default { 80 };
            };
        };
        _pool pushBack [_loc, _pos, _extent];
    };
} forEach _candidates;

private _maxExtent = 0;
{ if ((_x select 2) > _maxExtent) then { _maxExtent = _x select 2 } } forEach _pool;
if (_maxExtent <= 0) then { _maxExtent = 1 };

// Scores one pool entry against one anchor; -1 means out of that anchor's reach. Both terms
// normalise to 0..1 so neither can dominate by unit choice, and _maxExtent is global so the
// size term stays comparable between anchors.
private _fnc_score = {
    params ["_entry", "_anchor"];
    private _dist = (_entry select 1) distance2D _anchor;
    if (_dist > _ANCHOR_RADIUS) then { -1 } else {
        (_WEIGHT_SIZE * ((_entry select 2) / _maxExtent)) + (_WEIGHT_PROX * (1 - (_dist / _ANCHOR_RADIUS)))
    }
};

// Wave 1: each anchor ranks its own disc and takes its own quota, in turn, skipping what
// earlier anchors already took. A single ranking over the whole union let one dense cluster
// win every slot and left remote zones with no civilians within reach.
private _taken = [];
{
    private _anchor = _x;
    private _scored = [];
    {
        if (!(_forEachIndex in _taken)) then {
            private _score = [_x, _anchor] call _fnc_score;
            if (_score >= 0) then { _scored pushBack [_score, _forEachIndex] };
        };
    } forEach _pool;
    _scored sort false;
    { _taken pushBack (_x select 1) } forEach (_scored select [0, _PER_ANCHOR_CAP]);
} forEach _anchors;

// Wave 2: a flat top-up drawn at random across the union, sized to the zone count, so the
// map does not read as exactly three towns ringing every objective.
private _remaining = [];
{ if (!(_forEachIndex in _taken)) then { _remaining pushBack _forEachIndex } } forEach _pool;
_remaining = _remaining call BIS_fnc_arrayShuffle;
private _topUp = _remaining select [0, count _zones];
_taken append _topUp;
// Explicit count: omitting it makes `select` return an empty array under the pinned test VM,
// which silently discarded every replacement candidate.
_remaining = _remaining select [count _topUp, count _remaining];

// Replacement queue for registration, which rejects towns this pass cannot judge (it alone
// derives the civilian radius). HQ leftovers lead, best first: the rejection registration
// can act on is an overlap with the HQ, so the stand-in should come from the same disc.
private _spare = [];
if (count _hqPos > 0) then {
    private _hqScored = [];
    {
        private _score = [_pool select _x, _hqPos] call _fnc_score;
        if (_score >= 0) then { _hqScored pushBack [_score, _x] };
    } forEach _remaining;
    _hqScored sort false;
    _spare = _hqScored apply { _x select 1 };
};
_spare append (_remaining select { !(_x in _spare) });

private _selected = _taken apply { (_pool select _x) select 0 };
private _spareLocs = _spare apply { (_pool select _x) select 0 };

["INFO", "CIV", format ["Town selection: %1 anchors over %2 zones, %3 of %4 map towns within %5m; %6 selected (%7 quota + %8 top-up), %9 spare",
    count _anchors, count _zones, count _pool, count _candidates, _ANCHOR_RADIUS,
    count _selected, (count _taken) - (count _topUp), count _topUp, count _spareLocs]] call fnc_log;
["INFO", "CIV", format ["Town selection returned %1 towns: %2",
    count _selected, _selected apply { text _x }]] call fnc_log;

[_selected, _spareLocs]
