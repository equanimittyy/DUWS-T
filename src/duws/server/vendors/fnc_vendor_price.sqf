// Locality: any -- the catalogue prints what the server will charge, and the server recomputes it
// when the row is actually bought, so the two can never quote different prices.
/*
    What one class costs in Money_roll on one stock list. Params: [_class, _list]. Returns a positive
    count, or -1 for a class no vendor may sell -- which is also what makes this the single gate on
    sellability.

    Banded by what the class is rather than priced per class, so a modded server's stock is priced with
    no table to maintain. The bands themselves are untuned: prices are balanced against job payouts in
    the jobs plan's balance phase, once a paid job exists to weigh them against.
*/
params ["_class", ["_list", ""]];

// Money per CP. The lowest CP band starts at 1, so a floored price never reaches 0 and delists a hull.
#define VEHICLE_RATE 1.2
// A premium on stock that is not BLUFOR's own issue.
#define FOREIGN_MARKUP 1.1

// Selling the currency for the currency would be a loop with a profit in it.
if (_class isEqualTo "Money_roll") exitWith { -1 };

if (isNull ([_class] call fnc_vendor_classCfg)) exitWith { -1 };

private _base = call {
    if (isClass (configFile >> "CfgMagazines" >> _class)) exitWith { 1 };
    if (isClass (configFile >> "CfgGlasses" >> _class)) exitWith { 1 };
    if (_class isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) exitWith { 2 };

    // Hulls take the request menu's CP price, so a dealer ranks them exactly as HQ does and a retune
    // of the CP bands carries through to the forecourt.
    if (["car", _class] call fnc_vendor_hullFits || {["boat", _class] call fnc_vendor_hullFits}) exitWith {
        VEHICLE_RATE * ([_class] call DUWS_fnc_vehPrice)
    };

    // Anything left that is not gear has no band, so it has no price and cannot be sold -- which is
    // what keeps an aircraft off a forecourt even if one reached this far.
    if (!isClass (configFile >> "CfgWeapons" >> _class)) exitWith { -1 };

    // CfgWeapons holds the guns and everything worn or clipped to one. type is the engine's own split:
    // 1 primary, 2 handgun, 4 launcher; clothing and attachments carry neither.
    switch (getNumber (configFile >> "CfgWeapons" >> _class >> "type")) do {
        case 4: { 5 };
        case 1: { 3 };
        case 2: { 2 };
        default { 1 };
    }
};
if (_base < 0) exitWith { -1 };

// One floor over both rates, so a marked-up hull is not rounded down twice.
floor (_base * ([1, FOREIGN_MARKUP] select (_list in ["opfor", "all"])))
