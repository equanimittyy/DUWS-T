// Locality: any. Pure -- no engine state, so the unit tests drive it directly.

// The camouflageCoef a BLUFOR unit earns for how it is moving inside a covert mission's radius. A lower
// value only makes the engine slower to acquire it, so this biases detection rather than gating it: the
// cordon still arms its alarm on its own nearTargets/knowsAbout test.
//
// The three inputs multiply rather than the worst one winning, so stacking good behaviour compounds.
//
// _firedAgo is seconds since the unit last fired; one that never fired passes any value past the window.
params ["_stance", "_speed", "_firedAgo"];

private _stanceMult = switch (toUpper _stance) do {
    case "PRONE":  { 0.625 };
    case "CROUCH": { 0.8 };
    default        { 1 };
};

// A man walks at about 5 km/h, runs at about 12, and sprints past 14.
private _spd = abs _speed;
private _speedMult = 1.12;
if (_spd < 14) then { _speedMult = 1.05 };
if (_spd < 6)  then { _speedMult = 1 };
if (_spd < 1)  then { _speedMult = 0.8 };

// Firing costs position for a moment without branding the shooter for the rest of the approach.
private _firedMult = 1 + (0.1 * (1 - (((_firedAgo / 5) max 0) min 1)));

// Prone and still is exactly the floor, and only a standing sprinter who just fired overruns the ceiling.
((_stanceMult * _speedMult * _firedMult) max 0.5) min 1.2
