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

// Quiet time before a civilian is handed back their waypoints and can be called over again.
// Counted from the panic that started it and never extended -- see the guard below.
#define CALM_DELAY 60

params ["_unit", "_firer", ["_spread", true]];

// First, and alone on the hot path: a FiredNear handler sits on every civilian, so this is entered
// once per round per person within earshot and everything below is wasted on someone already
// running. An in-flight panic costs one getVariable and an exit. The consequence is deliberate --
// the calm-down is a flat count from the first round, so a fight outlasting it lets the crowd
// settle and be scattered again, which is the only re-check that has to happen. Doubles as the
// recursion guard for the sweep below. Broadcast, unlike the local flag this was: the call-over
// action's condition reads it, and that runs on every machine carrying the action.
if (_unit getVariable ["DUWS_civ_panicked", false]) exitWith {};

if (isNull _unit || {!alive _unit}) exitWith {};

// A surrendered civilian is already being held at gunpoint and the search action is waiting on
// them standing still. Letting a stray shot release them would hand the player an escape they
// never rolled for.
if (_unit getVariable ["isSurrendered", false]) exitWith {};

_unit setVariable ["DUWS_civ_panicked", true, true];

// One thread per panicking civilian, and a flat sleep rather than a poll on a deadline that
// nothing moves any more -- a 5 s waitUntil per fleeing civilian is a poll per person per tick
// for a whole town. Without this thread the flag never cleared and a town that heard one shot
// stayed uncallable for the rest of its occupancy.
// Orders are re-issued from wherever the flight ended, which may be well outside the town: the
// building list only supplies stroll targets, so a civilian who ran clear of it walks a circuit
// where they stand.
_unit spawn {
    sleep CALM_DELAY;
    if (!alive _this) exitWith {};
    _this setVariable ["DUWS_civ_panicked", false, true];
    // Everyone who fled one shot took the same bearing into the same nearestBuilding, so resuming
    // the remembered role would leave a stack of them standing in one house for the rest of the
    // occupancy. Walking is what breaks the clump: the circuits are drawn around each unit, so a
    // group that arrived together disperses over the roam radius. Cleared rather than passed as an
    // override because the flag dies with the unit -- a town's crowd is deleted when it empties,
    // so this cannot drift the stander/walker mix beyond the visit the firefight happened in.
    _this setVariable ["civ_idler", false];
    [_this] call fnc_civ_resume;
};

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
