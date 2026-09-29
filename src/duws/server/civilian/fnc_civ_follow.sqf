// Locality: server -- run by a town's fill thread in fnc_civ_handler while the town is awake.
/*
    Keeps a town's crowd around its players: up to three civilians furthest from every player are
    deleted and made again out of every player's sight near a player in the town, on a circuit that
    walks past that player. Params: [_locIndex, _centre, _radius].

    Delete-and-create, not relocate: a civilian carries interaction state (spoken to, asked for
    intel, its action IDs) that a move would have to clear by hand, and a fresh unit gets a fresh face.
*/
if (!isServer) exitWith {};
params ["_locIndex", "_centre", "_radius"];

#define MOVE_MAX 3
#define KEEP_DIST 50
#define SPAWN_MAX 100
#define SPAWN_TRIES 6
// A man past this is a few pixels, and the bound keeps the rays to players who could be looking.
#define SIGHT_REACH 600

private _players = (call BIS_fnc_listPlayers) select { alive _x };
private _inTown = _players select { (_x distance2D _centre) < _radius };
if (_inTown isEqualTo []) exitWith {};

private _fnc_clearance = {
    params ["_pos"];
    private _d = 1e9;
    { _d = _d min (_x distance2D _pos) } forEach _players;
    _d
};
private _fnc_unseen = {
    params ["_pos"];
    (_players findIf { (_x distance2D _pos) < SIGHT_REACH && {[_pos, _x] call fnc_duws_posSeenBy} }) < 0
};

// A hostile, or a civilian mid-exchange with a player, is the player's business: a fresh unit would drop it.
private _key = [_locIndex] call fnc_town_site_key;
private _roster = [_key, "crowd"] call fnc_site_roster;
private _ranked = [];
{
    private _civ = _x;
    if (alive _civ && {_civ isKindOf "CAManBase"}
        && {isNil {_civ getVariable "DUWS_civ_pending"}}
        && {(["DUWS_civ_stopped", "DUWS_civ_panicked", "DUWS_civ_arrested", "isSurrendered", "isHostile"] findIf { _civ getVariable [_x, false] }) < 0}) then {
        private _gap = [getPos _civ] call _fnc_clearance;
        if (_gap > KEEP_DIST) then { _ranked pushBack [_gap, _forEachIndex] };
    };
} forEach _roster;
_ranked sort false;

private _picked = [];
{
    private _civ = _roster select (_x select 1);
    if ([getPos _civ] call _fnc_unseen) then { _picked pushBack _civ };
    if (count _picked == MOVE_MAX) exitWith {};
} forEach _ranked;

{
    private _civ = _x;
    private _player = selectRandom _inTown;
    private _spawn = [];
    for "_i" from 1 to SPAWN_TRIES do {
        private _try = [_player getPos [KEEP_DIST + random (SPAWN_MAX - KEEP_DIST), random 360], 10, 0, 3, 0.5, []] call fnc_safe_pos;
        if (_try isNotEqualTo [] && {([_try] call _fnc_clearance) > KEEP_DIST} && {[_try] call _fnc_unseen}) exitWith { _spawn = _try };
    };
    // Found before the delete, so ground with nowhere hidden keeps the crowd it has.
    if (_spawn isEqualTo []) then { continue };

    [_key, _civ, "crowd"] call fnc_site_roster_drop;
    deleteVehicle _civ;
    private _unit = [_locIndex, _spawn, selectRandom civ_array, false] call fnc_civ_spawnUnit;
    if (isNull _unit) then { continue };
    _roster pushBack _unit;

    private _via = _player getPos [5 + random 10, _spawn getDir _player];
    if (surfaceIsWater _via) then { _via = [] };
    [[group _unit], [], _via] call fnc_civ_wp_Tomata;
} forEach _picked;
