if (!isServer) exitWith {};
params ["_unit"];
// Kept low so battlefield pickups do not out-earn holding ground.
//
// Money only. Intel documents come from the search gate instead, which drops only ground-item
// classes that survive being dropped: a raw magazine class has no ground variant, so a looted one
// would vanish the instant the player dropped it.
if (random 1 < 0.5) then { _unit addMagazineGlobal "Money_roll" };