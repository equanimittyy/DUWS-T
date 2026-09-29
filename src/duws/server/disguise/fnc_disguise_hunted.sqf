// True while a living unit of _sides near the player holds a current nearTargets fix on them. Not
// knowsAbout: that is side-wide and decays over minutes, so it reads a player as hunted long after
// contact ends. The age gate cannot go below the engine's re-fix cycle (arma_engine_gotchas.md).
#define HUNT_RANGE 300
#define HUNT_FRESH 5

params ["_player", "_sides"];

private _observers = [];
{ _observers append (crew _x) } forEach (_player nearEntities [["AllVehicles"], HUNT_RANGE]);

(_observers findIf {
    alive _x && {side group _x in _sides} && {
        ((_x nearTargets HUNT_RANGE) findIf { (_x select 4) isEqualTo _player && {(_x select 5) <= HUNT_FRESH} }) >= 0
    }
}) >= 0
