// Locality: server -- a scripted lob, the mod-free stand-in for a thrown weapon. Custom throwables cannot
// exist without an addon: a magazine/weapon/ammo defined in description.ext lives in missionConfigFile, which
// addMagazines and muzzle bindings never see -- they resolve against configFile (arma_engine_gotchas.md). So
// nothing is thrown through the inventory; this arcs a cosmetic stone from the thrower to a point and owns the
// landing effect. The flight is drawn on every machine (fnc_throw_visual, createSimpleObject is local).
if (!isServer) exitWith {};
params [["_thrower", objNull], ["_to", [0, 0, 0]]];
if (isNull _thrower) exitWith {};

private _from = eyePos _thrower;
// Flight time from horizontal range: a slow, high lob you can actually watch, clamped so a point-blank throw
// still arcs and a long heave is not floaty.
private _dur = (((_from distance2D _to) / 8) max 1.2) min 3.5;

// Throw gesture on every machine, launched with the projectile. "throwGrenade" is the engine's own throw
// action, so it animates for the thrower's stance (unarmed here); an unknown action name is a silent no-op,
// so this stays safe if the name ever changes.
[_thrower, "throwGrenade"] remoteExec ["playActionNow", 0];
[_from, _to, _dur] remoteExec ["fnc_throw_visual", 0];

// Stone does no damage -- the crowd harasses, it does not kill. Sell the hit with a firm camera knock on any
// player it lands beside.
[_to, _dur] spawn {
	params ["_to", "_dur"];
	sleep _dur;
	// addCamShake is a command, wrapped in an extra array: remoteExec reads the params as a command's operand
	// list (max 2), so the bare 3-element array counted as three operands and threw. [[...]] passes one operand.
	{
		[[1.5, 0.8, 15]] remoteExec ["addCamShake", _x];
	} forEach (allPlayers select { alive _x && {(_x distance2D _to) < 3} });
};
