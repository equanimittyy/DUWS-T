// Locality: any. Pure -- no engine state, so the unit tests drive it directly.

// The camouflageCoef a BLUFOR unit earns for how it is moving inside a covert mission's radius. A lower
// value only makes the engine slower to acquire it, so this biases detection rather than gating it: the
// cordon still arms its alarm on its own nearTargets/knowsAbout test.
//
// The three inputs multiply rather than the worst one winning, so stacking good behaviour compounds.
//
// _firedAgo is seconds since the unit last fired; one that never fired passes any value past the window.
params ["_stance", "_speed", "_firedAgo"];

// A prone sprint is 4.8 km/h, slower than a standing slow-walk at 5.1, so global speed bands would read
// every prone unit as barely moving however fast it crawled. Boundaries sit midway between the game's own
// forward speeds for that stance, primary weapon. Prone slow-walk and walk are one speed: no walk band.
private _row = switch (toUpper _stance) do {
    case "PRONE":  { [0.5, 2.5, 2.5, 3.8] };
    case "CROUCH": { [0.75, 6.3, 9.8, 13.9] };
    default        { [1, 8.1, 12, 15.5] };
};
_row params ["_stanceMult", "_bSlow", "_bWalk", "_bCombat"];

private _spd = abs _speed;
private _speedMult = 1;
if (_spd < _bCombat) then { _speedMult = 0.9 };
if (_spd < _bWalk)   then { _speedMult = 0.8 };
if (_spd < _bSlow)   then { _speedMult = 0.65 };
if (_spd < 1)        then { _speedMult = 0.5 };

// Firing costs position for a moment without branding the shooter for the rest of the approach.
private _firedMult = 0.8 + (0.2 * (1 - (((_firedAgo / 5) max 0) min 1)));

// Every factor is a discount from vanilla, so the worst case is 1.0: this can only ever help.
((_stanceMult * _speedMult * _firedMult) max 0.2) min 1
