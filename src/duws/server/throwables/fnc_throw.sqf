// Locality: server -- thrown junk, the mod-free stand-in for a hurled object. A real dynamic body created and
// launched with setVelocity, so PhysX flies it, drops it under gravity, and bounces it off walls and vehicles.
// createVehicle is global, so the one server-simulated object renders and physics-networks to every machine --
// no per-client cosmetic. Does no damage: the crowd harasses, it does not kill (a camera knock sells the miss).
if (!isServer) exitWith {};
params [["_thrower", objNull], ["_to", [0, 0, 0]]];
if (isNull _thrower) exitWith {};

// Small vanilla debris that simulates as a dynamic PhysX body, picked at random so a volley is not all one can.
#define THROW_JUNK ["Land_Can_Dented_F", "Land_Can_V2_F", "Land_Can_V3_F", "Land_Can_Rusty_F", "Land_Can_V1_F", "Land_BakedBeans_F", "Land_BottlePlastic_V1_F", "Land_BottlePlastic_V2_F", "Land_TacticalBacon_F"]

private _from = eyePos _thrower;
// Flight time from horizontal range: a slow, high lob you can actually watch, clamped so a point-blank throw
// still arcs and a long heave is not floaty.
private _dur = (((_from distance2D _to) / 8) max 1.2) min 3.5;

// Spawn a hand's length in front of the eyes, not on them: a physics body created clipping the thrower's own
// head takes a collision impulse off it and is flung (arma_engine_gotchas.md). The thrower already faces _to.
private _dir = vectorNormalized (_to vectorDiff _from);
private _spawn = _from vectorAdd (_dir vectorMultiply 0.5);

// Throw gesture on every machine. "throwGrenade" is the engine's own throw action; an unknown name is a silent
// no-op, so this stays safe if it ever changes.
[_thrower, "throwGrenade"] remoteExec ["playActionNow", 0];

// CAN_COLLIDE so the engine drops it exactly where told rather than nudging it clear of nearby geometry.
private _obj = createVehicle [selectRandom THROW_JUNK, _spawn, [], 0, "CAN_COLLIDE"];
_obj setPosASL _spawn;
// Launch velocity that reaches _to in _dur under 9.81 gravity (vertical term counters the drop); PhysX and any
// obstacle in the path take it from there.
private _d = _to vectorDiff _spawn;
_obj setVelocity [(_d select 0) / _dur, (_d select 1) / _dur, ((_d select 2) + 4.905 * _dur * _dur) / _dur];

[_obj, _to, _dur] spawn {
	params ["_obj", "_to", "_dur"];
	sleep _dur;
	// addCamShake is a command, wrapped in an extra array: remoteExec reads the params as a command's operand
	// list (max 2), so a bare 3-element array counts as three operands and throws. [[...]] passes one operand.
	{ [[1.5, 0.8, 15]] remoteExec ["addCamShake", _x] } forEach (allPlayers select { alive _x && {(_x distance2D _to) < 3} });
	sleep 3;   // let it finish bouncing and settle before it vanishes
	if (!isNull _obj) then { deleteVehicle _obj };
};
