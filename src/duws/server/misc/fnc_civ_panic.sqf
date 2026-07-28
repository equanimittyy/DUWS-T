// Locality: server -- civilians are local to it, and doMove is ignored on any other machine.
/*
    fnc_civ_panic.sqf
    Breaks one civilian off whatever they were doing and sends them away from a shot, into the
    nearest building if there is one. Params: [_unit, _firer, _spread].
*/
if (!isServer) exitWith {};

// How far the alarm carries past the engine's own FiredNear radius, which is short enough that a
// shot across a square would otherwise empty only the corner that heard it.
#define ALARM_RADIUS 150

// Measured from the civilian, not the shot: what matters is that they end up out of the fight.
#define FLEE_DISTANCE 200

params ["_unit", "_firer", ["_spread", true]];

if (isNull _unit || {!alive _unit}) exitWith {};

// A surrendered civilian is already being held at gunpoint and the search action is waiting on
// them standing still. Letting a stray shot release them would hand the player an escape they
// never rolled for.
if (_unit getVariable ["isSurrendered", false]) exitWith {};

// One panic per person, and the flag is what keeps the sweep below from recursing: everyone it
// reaches is marked before it reaches them, so their own FiredNear handlers exit here.
if (_unit getVariable ["DUWS_civ_panicked", false]) exitWith {};
_unit setVariable ["DUWS_civ_panicked", true];

// Broadcast, because the interaction action's condition is evaluated on every machine that
// carries it: someone running for cover is not standing still to be talked to.
_unit setVariable ["DUWS_civ_stopped", false, true];

// The pose holds the unit's AI while it runs, so a civilian left mid-smoke would stand through
// the whole firefight.
if (_unit getVariable ["civ_posed", false]) then {
    [_unit] call BIS_fnc_ambientAnim__terminate;
    _unit setVariable ["civ_posed", false];
};

private _group = group _unit;

// Back to front: deleteWaypoint shifts every later index down, so a forward pass over the list
// deletes every other waypoint and leaves the rest standing. `reverse` cannot be inlined into the
// forEach -- it reverses in place and returns Nothing.
private _wps = waypoints _group;
reverse _wps;
{ deleteWaypoint _x } forEach _wps;

_unit enableAI "PATH";

// CARELESS, not COMBAT: it keeps them running in a straight line instead of bounding between
// cover, which is the difference between a civilian fleeing and a soldier fighting.
_group setBehaviour "CARELESS";
_group setSpeedMode "FULL";

private _bearing = if (isNull _firer) then { random 360 } else { _firer getDir _unit };
private _away = _unit getPos [FLEE_DISTANCE, _bearing];

private _dest = _away;
private _cover = nearestBuilding _away;
if (!isNull _cover) then {
    private _positions = [_cover] call BIS_fnc_buildingPositions;
    if (count _positions > 0) then { _dest = selectRandom _positions };
};

_unit doMove _dest;

if (_spread) then {
    {
        [_x, _firer, false] call fnc_civ_panic;
    } forEach ((_unit nearEntities ["CAManBase", ALARM_RADIUS]) select {
        (_x getVariable ["civ_locIndex", -1]) > -1 && {!(_x getVariable ["civ_isZombie", false])}
    });
};
