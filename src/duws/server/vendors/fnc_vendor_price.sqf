// Locality: any -- the catalogue prints what the server will charge, and the server recomputes it
// when the row is actually bought. The two differ only when the town's reputation crosses a discount
// step between the catalogue's stock fetch and the purchase.
/*
    What one pack of one class costs in Money_roll. Params: [_class, _discount], the last a percent
    off from fnc_vendor_discount. Returns a positive count, or -1 for a class no vendor may sell --
    which is also what makes this the single gate on sellability.

    Banded by what the class is rather than priced per class, so a modded server's stock is priced with
    no table to maintain. The bands themselves are untuned: prices are balanced against job payouts in
    the jobs plan's balance phase, once a paid job exists to weigh them against.
*/
params ["_class", ["_discount", 0]];

// Money per CP. The lowest CP band starts at 1, so a floored price never reaches 0 and delists a hull.
#define VEHICLE_RATE 1.2
#define ARMOR_TOP 16

// Selling the currency for the currency would be a loop with a profit in it.
if (_class isEqualTo "Money_roll") exitWith { -1 };

if (isNull ([_class] call fnc_vendor_classCfg)) exitWith { -1 };

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
        // A civilian ground hull prices by its seats alone, so a fuel truck or an ambulance off the
        // street sells as the car it is, not as military logistics above BLUFOR's own transports.
        private _civ = getNumber (configFile >> "CfgVehicles" >> _class >> "side") == 3 && {_class isKindOf "LandVehicle"};
        VEHICLE_RATE * ([_class, ["", "lightUnarmed"] select _civ] call DUWS_fnc_vehPrice)
    };

    // Anything left that is not gear has no band, so it has no price and cannot be sold -- which is
    // what keeps a plane off a forecourt even if one reached this far.
    if (!isClass (configFile >> "CfgWeapons" >> _class)) exitWith { -1 };

    // CfgWeapons holds the guns and everything worn or clipped to one. type is the engine's own split:
    // 1 primary, 2 handgun, 4 launcher; clothing and attachments carry neither.
    switch (getNumber (configFile >> "CfgWeapons" >> _class >> "type")) do {
        case 4: { 3 };
        case 1: { 2 };
        case 2: { 1 };
        default {
            private _armor = selectMax ([0] + ((configProperties [
                configFile >> "CfgWeapons" >> _class >> "ItemInfo" >> "HitpointsProtectionInfo", "isClass _x"
            ]) apply { getNumber (_x >> "armor") }));
            call {
                if (_armor >= ARMOR_TOP) exitWith { 3 };
                if (_armor > 0) exitWith { 2 };
                1
            }
        };
    }
};
if (_base < 0) exitWith { -1 };

// One floor over both rates, so a discounted hull is not rounded down twice. Never below 1: a
// discounted single-money item would otherwise go free.
1 max floor (_base * (100 - _discount) / 100)
