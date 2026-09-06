// Locality: server -- a scripted lob, the mod-free stand-in for a thrown weapon. Custom throwables cannot
// exist without an addon: a magazine/weapon/ammo defined in description.ext lives in missionConfigFile, which
// addMagazines and muzzle bindings never see -- they resolve against configFile (arma_engine_gotchas.md). So
// nothing is thrown through the inventory; this arcs a cosmetic object from the thrower to a point and owns
// the landing effect. The flight is drawn on every machine (fnc_throw_visual, createSimpleObject is local).
if (!isServer) exitWith {};
params [["_thrower", objNull], ["_to", [0, 0, 0]], ["_kind", "stone"]];
if (isNull _thrower) exitWith {};

private _from = eyePos _thrower;
// Flight time from horizontal range, clamped so a point-blank lob still arcs and a long heave is not floaty.
private _dur = (((_from distance2D _to) / 14) max 0.6) min 2.5;

// Throw gesture on every machine, launched with the projectile. "throwGrenade" is the engine's own throw
// action, so it animates for the thrower's stance (unarmed here); an unknown action name is a silent no-op,
// so this stays safe if the name ever changes.
[_thrower, "throwGrenade"] remoteExec ["playActionNow", 0];
[_kind, _from, _to, _dur] remoteExec ["fnc_throw_visual", 0];

[_kind, _to, _dur] spawn {
	params ["_kind", "_to", "_dur"];
	sleep _dur;
	// Molotov lands as a scripted fire (server owns the networked flame); ignite works in ATL.
	if (_kind == "molotov") exitWith { [ASLToATL _to] call fnc_molotov_ignite; };
	// Stone does no damage -- the crowd harasses, it does not kill. Sell the hit instead: a thud at the
	// impact that carries to everyone near, and a firm camera knock on any player it lands beside.
	["duws\shared\sounds_npics\support\thud.wav", objNull, false, _to, 1.6, 1, 70] remoteExec ["playSound3D", 0];
	{
		[3, 0.8, 15] remoteExec ["addCamShake", _x];
	} forEach (allPlayers select { alive _x && {(_x distance2D _to) < 3} });
};
