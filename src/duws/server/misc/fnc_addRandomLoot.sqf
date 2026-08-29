if (!isServer) exitWith {};
params ["_unit"];
// Roughly three enemies in five carry money, thinned from four in five so battlefield pickups do
// not out-earn holding ground.
//
// Money only. Intel documents come from the search gate instead, which drops only ground-item
// classes that survive being dropped: a raw magazine class has no ground variant, so a looted one
// would vanish the instant the player dropped it.
if (random 1 > 0.6) exitWith {};
private _count = floor random 3; // 0,1,2
for "_i" from 1 to _count do {
    _unit addMagazineGlobal "Money_roll";
};