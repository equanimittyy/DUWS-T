// Locality: server -- issues move orders and setPosATL, so it must run where the unit is local.
//
// Keeps one garrison unit at its post: a doMove loop between the building's positions that leaves the
// unit's pathing on, so it works the building and fights rather than freezing on one spot. Spawn it,
// never call it -- the loop is unbounded. Initial placement, behaviour and combat mode stay with the
// caller; this owns only the holding.
//
// One loop per unit rather than one monitor walking the group: a group-wide monitor has to
// re-derive which building each unit belongs to on every pass, where a per-unit loop captures the
// building and its position list for free.
//
// _stance "" leaves the caller's stance alone. The informant hunt picks UP or MIDDLE per unit, and
// re-asserting one stance here would flatten every prone-ish unit to standing.
params ["_unit", "_building", "_positions", ["_stance", ""]];

if (_positions isEqualTo []) exitWith {};

// Parenthesised because a unary command binds tighter than `+`: `sleep 2 + random 5` is
// `(sleep 2) + (random 5)`, which sleeps a flat 2 s and discards the stagger silently.
sleep (2 + random 5);
while {alive _unit} do {
    private _targetPos = _building buildingPos (floor (random (count _positions)));
    _unit doMove _targetPos;
    if (_stance != "") then { _unit setUnitPos _stance };
    private _timeout = time + 30;
    waitUntil {
        sleep 5;
        (unitReady _unit) ||
        (!alive _unit) ||
        (_unit distance _targetPos < 2) ||
        (time > _timeout)
    };
    sleep (5 + random 15);
};
