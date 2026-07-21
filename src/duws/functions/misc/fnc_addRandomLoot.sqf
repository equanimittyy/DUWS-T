// fnc_addRandomLoot.sqf
// 给单个敌人步兵添加随机战利品
if (!isServer) exitWith {};
params ["_unit"];
if (random 1 > 0.8) exitWith {};
private _lootPool = ["Money_roll", "Files", "Wallet_ID"];
private _count = floor random 3; // 0,1,2
for "_i" from 1 to _count do {
    private _item = selectRandom _lootPool;
    _unit addMagazineGlobal _item;
};