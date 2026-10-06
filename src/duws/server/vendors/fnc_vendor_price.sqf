// Locality: any -- the catalogue prints what the server will charge, and the server recomputes it
// when the row is actually bought. The two differ only when the town's reputation crosses a discount
// step between the catalogue's stock fetch and the purchase.
/*
    What one class costs in Money_roll on one stock list. Params: [_class, _list, _discount], the
    last a percent off from fnc_vendor_discount. Returns a positive count, or -1 for a class no vendor
    may sell -- which is also what makes this the single gate on sellability.

    Banded by what the class is rather than priced per class, so a modded server's stock is priced with
    no table to maintain. The bands themselves are untuned: prices are balanced against job payouts in
    the jobs plan's balance phase, once a paid job exists to weigh them against.
*/
params ["_class", ["_list", ""], ["_discount", 0]];

// Money per CP. The lowest CP band starts at 1, so a floored price never reaches 0 and delists a hull.
#define VEHICLE_RATE 1.2
// A premium on stock that is not BLUFOR's own issue. Gear prices are single digits, so a hull-sized
// markup would floor away to nothing on them.
#define FOREIGN_MARKUP_HULL 1.1
#define FOREIGN_MARKUP_GEAR 1.5

// Selling the currency for the currency would be a loop with a profit in it.
if (_class isEqualTo "Money_roll") exitWith { -1 };

if (isNull ([_class] call fnc_vendor_classCfg)) exitWith { -1 };

private _markup = FOREIGN_MARKUP_GEAR;
private _base = call {
    if (isClass (configFile >> "CfgMagazines" >> _class)) exitWith { 1 };
    if (isClass (configFile >> "CfgGlasses" >> _class)) exitWith { 1 };
    // A bag that holds nothing is a weapon-system part -- a static's gun or tripod, a UAV -- not storage.
    if (_class isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) exitWith {
        [2, 6] select (getNumber (configFile >> "CfgVehicles" >> _class >> "maximumLoad") == 0)
    };

    // Hulls take the request menu's CP price, so a dealer ranks them exactly as HQ does and a retune
    // of the CP bands carries through to the forecourt.
    if (["car", _class] call fnc_vendor_hullFits || {["boat", _class] call fnc_vendor_hullFits}) exitWith {
        _markup = FOREIGN_MARKUP_HULL;
        VEHICLE_RATE * ([_class] call DUWS_fnc_vehPrice)
    };

    // Anything left that is not gear has no band, so it has no price and cannot be sold -- which is
    // what keeps a plane off a forecourt even if one reached this far.
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

// One floor over every rate, so a marked-up, discounted hull is not rounded down twice. Never below 1:
// a discounted single-money item would otherwise go free.
1 max floor (_base * ([1, _markup] select (_list in ["opfor", "all"])) * (100 - _discount) / 100)
