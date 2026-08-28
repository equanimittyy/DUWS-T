// Locality: every machine (compiled in client_init, which the server runs too). remoteExec'd to each
// client by the patrol-camp mission builder to stand a medium wood-smoke column on a camp's campfire.
//
// Built per client rather than as one server-spawned object because the taller-than-inflame look needs a
// #particlesource, and a particle source carries no config: its emitter is set by the local setParticleClass
// command, so a single global spawn would render on the host alone. The stock smoke helper avoids this only
// because its emitters live in config and each client runs them off the shared object; the trade for the
// column we want is that each machine builds its own.
//
// Cleanup rides the fire: the source is hung in the fire object's `effects` array, and the engine deletes
// every object in a parent's effects array when that parent is deleted. The campfire is a kept composition
// member, so when the camp is retired and the fire binned on every machine, the column goes with it on every
// machine -- no separate teardown, and none possible through fnc_duws_keep, which tracks global members only.
params ["_fire"];
// A JIP joiner whose message arrives after the camp was retired has no fire to stand smoke on.
if (isNull _fire) exitWith {};

private _smoke = "#particlesource" createVehicleLocal getPosATL _fire;
_smoke setParticleClass "MediumDestructionSmoke";
_smoke attachTo [_fire, [0, 0, 0.3]];
_fire setVariable ["effects", (_fire getVariable ["effects", []]) + [_smoke]];
