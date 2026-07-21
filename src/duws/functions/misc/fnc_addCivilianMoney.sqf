// fnc_addCivilianMoney.sqf
// 给平民单位添加随机数量（0-2）的 Money_roll
if (!isServer) exitWith {};
params ["_unit"];
private _count = 0 + floor random 2; // 0 到 2
for "_i" from 1 to _count do {
    _unit addMagazineGlobal "Money_roll";
}; 