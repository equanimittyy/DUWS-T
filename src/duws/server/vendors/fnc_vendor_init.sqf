// Locality: server -- registered once for all towns by server/civilian/fnc_civ_init_Tomata.sqf.
/*
    Drafts every town's vendors, paints their markers and hands their lifecycle to the shared site
    poller. No params. Returns once the hooks are in place.

    The draft runs once, at campaign generation, and is never re-rolled: a town's shops have to stand
    in the same place after a save/restore, so the registry is the campaign's answer and every later
    spawn only replays it.
*/
if (!isServer) exitWith {};

// A vanilla-mode feature, exactly as the disguise is. RAVAGE and WBK keep their own crowd handlers
// and have no civil economy to sell into; NONE has no civilians to sell to.
if (CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]) exitWith {};

// Building count above which a town carries a second vendor slot. Untuned: slot counts and prices are
// the two numbers the jobs plan's balance phase settles, once a paid job exists to weigh a shop against.
#define BIG_TOWN 30

// Weight of "leave this slot empty", as a share of the total weight of the types the town could host.
// Without it every slot in every town would carry a vendor. Measured against their total rather than
// set as one more type's weight, so the draft's density does not thin every time the catalogue grows:
// at 1.5 a second-pass slot comes up empty 60% of the time, whatever a campaign fields.
#define EMPTY_SHARE 1.5

private _locations = missionNamespace getVariable ["civ_locations", []];
private _count = count _locations;
if (_count == 0) exitWith {};
private _radii = missionNamespace getVariable ["civ_radii", []];

private _pops = [];
for "_i" from 0 to (_count - 1) do {
    _pops pushBack (missionNamespace getVariable [format ["civ_pop_%1", _i], 0]);
};

// One polar sweep per town answers both questions the boat dealer asks: whether the town can host one
// at all, and which of its buildings stands closest to the shore.
private _fnc_townWater = {
    params ["_centre", "_radius"];
    private _pts = [];
    for "_ring" from 1 to 6 do {
        private _r = _radius * _ring / 6;
        for "_i" from 0 to 23 do {
            private _p = _centre getPos [_r, _i * 15];
            if (surfaceIsWater _p) then { _pts pushBack _p };
        };
    };
    _pts
};

private _water = [];
for "_i" from 0 to (_count - 1) do {
    _water pushBack ([getPos (_locations select _i), _radii param [_i, 500]] call _fnc_townWater);
};

// A type with nowhere to stand is left out of the draft rather than drafted and then found stranded:
// a landlocked map has no boat dealer.
private _fnc_canHost = {
    params ["_town", "_type"];
    if ((([_type] call fnc_vendor_type) select 4) isNotEqualTo "water") exitWith { true };
    (_water select _town) isNotEqualTo []
};

// Largest town first, so the guaranteed pass below seeds each type into the town most able to host it
// and most likely to be visited.
private _ranked = [];
for "_i" from 0 to (_count - 1) do { _ranked pushBack [_pops select _i, _i] };
_ranked sort false;
private _order = _ranked apply { _x select 1 };

private _free = _pops apply { [1, 2] select (_x >= BIG_TOWN) };
// Built in a loop, not by apply: every town needs an array of its own to push into.
private _draft = [];
for "_i" from 0 to (_count - 1) do { _draft pushBack [] };

// Every type appears at least once. Rolling each town independently would let a type come up zero
// times across a whole campaign, or only in towns that start enemy-held and refuse to sell.
{
    private _type = _x;
    private _slot = _order findIf {
        (_free select _x) > 0 && {!(_type in (_draft select _x))} && {[_x, _type] call _fnc_canHost}
    };
    if (_slot >= 0) then {
        private _town = _order select _slot;
        (_draft select _town) pushBack _type;
        _free set [_town, (_free select _town) - 1];
    };
} forEach (keys DUWS_vendorTypes);

// Whatever is left is a weighted roll with "empty" on the wheel: a town is not owed a full set, and
// a type never appears twice in one town.
for "_i" from 0 to (_count - 1) do {
    while { (_free select _i) > 0 } do {
        private _wheel = [];
        private _total = 0;
        {
            if (!(_x in (_draft select _i)) && {[_i, _x] call _fnc_canHost}) then {
                private _w = ([_x] call fnc_vendor_type) select 2;
                _wheel pushBack _x;
                _wheel pushBack _w;
                _total = _total + _w;
            };
        } forEach (keys DUWS_vendorTypes);
        _wheel pushBack "";
        _wheel pushBack ((_total * EMPTY_SHARE) max 1);
        private _pick = selectRandomWeighted _wheel;
        if (_pick != "") then { (_draft select _i) pushBack _pick };
        _free set [_i, (_free select _i) - 1];
    };
};

// Weighted by trade: a boat dealer takes the surveyed building closest to the shore, a car dealer one
// near a fuel station where the town has one, and everything else a random building. A town with no
// anchor of its own kind falls back to random, so a fuel-less town still gets its car dealer.
private _fnc_pickBuilding = {
    params ["_pool", "_type", "_town", "_centre", "_radius"];
    private _anchors = switch (([_type] call fnc_vendor_type) select 4) do {
        case "water": { _water select _town };
        case "fuel":  { (nearestTerrainObjects [_centre, ["FUELSTATION"], _radius]) apply { getPos _x } };
        default       { [] };
    };
    if (_anchors isEqualTo []) exitWith { selectRandom _pool };
    // Ranked by index, not by holding the building itself: sort compares element by element, and a
    // row carrying an Object has nothing it can compare on if two buildings tie for distance.
    private _ranked = [];
    {
        private _b = getPos _x;
        _ranked pushBack [selectMin (_anchors apply { _b distance2D _x }), _forEachIndex];
    } forEach _pool;
    _ranked sort true;
    _pool select ((_ranked select 0) select 1)
};

private _registry = [];
for "_i" from 0 to (_count - 1) do {
    private _centre = getPos (_locations select _i);
    private _radius = _radii param [_i, 500];
    // The same survey the crowd fills from, already trimmed to this town's final radius. Destroyed
    // buildings go null, so the list is filtered rather than trusted.
    private _buildings = (missionNamespace getVariable [format ["civ_buildings_%1", _i], []])
        select { !isNull _x };
    private _recs = [];
    private _taken = [];
    {
        // One vendor per building: two shopkeepers in one doorway is two markers on one pin.
        private _pool = _buildings select { !(_x in _taken) };
        if (_pool isEqualTo []) then { continue };
        private _building = [_pool, _x, _i, _centre, _radius] call _fnc_pickBuilding;
        _taken pushBack _building;
        // A building with no interior positions falls back to clear ground beside it, never to the
        // model origin, which for most houses is inside a wall.
        private _spots = [_building] call BIS_fnc_buildingPositions;
        private _pos = if (_spots isEqualTo []) then {
            [_building, 15, 5, 3, 0.3, getPos _building] call fnc_safe_pos
        } else { selectRandom _spots };
        // Facing is stored, not re-rolled per spawn: a vendor has to stand the same way every time it
        // comes back, and facing the town centre puts it looking at whoever walks up.
        _recs pushBack [_x, _pos, _pos getDir _centre, 0];
    } forEach (_draft select _i);
    _registry pushBack _recs;
};
missionNamespace setVariable ["DUWS_vendors", _registry];

// The poller runs this per site on one thread against a ~3 ms budget, so it gates and does nothing
// else until something is actually due.
private _fnc_tick = {
    params ["_key", "_o", "_here", "_now"];
    private _i = _o get "townIndex";
    private _recs = [_i] call fnc_vendor_recs;

    // Counted off elapsed time rather than the poll count, so a cadence change cannot stretch or
    // shorten a respawn, and held as remaining seconds because an absolute stamp does not survive a
    // save/restore (campaign_persistence_plan.md, time-state rule). Runs whether or not anyone is
    // here, so a shop reopens on schedule rather than on the next visit.
    private _dt = (_now - (_o getOrDefault ["lastTick", _now])) max 0;
    _o set ["lastTick", _now];
    {
        private _left = _x select 3;
        if (_left > 0) then {
            _left = (_left - _dt) max 0;
            _x set [3, _left];
            if (_left <= 0) then { [_i, _forEachIndex, 0] call fnc_vendor_markerPaint };
        };
    } forEach _recs;

    if (_here) then {
        _o set ["awake", true];
        // Fills a kill as well as a first arrival: a cooldown that runs out while the player is still
        // standing in the town has to put the vendor back without waiting for the town to sleep and
        // wake, which is the whole reason vendors are a kind of their own.
        {
            if ((_x select 3) <= 0 && {isNull ([_i, _forEachIndex] call fnc_vendor_live)}) then {
                [_i, _forEachIndex] call fnc_vendor_spawn;
            };
        } forEach _recs;
    } else {
        if ((_o get "awake") && {(_o get "emptySince") >= 0}
            && {diag_tickTime > (_o get "emptySince") + (_o get "grace")}) then {
            _o set ["awake", false];
            [_key, "vendors"] call fnc_site_collect;
        };
    };
};

private _vis = missionNamespace getVariable ["civ_visible", []];
private _placed = 0;
{
    private _i = _forEachIndex;
    private _recs = _x;
    if (_recs isEqualTo []) then { continue };

    {
        _x params ["_type", "_pos"];
        ([_type] call fnc_vendor_type) params ["_nameKey", "_icon"];
        private _m = createMarker [[_i, _forEachIndex] call fnc_vendor_markerName, _pos];
        _m setMarkerShape "ICON";
        _m setMarkerType _icon;
        _m setMarkerSize [0.8, 0.8];
        // The label is what identifies a shop. The task-glyph set is a close fit for these trades,
        // not an exact one, so an approximate icon is never left to carry the meaning alone.
        _m setMarkerText (localize _nameKey);
        // Hidden until fnc_civ_town_reveal uncovers the town, so the map does not open with every
        // shop on the island already pinned.
        _m setMarkerAlpha ([0, 1] select (_vis param [_i, false]));
        [_i, _forEachIndex, 0] call fnc_vendor_markerPaint;
    } forEach _recs;

    private _key = [_i] call fnc_town_site_key;
    [_key, getPos (_locations select _i), _radii param [_i, 500]] call fnc_site_register;
    // The crowd's presence numbers, not the crowd's population: fnc_civ_liveTarget sizes the crowd
    // from civ_pop_<n> and the density setting and never from live units, so a town fields its full
    // crowd plus its vendors.
    private _o = [_key, "vendors", CIVILIAN, "town_crowd"] call fnc_site_occupant_register_profile;
    _o set ["townIndex", _i];
    // A tick hook, not wake/sleep: wake fires once, and a five-minute respawn with the player still
    // standing in the town needs a clock that runs every pass. Only a kind of its own can declare one.
    [_key, "vendors", createHashMapFromArray [["tick", _fnc_tick]]] call fnc_site_hooks_set;
    _placed = _placed + count _recs;
} forEach _registry;

["INFO", "VENDOR", format ["%1 vendors drafted across %2 towns", _placed, _count]] call fnc_log;
