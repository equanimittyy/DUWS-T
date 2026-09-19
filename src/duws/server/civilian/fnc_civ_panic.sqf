// Locality: server -- civilians are local to it, and doMove is ignored on any other machine.
/*
    Breaks one civilian off whatever they were doing and sends them away from a shot, into the
    nearest building if there is one. Params: [_unit, _firer, _spread].
*/
if (!isServer) exitWith {};

// How far the alarm carries past the engine's own FiredNear radius, which is short enough that a
// shot across a square would otherwise empty only the corner that heard it.
#define ALARM_RADIUS 150

// Measured from the civilian, not the shot: what matters is that they end up out of the fight.
#define FLEE_DISTANCE 200

// Quiet time before a civilian is handed back their waypoints and can be called over again.
// Counted from the panic that started it and never extended -- see the guard below.
#define CALM_DELAY 60

params ["_unit", "_firer", ["_spread", true]];

// First and alone on the hot path: a FiredNear handler fires once per round per civilian in earshot, so
// most calls land on someone already panicking -- an in-flight panic costs one getVariable and an exit.
// Doubles as the recursion guard for the sweep below. Broadcast, not local: the call-over action's
// condition reads it on every machine carrying the action.
if (_unit getVariable ["DUWS_civ_panicked", false]) exitWith {};

if (isNull _unit || {!alive _unit}) exitWith {};

// A surrendered civilian is already being held at gunpoint and the search action is waiting on
// them standing still. Letting a stray shot release them would hand the player an escape they
// never rolled for.
if (_unit getVariable ["isSurrendered", false]) exitWith {};

// A civilian side mission's giver holds still where the task pin shows them until the mission ends.
if ((_unit getVariable ["DUWS_civMission_state", ""]) != "") exitWith {};

_unit setVariable ["DUWS_civ_panicked", true, true];

// Broadcast, because the interaction action's condition is evaluated on every machine that
// carries it: someone running for cover is not standing still to be talked to.
_unit setVariable ["DUWS_civ_stopped", false, true];

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
private _inCover = false;
private _cover = nearestBuilding _away;
if (!isNull _cover) then {
    private _positions = [_cover] call BIS_fnc_buildingPositions;
    if (count _positions > 0) then {
        _dest = selectRandom _positions;
        _inCover = true;
    };
};

_unit doMove _dest;

// One thread per panicking civilian, watching the run in: the engine raises nothing when a doMove lands,
// so arrival is polled -- but only inside the calm-down this thread sleeps through anyway. Without it the
// flag never cleared and a town that heard one shot stayed uncallable for its whole occupancy. Orders
// resume from wherever the flight ended (maybe outside town): the building list only supplies stroll
// targets, so a civilian clear of it walks a circuit where they stand.
[_unit, _dest, _inCover] spawn {
    params ["_unit", "_dest", "_inCover"];
    private _settle = time + CALM_DELAY;

    if (_inCover) then {
        waitUntil { sleep 2; !alive _unit || {time > _settle} || {_unit distance _dest < 3} };
        // Weighted to crouching: a room where everyone is upright reads as a queue, one where
        // everyone is flat as a massacre. Taken on arrival and not before -- setUnitPos on a unit
        // still pathing turns the run for cover into a crawl.
        if (alive _unit) then { _unit setUnitPos (selectRandom ["UP", "MIDDLE", "MIDDLE", "DOWN"]) };
    };

    if (time < _settle) then { sleep (_settle - time) };
    if (!alive _unit) exitWith {};
    _unit setVariable ["DUWS_civ_panicked", false, true];
    // UP rather than AUTO: AUTO hands the stance back to an AI that has just been shot at and can
    // keep them flat, so a calmed civilian would crawl their circuit. A civilian has no tactical
    // reason to be anywhere but on their feet.
    _unit setUnitPos "UP";
    [_unit] call fnc_civ_resume;
};

if (_spread) then {
    {
        [_x, _firer, false] call fnc_civ_panic;
    } forEach ((_unit nearEntities ["CAManBase", ALARM_RADIUS]) select {
        (_x getVariable ["civ_locIndex", -1]) > -1 && {!(_x getVariable ["civ_isZombie", false])}
    });
};
