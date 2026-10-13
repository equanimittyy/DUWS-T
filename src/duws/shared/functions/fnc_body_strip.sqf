// Locality: the machine where the corpse is local, because every remove command here takes a local unit.
// _worn holds getUnitLoadout slot indices: 3 uniform, 4 vest, 5 backpack, 6 headgear, 7 goggles.
params ["_body", "_weapons", "_worn", "_linked"];
{ _body removeWeapon _x } forEach _weapons;
if (3 in _worn) then { removeUniform _body };
if (4 in _worn) then { removeVest _body };
if (5 in _worn) then { removeBackpack _body };
if (6 in _worn) then { removeHeadgear _body };
if (7 in _worn) then { removeGoggles _body };
{ _body unlinkItem _x } forEach _linked;
