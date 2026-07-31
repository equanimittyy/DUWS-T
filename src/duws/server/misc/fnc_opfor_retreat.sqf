// Locality: server -- addWaypoint and doSuppressiveFire are ignored unless the group is local to
// the machine issuing them (docs/info/arma_engine_gotchas.md), and every group this steers is
// server-spawned.
// usage: [[_group1, _group2, ...], _holdPos] spawn fnc_opfor_retreat
//        units may be passed instead of groups; both resolve to the same group list.
//
// OPFOR give ground instead of being deleted where they stand. Callers are the town garrison and,
// later, the OPFOR commander -- which is why the order is a function taking arbitrary groups rather
// than anything the garrison owns.
//
// The force bounds rather than running as one body: half of the groups move while the other half
// holds ground and suppresses, then the two swap, repeating until the whole force is clear. A
// single group has nobody to cover it and simply moves every bound.
//
// _holdPos is the ground being given up. It is only the fallback bearing for an order issued with
// no BLUFOR left in reach, so a withdrawal still has a direction when the player has already gone.

if (!isServer) exitWith {};

// How far a moving element travels before the roles swap. Short enough that the covering element
// can still see and shoot over the ground its partner is crossing, which is the whole point of
// bounding; the bearing is recomputed every bound, so this is also how often the withdrawal
// re-aims at a player who has moved.
#define BOUND_LENGTH 300

// A bound that has not finished by here swaps anyway. Without it one group stuck on terrain holds
// the covering element in place for the rest of the withdrawal.
#define BOUND_TIMEOUT 60

// Deleting a unit somebody can see is the one thing a despawn must not do, so this is what the
// whole withdrawal is timed against -- not distance travelled, which says nothing about who is
// watching. A kilometre because this is a sighting range rather than a rendering one: infantry at
// 500 m are plain to the naked eye across open ground and unmissable through any optic, and the
// cost of pitching it short is a unit blinking out while somebody is looking at it.
#define OBSERVE_RADIUS 1000

// Area fire beyond this is noise: it empties magazines the group needs for the next bound and puts
// rounds nowhere near a player who cannot hear them land.
#define SUPPRESS_RANGE 400

#define POLL_INTERVAL 10

// A force that cannot break contact stops pretending to withdraw and turns to fight. Nothing is
// deleted on this path: a player who has chased them this long is watching, and the alternative to
// standing them back up is exactly the disappearing act the observation radius exists to prevent.
#define GIVE_UP 1200

// Must exceed OBSERVE_RADIUS, or a group could be held in place by a pursuer the bearing
// calculation cannot see, and would bound in a direction chosen from nothing.
#define SCAN_RADIUS 1600

params [["_units", []], ["_holdPos", [0,0,0]]];

private _groups = [];
{
    if (!isNull _x) then {
        _groups pushBackUnique (if (_x isEqualType grpNull) then { _x } else { group _x });
    };
} forEach _units;
if (count _groups == 0) exitWith {};

private _fnc_alive = { params ["_grp"]; ({alive _x} count units _grp) };

private _fnc_clearWp = {
    params ["_grp"];
    // Bound and reversed before the walk: deleteWaypoint renumbers every later waypoint down by
    // one, so a forward pass clears only every other one.
    private _wps = waypoints _grp;
    reverse _wps;
    { deleteWaypoint _x } forEach _wps;
};

// Clamped to the map rather than resolved to a safe position: arrival is not what releases a
// group, so a bound that ends in a bay costs one swap and nothing else, whereas BIS_fnc_findSafePos
// answers [0,0,0] on failure and would march the withdrawal to the map origin.
private _fnc_point = {
    params ["_from", "_dir"];
    private _edge = worldSize - 100;
    [((_from select 0) + BOUND_LENGTH * sin _dir) max 100 min _edge,
     ((_from select 1) + BOUND_LENGTH * cos _dir) max 100 min _edge, 0]
};

// What to call the ground being given up. A zone or a town by name where one is registered at this
// position, and a grid reference otherwise -- prefixed with the word, because a bare six-figure
// number on a notification card reads as anything but a map reference.
//
// Both callers hand over the position the place was registered at -- fnc_spawnWait its zone's
// spawn position, fnc_civ_garrison `getPos` of the town's Location -- so an exact match is the
// right test and a radius search would only invite naming a neighbour.
//
// A zone hardcore mode has not revealed stays a grid. The map readout withholds its name on the
// same flag, and a notification broadcast to every player must not hand out what the mode hides.
private _fnc_placeName = {
    params ["_pos"];
    private _zones = missionNamespace getVariable ["zone_namePOS_pairs", []];
    private _i = _zones findIf {((_x select 1) distance2D _pos) < 1 && {_x select 2}};
    if (_i > -1) exitWith { (_zones select _i) select 0 };

    // Towns carry no reveal flag: the readout names any town the player clicks, so there is
    // nothing here to withhold. An unnamed Location falls through to the grid rather than
    // printing the "Unnamed7" placeholder the civilian registry uses for its own bookkeeping.
    private _locs = missionNamespace getVariable ["civ_locations", []];
    private _t = _locs findIf {((getPos _x) distance2D _pos) < 1};
    if (_t > -1 && {text (_locs select _t) != ""}) exitWith { text (_locs select _t) };

    format [localize "STR_DUWS_T_GRID_REF", mapGridPosition _pos]
};

private _fnc_centre = {
    params ["_grps"];
    private _sx = 0; private _sy = 0; private _n = 0;
    {
        if (([_x] call _fnc_alive) > 0) then {
            private _p = getPos (leader _x);
            _sx = _sx + (_p select 0); _sy = _sy + (_p select 1); _n = _n + 1;
        };
    } forEach _grps;
    if (_n == 0) exitWith { [0,0,0] };
    [_sx / _n, _sy / _n, 0]
};

// Returns [bearing to withdraw along, position it is running from, whether that position is a real
// contact]. The covering element needs the second to know which way to face and where to put fire,
// and the third because the fallback is the ground the force is standing on -- suppressing that
// would have them shooting at their own feet.
private _fnc_aim = {
    params ["_centre", "_hold"];

    // Found the way fnc_duws_bluforNear finds presence: vehicles are queried alongside men and
    // their crew unpacked, because a CAManBase-only query does not report anyone riding in
    // something.
    private _near = [];
    {
        if (_x isKindOf "CAManBase") then {
            if (side _x == WEST) then { _near pushBack _x };
        } else {
            { if (side _x == WEST) then { _near pushBack _x } } forEach crew _x;
        };
    } forEach (_centre nearEntities [["CAManBase", "LandVehicle", "Air"], SCAN_RADIUS]);

    // Flat distance throughout: this picks a ground bearing, and a helicopter 300 m overhead would
    // otherwise be the nearest BLUFOR and give a direction to run that has no ground meaning.
    private _anchor = _hold;
    private _contact = count _near > 0;
    if (_contact) then {
        private _best = _near select 0;
        { if (_x distance2D _centre < _best distance2D _centre) then { _best = _x } } forEach _near;
        _anchor = getPos _best;
    };
    private _dir = _anchor getDir _centre;

    // Toward friendly ground, but only where that also opens the range: a held zone on the far
    // side of the player would otherwise route the withdrawal straight back through them.
    private _zones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
    if (count _zones > 0) then {
        private _zone = ([_zones, [_centre], {_input0 distance2D _x}, "ASCEND"] call BIS_fnc_sortBy) select 0;
        private _toZone = _centre getDir _zone;
        if (([_centre, _toZone] call _fnc_point) distance2D _anchor > _centre distance2D _anchor) then {
            _dir = _toZone;
        };
    };
    [_dir, _anchor, _contact]
};

// The bounding element. GREEN rather than BLUE: told to ignore the fight, not to die in it -- they
// return fire if engaged but never initiate, and enableAttack false stops them breaking off to
// close on a target, which is what would strand them out of their partner's arc. Safe to disable
// here precisely because it is the covering element's job to shoot, not this one's.
private _fnc_move = {
    params ["_grp", "_dir"];
    private _dest = [getPos (leader _grp), _dir] call _fnc_point;
    { _x doWatch objNull } forEach units _grp;
    [_grp] call _fnc_clearWp;
    _grp enableAttack false;
    _grp setBehaviour "AWARE";
    _grp setCombatMode "GREEN";
    _grp setSpeedMode "FULL";
    private _wp = _grp addWaypoint [_dest, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCombatMode "GREEN";
    _wp setWaypointSpeed "FULL";
    // doStop survives a fresh waypoint list, so the bound is issued as a direct order as well --
    // free on any group that was never stopped, and this one held its ground last bound.
    (leader _grp) doMove _dest;
    _dest
};

// The covering element. No waypoint at all rather than a waypoint on their own position: a group
// with an empty list holds where it stands.
// enableAttack is deliberately NOT disabled here, unlike on the movers. Its documented effect is
// that a group stops attacking on its own, and this element's entire job is to attack on its own;
// the cost of it being stronger than advertised is a covering element that never fires. Holding is
// enforced by the empty waypoint list instead, and creeping forward a little between bounds is
// what an overwatch does anyway -- the next bound re-orders them regardless.
private _fnc_hold = {
    params ["_grp", "_anchor"];
    [_grp] call _fnc_clearWp;
    _grp setBehaviour "COMBAT";
    _grp setCombatMode "RED";
    _grp setSpeedMode "LIMITED";
    { _x doWatch _anchor } forEach units _grp;
};

// One pass over the covering element per poll, splitting it by what each unit actually knows.
//
// A unit that knows about an enemy is left alone entirely and its doWatch released: RED plus a live
// target is what produces kills, and doSuppressiveFire is a fire-at-this-point order that would
// override the engagement it was about to make. Only the blind half area-fires, which is what
// suppression is for -- putting rounds on ground nobody can currently see into.
//
// Aimed at a position rather than at a unit: targeting the object would track a moving player,
// which is aimed fire wearing suppression's name. The position is the latest contact any covering
// unit knows about, falling back to what the caller passed, so a force that loses sight keeps
// working the spot it last had someone at rather than the one the bound opened on.
//
// Returns the updated aim point for the caller to carry into the next poll.
private _fnc_coverFire = {
    params ["_grps", "_aim"];
    private _blind = [];
    private _bestTgt = objNull;
    private _bestD = 1e10;
    {
        {
            if (alive _x) then {
                private _tgt = _x findNearestEnemy _x;
                if (isNull _tgt || {!alive _tgt}) then {
                    _blind pushBack _x;
                } else {
                    _x doWatch objNull;
                    private _d = _x distance2D _tgt;
                    if (_d < _bestD) then { _bestD = _d; _bestTgt = _tgt };
                };
            };
        } forEach units _x;
    } forEach _grps;

    private _at = _aim;
    if (!isNull _bestTgt) then { _at = getPos _bestTgt };
    // Area fire beyond SUPPRESS_RANGE empties magazines the group needs for the next bound and puts
    // rounds nowhere near a player who cannot hear them land.
    { if ((_x distance2D _at) < SUPPRESS_RANGE) then { _x doSuppressiveFire _at } } forEach _blind;
    _at
};

// Handed back as ordinary OPFOR, not deleted. allowFleeing is deliberately left at 0: a force that
// has already been ordered out once and could not break contact has nowhere to rout to, so it
// stands. Clearing DUWS_retreating returns them to the zone streaming sweep, which is what collects
// them once the player finally leaves.
private _fnc_standDown = {
    params ["_grps"];
    {
        private _grp = _x;
        {
            _x setVariable ["DUWS_retreating", nil];
            if (vehicle _x != _x) then { (vehicle _x) setVariable ["DUWS_retreating", nil] };
            _x doWatch objNull;
        } forEach units _grp;
        [_grp] call _fnc_clearWp;
        _grp enableAttack true;
        _grp setBehaviour "COMBAT";
        _grp setCombatMode "RED";
        _grp setSpeedMode "NORMAL";
    } forEach _grps;
};

// Corpses are left where they fell: bodies carry the search flag and are the garrison's payout, and
// the litter sweep already has a lifetime for them. Crew before their vehicle, or deleting the
// vehicle first ejects whoever is in it.
//
// A static weapon or a composition member is never taken with its crew. Zone emplacements pass to
// the player on capture and are exactly what a gunner ordered out of a lost zone is still sitting
// in, and a tracked composition member deleted behind its record's back leaves that record naming
// a null object. The zone despawn sweep spares statics for the same reason.
private _fnc_release = {
    params ["_grps"];
    {
        private _vehs = [];
        {
            if (alive _x) then {
                private _veh = vehicle _x;
                if (_veh != _x && {!(_veh isKindOf "StaticWeapon")}
                    && {!(_veh getVariable ["persistent", false])}) then {
                    _vehs pushBackUnique _veh;
                };
                deleteVehicle _x;
            };
        } forEach units _x;
        { if (alive _x) then { deleteVehicle _x } } forEach _vehs;
    } forEach _grps;
};

private _fnc_forceClear = {
    params ["_grps"];
    private _watched = false;
    {
        if (!_watched && {([_x] call _fnc_alive) > 0}) then {
            if ([getPos (leader _x), OBSERVE_RADIUS, 1] call fnc_duws_bluforNear) then {
                _watched = true;
            };
        };
    } forEach _grps;
    !_watched
};

{
    {
        // Read by the zone streaming sweep, which deletes every EAST unit inside a despawning
        // zone's radius -- towns sit on enemy zones by design, so a withdrawal crossing one would
        // otherwise be collected mid-retreat, in front of whoever pushed it out.
        _x setVariable ["DUWS_retreating", true];
        _x setVariable ["Vcm_Disable", true];
        if (vehicle _x != _x) then { (vehicle _x) setVariable ["DUWS_retreating", true] };
    } forEach units _x;
    // Fleeing AI abandon their waypoints and scatter, which is the one outcome a scripted
    // withdrawal cannot use: the bounds are the whole mechanic.
    _x allowFleeing 0;
} forEach _groups;

// Split on index parity rather than by strength: the callers hand over a garrison's spawn order, so
// alternate entries are already a patrol and a team rather than two of a kind.
private _elements = [[], []];
{ (_elements select (_forEachIndex % 2)) pushBack _x } forEach _groups;
private _moving = 0;

["INFO", "OPFOR", format ["%1 group(s) bounding back from %2",
    count _groups, mapGridPosition _holdPos]] call fnc_log;

// Resolved once and carried to both cards: the ground does not move, and a second lookup could
// disagree with the first if the zone were revealed part-way through the withdrawal.
private _place = [_holdPos] call _fnc_placeName;

// Announced rather than left to be noticed. A bounding withdrawal reads as a firefight the player
// is still losing until they see the ground behind it empty, and the whole mechanic is worth
// nothing if it is mistaken for the AI holding.
["info", [localize "STR_DUWS_T_OPFOR_WITHDRAW_TITLE",
    format [localize "STR_DUWS_T_OPFOR_WITHDRAW_MSG", _place]]]
    remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];

private _deadline = time + GIVE_UP;
private _outcome = "";

while {_outcome == ""} do {
    for "_i" from 0 to 1 do {
        private _kept = [];
        { if (!isNull _x && {([_x] call _fnc_alive) > 0}) then { _kept pushBack _x } }
            forEach (_elements select _i);
        _elements set [_i, _kept];
    };
    private _all = (_elements select 0) + (_elements select 1);
    if (count _all == 0) exitWith { _outcome = "wiped" };

    // The element whose turn it is may have been wiped since the last bound; the survivors move
    // rather than standing still waiting for cover that no longer exists.
    private _movers = _elements select _moving;
    private _cover = _elements select (1 - _moving);
    if (count _movers == 0) then { _movers = _cover; _cover = []; };

    ([[_all] call _fnc_centre, _holdPos] call _fnc_aim) params ["_dir", "_anchor", "_contact"];
    { [_x, _anchor] call _fnc_hold } forEach _cover;
    private _dests = _movers apply { [_x, _dir] call _fnc_move };

    // Carried across polls so the aim point tracks contact within the bound, not just between them.
    private _aim = _anchor;
    private _boundEnd = time + BOUND_TIMEOUT;
    while {true} do {
        if (_contact) then { _aim = [_cover, _aim] call _fnc_coverFire };
        sleep POLL_INTERVAL;
        if ([_all] call _fnc_forceClear) exitWith { _outcome = "clear" };
        if (time > _deadline) exitWith { _outcome = "shadowed" };
        if (time > _boundEnd) exitWith {};
        // Every mover on its mark ends the bound early rather than sitting out the timeout, which
        // is what keeps a short withdrawal from crawling.
        private _short = false;
        {
            if (([_x] call _fnc_alive) > 0
                && {(getPos (leader _x)) distance2D (_dests select _forEachIndex) > 50}) then {
                _short = true;
            };
        } forEach _movers;
        if (!_short) exitWith {};
    };

    _moving = 1 - _moving;
};

private _survivors = (_elements select 0) + (_elements select 1);
switch (_outcome) do {
    case "clear": {
        [_survivors] call _fnc_release;
        ["INFO", "OPFOR", format ["withdrawal from %1 broke contact; %2 group(s) despawned clear",
            mapGridPosition _holdPos, count _survivors]] call fnc_log;
        // Only this outcome is announced. "shadowed" puts the force back on its feet and the player
        // is already in contact with it, and "wiped" is a fight they watched themselves win.
        //
        // TODO: credit OPFOR army power here, for the survivors counted above. This is the one exit
        // that hands the enemy a force back intact, which is what makes it the site worth paying:
        // ground given up cheaply should buy the enemy something the player can later be made to
        // pay for. Until it lands, the card below promises manpower that no pool actually receives.
        ["info", [localize "STR_DUWS_T_OPFOR_ESCAPED_TITLE",
            format [localize "STR_DUWS_T_OPFOR_ESCAPED_MSG", _place]]]
            remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
    };
    case "shadowed": {
        [_survivors] call _fnc_standDown;
        ["WARN", "OPFOR", format ["withdrawal from %1 still in contact after %2 s; %3 group(s) stood back up to fight",
            mapGridPosition _holdPos, GIVE_UP, count _survivors]] call fnc_log;
    };
    default {
        ["INFO", "OPFOR", format ["withdrawal from %1 ended: no survivors",
            mapGridPosition _holdPos]] call fnc_log;
    };
};
