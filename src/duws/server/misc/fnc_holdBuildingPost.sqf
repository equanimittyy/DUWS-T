// Locality: server -- issues move orders and setPosATL, so it must run where the unit is local.
//
// Keeps one garrison unit at its post. Spawn it, never call it: HERD is an unbounded loop. Initial
// placement, behaviour and combat mode stay with the caller; this owns only the holding.
//
// One loop per unit rather than one monitor walking the group: a group-wide monitor has to
// re-derive which building each unit belongs to on every pass, where a per-unit loop captures the
// building and its position list for free.
//
// **Neither mode may outlive an order given later.** A zone that falls sends its survivors off with
// a MOVE waypoint, and a hold that goes on asserting a position beats that order every time -- so
// the garrison stayed in its houses and was collected on distance instead of walking out. PIN is a
// one-shot for that reason and HERD stands down when its post is released.
//
// PIN places once, lets the unit settle, and places it again. The re-place is the whole body: a
// setPosATL taken on the frame a unit spawns is routinely undone as the engine beds it into the
// geometry, and a tower guard that lands beside his catwalk instead of on it is not a tower guard.
// It used to hold that spot for the unit's whole life on a 3 m leash, which is what fought the
// withdrawal -- and cost a permanent thread per man for a unit that has no waypoints to wander on
// anyway.
//
// _stance "" leaves the caller's stance alone. intel_gathering picks UP or MIDDLE per unit, and
// re-asserting one stance here would flatten every prone-ish unit to standing.
params ["_unit", "_building", "_positions", ["_mode", "HERD"], ["_stance", ""]];

if (_positions isEqualTo []) exitWith {};

if (_mode == "PIN") exitWith {
    private _fixedPos = _positions select 0;
    sleep 1;
    if (alive _unit) then { _unit setPosATL _fixedPos };
};

// Parenthesised because a unary command binds tighter than `+`: `sleep 2 + random 5` is
// `(sleep 2) + (random 5)`, which sleeps a flat 2 s and discards the stagger silently.
sleep (2 + random 5);
// Released is checked here rather than acted on from outside, because the doMove below is what has
// to stop: whoever releases the post has already given this man somewhere else to be. Read off the
// unit, not its group -- a withdrawal can leave one man behind in a group that has moved on.
while {alive _unit && {!(_unit getVariable ["DUWS_postReleased", false])}} do {
    private _targetPos = _building buildingPos (floor (random (count _positions)));
    _unit doMove _targetPos;
    if (_stance != "") then { _unit setUnitPos _stance };
    private _timeout = time + 30;
    waitUntil {
        sleep 5;
        (unitReady _unit) ||
        (!alive _unit) ||
        (_unit distance _targetPos < 2) ||
        (time > _timeout) ||
        (_unit getVariable ["DUWS_postReleased", false])
    };
    // Tested twice, here and at the top: the doMove above outranks a waypoint until this loop stops
    // reissuing it, and waiting out the settle sleep as well as the timeout would leave a released
    // man standing in his house for the best part of a minute after the zone had already fallen.
    if (_unit getVariable ["DUWS_postReleased", false]) exitWith {};
    sleep (5 + random 15);
};
