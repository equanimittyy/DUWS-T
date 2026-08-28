// Locality: every machine (compiled in client_init, which the server runs too). remoteExec'd to each
// client by the patrol-camp mission builder to stand a medium wood-smoke column on a camp's campfire.
//
// Built per client rather than as one server-spawned object because the taller-than-inflame look needs a
// #particlesource, and a particle source carries no config: its emitter is set by the local setParticleClass
// command, so a single global spawn would render on the host alone. The stock smoke helper avoids this only
// because its emitters live in config and each client runs them off the shared object; the trade for the
// column we want is that each machine builds its own.
//
// Cleanup rides the fire, but explicitly. The source is attachTo'd to the global fire, and deleting an object
// only detaches its attached children -- it does not delete them -- so a source left to the engine keeps
// smoking from wherever the binned fire last stood. Storing it in the fire's `effects` array does not save
// this either: no reaper deletes a machine-local source when its shared parent is removed over the network.
// So each machine watches its own fire reference and deletes its own source once the fire is gone. isNull
// flips true wherever the fire is binned, host or client, so every machine reaps its own column, once.
params ["_fire"];
// A JIP joiner whose message arrives after the camp was retired has no fire to stand smoke on.
if (isNull _fire) exitWith {};

private _smoke = "#particlesource" createVehicleLocal getPosATL _fire;
_smoke setParticleClass "MediumDestructionSmoke";
_smoke attachTo [_fire, [0, 0, 0.3]];

[_fire, _smoke] spawn {
    params ["_fire", "_smoke"];
    waitUntil { sleep 2; isNull _fire };
    deleteVehicle _smoke;
};
