// fnc_addRandomLoot.sqf
if (!isServer) exitWith {};
params ["_unit"];
// Roughly three enemies in five carry anything, thinned from four in five: intel is the input to a
// CP faucet with no cooldown, so fewer bodies holding documents is what keeps loot from out-earning
// held ground, rather than a cap on the turn-in.
if (random 1 > 0.6) exitWith {};
private _lootPool = ["Money_roll", "Files", "Wallet_ID"];
private _count = floor random 3; // 0,1,2
for "_i" from 1 to _count do {
    private _item = selectRandom _lootPool;
    _unit addMagazineGlobal _item;
};