// Locality: server. True while _unit is in a fight: its behaviour is COMBAT, or it still knows its nearest
// living player. Shared by OPCOM and hardpoint streaming, which hold a stow for it, and the map cleanup,
// which holds a deletion for it, so the three agree on what engaged means.
// COMBAT is the engine's contact state for a group spawned SAFE or AWARE, and it catches a fight with
// BLUFOR AI that no player is part of. knowsAbout decays over minutes after contact breaks
// (arma_engine_gotchas.md), which is the grace: a unit is not stowed or deleted the moment it loses sight.
params ["_unit"];
if (behaviour _unit isEqualTo "COMBAT") exitWith { true };
private _pl = (allPlayers select { alive _x }) apply { [_unit distance _x, _x] };
if (_pl isEqualTo []) exitWith { false };
_pl sort true;
(_unit knowsAbout ((_pl select 0) select 1)) > 1.5
