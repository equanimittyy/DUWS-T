// Locality: server -- reads zone state published by the zone locators.
/*
    Picks the map towns that should carry a civilian population: real Locations near the
    fighting, ranked by how many usable buildings they hold. Returns [selected, spare] as
    [location, buildingCount, hqQuota, buildings] quads -- the towns to register, and a
    replacement queue for those the caller rejects. Draws its own survey progress on the map
    prompt; otherwise no side effects, and the caller does the registration.
*/
if (!isServer) exitWith {[[], []]};

// Tuning knobs. _COUNT_RADIUS is the disc a town's buildings are counted over, and the caller
// derives each town's civilian area and starting population from that same count, so moving it
// moves civilian density as well as the ranking.
private _ANCHOR_RADIUS = 5000;
private _PER_ANCHOR_CAP = 3;
private _COUNT_RADIUS = 350;
private _MIN_BUILDINGS = 3;

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
// maps that use it for settlements; on Altis it also names quarries and salt flats, which the
// building floor below removes.
private _candidates = nearestLocations [
    [worldSize / 2, worldSize / 2, 0],
    ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"],
    worldSize
];

// Towns inside some anchor's disc. The union of the discs, not their intersection: a strict
// intersection is empty in any campaign whose zones sit more than twice _ANCHOR_RADIUS apart,
// which is most of them. Split off from the building sweep below so that sweep runs over a
// known total and its progress reads linearly -- this pass is only distance checks.
private _inReach = [];
{
    // getPos, not locationPosition: the runtime centres triggers and markers on
    // getPos (fnc_civ_handler.sqf:26), and eligibility must measure the same point.
    private _pos = getPos _x;
    if ((_anchors findIf { _pos distance2D _x <= _ANCHOR_RADIUS }) >= 0) then {
        _inReach pushBack [_x, _pos];
    };
} forEach _candidates;

// [location, position, buildings] for every town in reach holding enough buildings to populate.
// Ranked on standing buildings rather than `size _loc`: the radiusA/radiusB in CfgWorlds are
// hand-authored per map and routinely put a hamlet level with a city, so an extent-ranked pass
// kept spending slots on empty ground. Counted once here and carried out with the location,
// because the caller needs the same figure and this is the heaviest engine work in the whole
// civilian pass.
private _pool = [];
private _total = count _inReach;
private _lastPing = 0;
{
    _x params ["_loc", "_pos"];
    private _usable = [_pos, 2, _COUNT_RADIUS] call fnc_usableBuildings;
    private _buildings = count _usable;
    // Below the floor there is nothing for a civilian to walk into, and the caller's population
    // floor would still drop a dozen of them in an empty field.
    if (_buildings >= _MIN_BUILDINGS) then {
        _pool pushBack [_loc, _pos, _buildings, _usable];
    };

    // The setup phase forces the map open and hint/globalChat both render beneath it, so the
    // map prompt is the only channel a player sees during this pass. Throttled by time, not by
    // index: the candidate count swings with the anchor spread, so a fixed every-Nth would be
    // silent on a tight campaign and spam on a spread one.
    if (diag_tickTime - _lastPing > 1.5) then {
        _lastPing = diag_tickTime;
        [format ["Placing civilians...<br/>surveying towns  %1%2  (%3 of %4 sites)",
            round (100 * _forEachIndex / (1 max _total)), "%", _forEachIndex, _total]]
            remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    };
} forEach _inReach;

// Wave 1: each anchor ranks its own disc by building count and takes its own quota, in turn,
// skipping what earlier anchors already took. A single ranking over the whole union let one
// dense cluster win every slot and left remote zones with no civilians within reach. Distance
// only gates -- inside a disc the bigger town always wins, however far back it sits, because
// blending in closeness let roadside hamlets outrank the cities behind them.
// The HQ's own quota is flagged separately because hardcore starts the player knowing their
// immediate surroundings and nothing else. Tagged in the loop rather than sliced off the front
// of _taken afterwards: with no HQ placed the zones lead the anchor list and no town qualifies.
private _taken = [];
private _hqQuota = [];
{
    private _anchor = _x;
    private _isHQ = count _hqPos > 0 && { _forEachIndex == 0 };
    private _scored = [];
    {
        if (!(_forEachIndex in _taken) && { (_x select 1) distance2D _anchor <= _ANCHOR_RADIUS }) then {
            _scored pushBack [_x select 2, _forEachIndex];
        };
    } forEach _pool;
    _scored sort false;
    {
        _taken pushBack (_x select 1);
        if (_isHQ) then { _hqQuota pushBack (_x select 1) };
    } forEach (_scored select [0, _PER_ANCHOR_CAP]);
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
// derives the civilian radius). HQ leftovers lead, biggest first: the rejection registration
// can act on is an overlap with the HQ, so the stand-in should come from the same disc.
private _spare = [];
if (count _hqPos > 0) then {
    private _hqScored = [];
    {
        private _entry = _pool select _x;
        if ((_entry select 1) distance2D _hqPos <= _ANCHOR_RADIUS) then {
            _hqScored pushBack [_entry select 2, _x];
        };
    } forEach _remaining;
    _hqScored sort false;
    _spare = _hqScored apply { _x select 1 };
};
_spare append (_remaining select { !(_x in _spare) });

// Spare towns are drawn from what wave 1 left behind, so the HQ flag is always false for them.
private _fnc_pair = { private _entry = _pool select _x; [_entry select 0, _entry select 2, _x in _hqQuota, _entry select 3] };
private _selected = _taken apply _fnc_pair;
private _spareTowns = _spare apply _fnc_pair;

["INFO", "CIV", format ["Town selection: %1 anchors over %2 zones, %3 of %4 map towns within %5m holding %6+ buildings; %7 selected (%8 quota + %9 top-up), %10 spare",
    count _anchors, count _zones, count _pool, count _candidates, _ANCHOR_RADIUS, _MIN_BUILDINGS,
    count _selected, (count _taken) - (count _topUp), count _topUp, count _spareTowns]] call fnc_log;
["INFO", "CIV", format ["Town selection returned %1 towns (name/buildings): %2",
    count _selected, _selected apply { format ["%1 %2", text (_x select 0), _x select 1] }]] call fnc_log;

[_selected, _spareTowns]
