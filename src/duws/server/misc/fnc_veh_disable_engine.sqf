// Locality: server. Kill every engine hit point so a spawned derelict can't drive until repaired.
// Name-matched ("engine") so modded/multi-engine hulls are caught too. Call AFTER setDamage --
// setDamage redistributes across hit points and would revive the engine.
params ["_veh"];
{
    if (toLower _x find "engine" >= 0) then { _veh setHitPointDamage [_x, 1] };
} forEach (getAllHitPointsDamage _veh param [0, []]);
