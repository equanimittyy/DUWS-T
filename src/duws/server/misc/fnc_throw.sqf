// Locality: server -- thrown junk, a mod-free stand-in for a hurled object. A real physics body so it bounces
// off walls and vehicles; createVehicle is global, so one server object networks to every machine (no per-client
// draw). No damage by design -- the crowd harasses, it does not kill.
if (!isServer) exitWith {};
params [["_thrower", objNull], ["_to", [0, 0, 0]]];
if (isNull _thrower) exitWith {};

// Small vanilla debris, each a dynamic body that bounces; random pick for a mixed volley.
#define THROW_JUNK ["Land_Can_Dented_F", "Land_Can_V2_F", "Land_Can_V3_F", "Land_Can_Rusty_F", "Land_Can_V1_F", "Land_BakedBeans_F", "Land_BottlePlastic_V1_F", "Land_BottlePlastic_V2_F", "Land_TacticalBacon_F"]

private _from = eyePos _thrower;
// Flight time from range, jittered x0.8-1.05 (biased under 1 to stay readable, never floaty), clamped [1.1, 3.5].
private _dur = ((((_from distance2D _to) / 8) * (0.8 + random 0.25)) max 1.1) min 3.5;

// Spawn a hand's length ahead of the eyes: a physics body created clipping the thrower is flung (arma_engine_gotchas.md).
private _dir = vectorNormalized (_to vectorDiff _from);
private _spawn = _from vectorAdd (_dir vectorMultiply 0.5);

// Throw gesture on every machine; an unknown action name is a silent no-op, so safe if it ever changes.
[_thrower, "throwGrenade"] remoteExec ["playActionNow", 0];

// CAN_COLLIDE so the engine drops it exactly where told, not nudged clear of nearby geometry.
private _obj = createVehicle [selectRandom THROW_JUNK, _spawn, [], 0, "CAN_COLLIDE"];
_obj setPosASL _spawn;
_obj setMass 1;   // featherweight so a collision nudges a player, never kills (impact scales with mass); still bounces
// Ballistic launch: velocity to reach _to in _dur under 9.81 gravity (4.905 = g/2). _loft varies arc height on its
// own -- above 1 lofts higher and lands a touch long.
private _d = _to vectorDiff _spawn;
private _loft = 0.9 + random 0.4;
_obj setVelocity [(_d select 0) / _dur, (_d select 1) / _dur, (((_d select 2) + 4.905 * _dur * _dur) / _dur) * _loft];
_obj setAngularVelocity [random 16 - 8, random 16 - 8, random 16 - 8];   // random tumble per axis, so none slides flat

[_obj, _to, _dur] spawn {
	params ["_obj", "_to", "_dur"];
	sleep _dur;
	// [[...]] passes the array as ONE operand: remoteExec reads a command's operands (max 2), so a bare 3-element array throws.
	{ [[1.5, 0.8, 15]] remoteExec ["addCamShake", _x] } forEach (allPlayers select { alive _x && {(_x distance2D _to) < 3} });
	sleep 5;   // let it settle after bouncing before it vanishes
	if (!isNull _obj) then { deleteVehicle _obj };
};
