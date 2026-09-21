// Locality: any -- the catalogue prints what the server will charge, and the server recomputes it
// when the row is actually bought, so the two can never quote different prices.
/*
    What one gear class costs in Money_roll. Params: [_class]. Returns a positive count, or -1 for a
    class no vendor may sell -- which is also what makes this the single gate on sellability.

    Banded by what the class is rather than priced per class, so a modded server's gear is priced with
    no table to maintain. The bands themselves are untuned: prices are balanced against job payouts in
    the jobs plan's balance phase, once a paid job exists to weigh them against.
*/
params ["_class"];

// Selling the currency for the currency would be a loop with a profit in it.
if (_class isEqualTo "Money_roll") exitWith { -1 };

if (isNull ([_class] call fnc_vendor_classCfg)) exitWith { -1 };

if (isClass (configFile >> "CfgMagazines" >> _class)) exitWith { 1 };
if (isClass (configFile >> "CfgGlasses" >> _class)) exitWith { 1 };
if (_class isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) exitWith { 3 };

// Cars and boats. Seats are the closest thing to a value proxy config carries without a table per
// class, so a quadbike and a van do not cost the same.
if (_class isKindOf ["Car", configFile >> "CfgVehicles"]
    || {_class isKindOf ["Ship", configFile >> "CfgVehicles"]}) exitWith {
    20 + 3 * (getNumber (configFile >> "CfgVehicles" >> _class >> "transportSoldier"))
};

// Anything left that is not gear has no band, so it has no price and cannot be sold -- which is what
// keeps a tank off a forecourt even if one reached this far.
if (!isClass (configFile >> "CfgWeapons" >> _class)) exitWith { -1 };

// CfgWeapons holds the guns and everything worn or clipped to one. type is the engine's own split:
// 1 primary, 2 handgun, 4 launcher; clothing and attachments carry neither.
switch (getNumber (configFile >> "CfgWeapons" >> _class >> "type")) do {
    case 4: { 25 };
    case 1: { 10 };
    case 2: { 6 };
    default { 3 };
};
