// Locality: server -- reads zone state published by the zone locators.
/*
    fnc_civ_selectTowns.sqf
    Picks the map towns that should carry a civilian population: real Locations near the
    fighting, ranked by size and proximity. Returns an array of Locations, no side effects.
    Callers do the sizing and registration.
*/
if (!isServer) exitWith {[]};

// Tuning knobs. Raising _WEIGHT_PROX pulls civilians onto the front line; raising
// _WEIGHT_SIZE sends players to the population centres wherever they happen to be.
private _WEIGHT_SIZE = 0.5;
private _WEIGHT_PROX = 0.5;
// Union of discs around each anchor, not their intersection: a strict intersection is empty
// in any campaign whose zones sit more than twice this apart, which is most of them.
private _ANCHOR_RADIUS = 5000;
private _PER_ANCHOR_CAP = 3;

// An anchor is a point the fighting revolves around. FOBs are excluded: they are built after
// generation and would mean re-selecting. PosOfBLUHQ defaults to [] rather than nil, so
// isNil does not catch the unset case and a bare `select 0` would throw.
private _anchors = [];
private _hq = missionNamespace getVariable ["PosOfBLUHQ", []];
if (count _hq >= 2) then { _anchors pushBack [_hq select 0, _hq select 1, 0]; };
{
    if (count _x >= 2) then { _anchors pushBack [_x select 0, _x select 1, 0]; };
} forEach (missionNamespace getVariable ["serv_zones_array", []]);

private _result = [];

if (count _anchors == 0) then {
    ["ERROR", "CIV", "No anchors: PosOfBLUHQ unset and no zones placed. Selecting no towns."] call fnc_log;
} else {
    // One config-backed engine call, not a terrain scan. NameLocal is kept for portability to
    // maps that use it for settlements; on Altis it also names quarries and salt flats, which
    // the caller's building-count filter removes.
    private _candidates = nearestLocations [
        [worldSize / 2, worldSize / 2, 0],
        ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"],
        worldSize
    ];

    // [location, distance to nearest anchor, extent]
    private _eligible = [];
    {
        private _loc = _x;
        // getPos, not locationPosition: the runtime centres triggers and markers on
        // getPos (fnc_civ_handler.sqf:26), and eligibility must measure the same point.
        private _pos = getPos _loc;
        private _nearest = -1;
        {
            private _dist = _pos distance2D _x;
            if (_nearest < 0 || _dist < _nearest) then { _nearest = _dist };
        } forEach _anchors;

        if (_nearest >= 0 && _nearest <= _ANCHOR_RADIUS) then {
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
            _eligible pushBack [_loc, _nearest, _extent];
        };
    } forEach _candidates;

    private _cap = _PER_ANCHOR_CAP * count _anchors;
    ["INFO", "CIV", format ["Town selection: %1 anchors, %2 of %3 map towns within %4m, cap %5",
        count _anchors, count _eligible, count _candidates, _ANCHOR_RADIUS, _cap]] call fnc_log;

    if (count _eligible <= _cap) then {
        _result = _eligible apply { _x select 0 };
    } else {
        private _maxExtent = 0;
        { if ((_x select 2) > _maxExtent) then { _maxExtent = _x select 2 } } forEach _eligible;
        if (_maxExtent <= 0) then { _maxExtent = 1 };

        // Both terms normalise to 0..1 so neither can dominate by unit choice.
        private _scored = _eligible apply {
            private _sizeScore = (_x select 2) / _maxExtent;
            private _proxScore = 1 - ((_x select 1) / _ANCHOR_RADIUS);
            [(_WEIGHT_SIZE * _sizeScore) + (_WEIGHT_PROX * _proxScore), _x select 0]
        };
        _scored sort false;
        _result = (_scored select [0, _cap]) apply { _x select 1 };
    };
};

["INFO", "CIV", format ["Town selection returned %1 towns: %2",
    count _result, _result apply { text _x }]] call fnc_log;

_result
