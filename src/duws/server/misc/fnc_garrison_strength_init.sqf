// Garrison attrition, shared by every kind of ground that holds one.
//
// Executed by the registry rather than stored as one function: this file defines several. Loaded
// ahead of both fnc_zone_state_init and fnc_civ_state_init, which are its two consumers.
//
// A zone and a town differ in what they *are* -- one has an owner, the other an opinion -- but not
// in how a garrison wears down. Both raise a composition, both get ground down by the same player,
// and both have to come back at what was left rather than at what they started with. So this is one
// store keyed by a string: `zone_<x>_<y>` for a zone, `town_<n>` for a town. Callers own their key
// format and nothing here inspects it.

// The strength a garrison redeploys at, as a fraction. Full for ground nobody has fought over.
DUWS_fnc_garrisonStrength = {
	params ["_key"];
	missionNamespace getVariable [format ["DUWS_garrisonStrength_%1", _key], 1]
};

// The only writer, so a mechanic that lets either side rebuild a mauled garrison has a single place
// to go through and inherits the quantisation and the floor rather than restating them.
//
// **Tenths, because this is a spawn budget and not a casualty ledger.** What it scales is whole
// groups, whole buildings and whole emplacements, so finer resolution rounds away at the point of
// use. The epsilon absorbs float slop rather than shifting the rule: SQF scalars are 32-bit floats,
// and a division landing a hair above an exact tenth would buy the garrison a whole free step.
//
// **The 0.3 floor is the mechanic, not a guard.** Against the 0.1 break line the zone capture test
// uses, a garrison at the floor still sits two tenths above beaten, so retaking ground you softened is
// a fight rather than a walk-in. For a zone it is also structural: one allowed to redeploy empty would
// be uncapturable outright, because a zero peak refuses capture.
DUWS_fnc_garrisonStrengthSet = {
	params ["_key", "_frac"];
	private _q = ((ceil ((_frac * 10) - 0.0001)) / 10) max 0.3 min 1;
	missionNamespace setVariable [format ["DUWS_garrisonStrength_%1", _key], _q];
	_q
};

// Records what a garrison was ground down to: survivors against the force it was given, and never
// upward. Clamped to what it already deployed at because every consumer rounds its own share up and
// keeps at least one of whatever it is placing -- a garrison sent out at three tenths stands nearer
// four, so a raw measurement would have an untouched one climb a step on every visit and heal itself
// back to full for free.
// A zero or missing baseline means no cycle ever finished placing, so there is nothing to measure
// against and what is standing describes a garrison that was still arriving.
DUWS_fnc_garrisonStrengthRecord = {
	params ["_key", "_left", "_base"];
	if (_base <= 0) exitWith { [_key] call DUWS_fnc_garrisonStrength };
	[_key, (_left / _base) min ([_key] call DUWS_fnc_garrisonStrength)] call DUWS_fnc_garrisonStrengthSet
};

// The key a town files under. Zones derive theirs through fnc_zone_key, which predates this and is
// used for far more than strength; a town has no such key, so this is the whole of it.
DUWS_fnc_townStrengthKey = {
	params ["_townIndex"];
	format ["town_%1", _townIndex]
};
