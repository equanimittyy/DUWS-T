// Locality: server -- driven by the town monitor thread in fnc_civ_handler.
/*
    fnc_civ_recycle.sqf
    One pass of a town's civilian stream: drop the people the players have walked away from, and
    refill the crowd around where the players actually are. Params: [_locIndex].

    Delete-and-create rather than moving the bodies. A civilian carries interaction state --
    searched, bribed, refused, arrested, plus its action IDs -- and relocating one means clearing
    every one of those by hand, a list that rots silently as interactions are added. A fresh unit
    also gets a fresh face, so a player crossing a city does not keep meeting the same six people.
    The cost is affordable because the rate is low: a pass every 90 s creates at worst what a
    single town fill already creates in a few seconds when the player first walks in, and in
    practice replaces only the handful that fell behind since the last pass.
*/
if (!isServer) exitWith {};
params ["_locIndex"];

if (CIV_PRESENCE == "NONE") exitWith {};
if !(missionNamespace getVariable [format ["civ_spawned_%1", _locIndex], false]) exitWith {};

// Floor under the recycle range, which is otherwise derived from the crowd's own spread below.
// Holds in a town dense enough that its cluster is only a block or two across, where the derived
// figure would start deleting people close enough to be recognisable as they go.
#define RECYCLE_FLOOR 180

// Margin over the cluster's own radius. Anything at or inside that radius is part of the crowd
// the players are standing in, so a range below it would delete units this same pass had just
// placed at the cluster's far edge and spend the whole budget churning in place.
#define RECYCLE_MARGIN 1.4

// Nothing appears in front of anyone. A town the players are standing in the middle of therefore
// refills slowly or not at all, which is the intended consequence of parking in one: the crowd
// thins as it is killed off and does not restock under the killer's nose.
#define SPAWN_CLEARANCE 120

// Must match fnc_civ_handler: the initial fill and this pass have to spread the crowd over the
// same footprint, or walking across a town would change how busy it reads for no reason the
// player can see. Why it is fixed rather than scaled is documented there.
#define CLUSTER_BUILDINGS 20

private _locations = missionNamespace getVariable ["civ_locations", []];
if (_locIndex >= count _locations) exitWith {};
private _centerPos = getPos (_locations select _locIndex);
private _radius = (missionNamespace getVariable ["civ_radii", []]) param [_locIndex, 500];

private _inTown = allPlayers select { alive _x && {_x distance2D _centerPos < _radius} };
if (_inTown isEqualTo []) exitWith {};

private _density = missionNamespace getVariable ["civ_density", 15];
private _target = [_density, _locIndex] call fnc_civ_liveTarget;

// The crowd goes into the buildings nearest a player rather than across the whole disc. A town's
// radius grows with its building count, so a fixed budget spread over the disc made the big towns
// the empty ones -- the same civilians over three times the ground. Clustering on a fixed number
// of buildings instead means the dense town packs them into a street corner and the sparse one
// strings them across a valley, which is the difference the density setting is meant to express.
// Ranked by index rather than by the building itself: sort compares element by element, and two
// buildings at an identical distance would leave it comparing objects.
private _buildings = (missionNamespace getVariable [format ["civ_buildings_%1", _locIndex], []]) select { !isNull _x };
private _anchor = getPos (_inTown select 0);
private _ranked = [];
{ _ranked pushBack [_x distance2D _anchor, _forEachIndex] } forEach _buildings;
_ranked sort true;
private _cluster = (_ranked select [0, CLUSTER_BUILDINGS]) apply { _buildings select (_x select 1) };

// Derived from the crowd's own spread rather than fixed, because the spread is what a flat figure
// would have to be wrong about in one direction or the other. A dense town packs its cluster into
// a couple of blocks, so the range closes in and the crowd re-forms two or three times as the
// player crosses the place -- which is the streaming actually doing something. A sparse town's
// cluster covers most of the town, the range opens past it, and nothing recycles, which is
// correct: there is no second half of that town to stream into.
private _clusterRadius = 0;
{ _clusterRadius = _clusterRadius max (_x distance2D _anchor) } forEach _cluster;
private _recycleDist = RECYCLE_FLOOR max (_clusterRadius * RECYCLE_MARGIN);

// Measured against every player, not just the ones inside the disc: someone standing just outside
// the boundary is still looking into the town, and deleting a civilian in their view is exactly
// what the distance rule exists to prevent.
private _watchers = allPlayers select { alive _x };
private _mine = allUnits select { (_x getVariable ["civ_locIndex", -1]) == _locIndex };
private _stale = _mine select {
    private _unit = _x;
    (_watchers findIf { _unit distance2D _x < _recycleDist }) < 0
};
{ deleteVehicle _x } forEach _stale;

// Empty groups are left to fnc_repetitive_cleanup, which reaps them on its own pass.
private _live = (count _mine) - (count _stale);
private _deficit = _target - _live;
if (duws_log_level >= 4) then {
    ["DEBUG", "CIV", format ["[Recycle] Location %1: %2 live, %3 dropped, target %4, range %5m",
        _locIndex, _live, count _stale, _target, round _recycleDist]] call fnc_log;
};
if (_deficit <= 0) exitWith {};

// Dropping the stale crowd runs whatever happens; only the refill needs somewhere to put people.
if (_cluster isEqualTo []) exitWith {};
private _civArray = missionNamespace getVariable ["civ_array", []];
if (_civArray isEqualTo []) exitWith {};

private _recruitableTypes = ["C_man_p_beggar_F","C_Man_casual_1_F","C_Man_casual_3_F","C_Man_casual_8_F","C_Man_casual_6_v2_F","C_Man_casual_2_F","C_Man_UtilityWorker_01_F","C_Man_Fisherman_01_F","C_Man_p_shorts_1_F","C_Man_w_worker_F"];
private _zombieTypes = _civArray select { !(_x in _recruitableTypes) };
if (_zombieTypes isEqualTo []) then { _zombieTypes = _civArray };

private _newGroups = [];
for "_i" from 1 to _deficit do {
    private _pos = [];
    private _tries = 0;
    while { _tries < 6 && {_pos isEqualTo []} } do {
        _tries = _tries + 1;
        private _building = selectRandom _cluster;
        if (!isNull _building) then {
            private _positions = [_building] call BIS_fnc_buildingPositions;
            private _candidate = if (_positions isEqualTo []) then { getPos _building } else { selectRandom _positions };
            if ((_watchers findIf { _candidate distance2D _x < SPAWN_CLEARANCE }) < 0) then { _pos = _candidate };
        };
    };
    // No clear ground in the cluster means the players are standing on all of it. Give up on this
    // pass rather than widening the search: the next one runs 90 s later, by which time they have
    // usually moved.
    if !(_pos isEqualTo []) then {
        private _unitType = selectRandom _civArray;
        private _isZombie = false;
        if (CIV_PRESENCE == "RAVAGE") then {
            _isZombie = random 1 >= 0.2;
            _unitType = selectRandom ([_recruitableTypes, _zombieTypes] select _isZombie);
        };
        private _unit = [_locIndex, _pos, _unitType, _isZombie] call fnc_civ_spawnUnit;
        if (!isNull _unit) then { _newGroups pushBack (group _unit) };
        sleep 0.2;
    };
};

if (_newGroups isEqualTo []) exitWith {};

private _groupList = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
_groupList append _newGroups;
missionNamespace setVariable [format ["civ_groups_%1", _locIndex], _groupList];

if (CIV_PRESENCE == "RAVAGE") then {
    {
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        private _wp = _x addWaypoint [_anchor, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointCompletionRadius 50;
        private _wpCycle = _x addWaypoint [_anchor, 100];
        _wpCycle setWaypointType "CYCLE";
    } forEach _newGroups;
} else {
    [_newGroups, _cluster] spawn fnc_civ_wp_Tomata;
};
