// Locality: server -- owns the money, the arsenal pool and the garage, and re-tests everything the
// catalogue only greyed. Nothing a client sends is trusted: its town list is a broadcast copy, its
// money count is a snapshot, and in co-op two players can spend the same note.
/*
    Sells one class to one player. Params: [_vendor, _buyer, _class, _store].
    _store picks the second destination -- the arsenal for gear, the garage for a vehicle -- against
    taking it here and now. Every answer is spoken to the buyer alone; a purchase is nobody else's news.

    Everything that can refuse the sale is asked before the money moves. A charge that cannot be
    delivered would have to be refunded, and a refund is a second place for the price to be wrong.
*/
if (!isServer) exitWith {};
params ["_vendor", "_buyer", "_class", ["_store", false]];
if (isNull _vendor || isNull _buyer) exitWith {};

private _fnc_say = {
    params ["_line"];
    [localize "STR_DUWS_T_civ", localize _line] remoteExec ["fnc_duws_dialogue", _buyer];
};

// The reach the action opens at, with a metre of slack for the walk to the dialog button.
if (!alive _vendor || {_buyer distance _vendor > 4}) exitWith {};

private _type = _vendor getVariable ["DUWS_vendor_type", ""];
private _kind = [_type] call fnc_vendor_kind;
private _gear = _kind isEqualTo "gear";

// The same OPFOR band the disguise breaks in, read here rather than from the client's copy:
// civ_town_rep is server-only, and DUWS_enemy_town_pos is a derivative that rebuilds on a crossing.
if (([_vendor getVariable ["DUWS_vendor_town", -1]] call fnc_civ_repAt) <= -10) exitWith {
    ["STR_DUWS_T_VENDOR_HOSTILE"] call _fnc_say;
};

private _price = [_class] call fnc_vendor_price;
if (_price < 0) exitWith {};

// A hand-made remoteExec must not buy a tank from a car dealer, so a vehicle has to be in the
// dealer's own pool. Gear needs no equivalent: Everything is by construction every class
// fnc_vendor_price will price, so the price gate above already is the membership test.
private _stocked = _gear;
if (!_gear) then {
    {
        private _rows = [_x] call fnc_vendor_stock;
        if ((_rows findIf { (_x select 1) isEqualTo _class }) >= 0) exitWith { _stocked = true };
    } forEach ([_type] call fnc_vendor_lists);
};
if (!_stocked) exitWith {};

// Outside Limited mode a friendly class is already unlimited on the shelf, so stocking it would buy
// nothing at all.
if (_gear && {_store} && {!([_class] call fnc_vendor_poolCounts)}) exitWith {
    ["STR_DUWS_T_VENDOR_NO_POOL"] call _fnc_say;
};

// Land, air and boat are three independent garage pools, so a full land pool must never block a boat.
private _domainIndex = if (_gear) then { -1 } else {
    [[_class] call DUWS_fnc_vehDomain] call DUWS_fnc_garageDomainIndex
};
if (_store && {_domainIndex >= 0}
    && {(([] call DUWS_fnc_garageUsed) select _domainIndex) >= (([] call DUWS_fnc_garageCaps) select _domainIndex)}) exitWith {
    [localize "STR_DUWS_T_GARAGE_POOL_FULL"] remoteExec ["hint", _buyer];
};

private _spawnPos = if (_gear || _store) then { [] } else { [_vendor, _kind] call fnc_vendor_dropPos };
if (!_gear && {!_store} && {_spawnPos isEqualTo []}) exitWith {
    ["STR_DUWS_T_VENDOR_NO_ROOM"] call _fnc_say;
};

if !([_buyer, _price] call fnc_money_spend) exitWith { ["STR_DUWS_T_VENDOR_BROKE"] call _fnc_say };

if (_gear) exitWith {
    if (_store) exitWith {
        [_class, ([_class] call fnc_captured_pool_getCount) + 1] call fnc_captured_pool_setCount;
        // The setter deliberately does not broadcast -- its other callers batch several writes behind
        // one publish -- so a single sale has to publish for itself or no client sees the shelf move.
        publicVariable "DUWS_capturedPool";
        ["STR_DUWS_T_VENDOR_BOUGHT_ARSENAL"] call _fnc_say;
    };
    // One holder builder for every gear type, rather than branching per inventory slot the way the
    // black market did. An inventory add only takes effect where the unit is local, and addBackpack
    // would swap out whatever the buyer is already wearing and spill its contents; the holder is
    // global-effect, and the goods are handed over to be picked up exactly as fnc_civ_serve does it.
    [[[_class, 1]], getPosATL _buyer] call fnc_money_drop;
    ["STR_DUWS_T_VENDOR_BOUGHT"] call _fnc_say;
};

// A bought vehicle has no live original to capture a spec from, so one is built in factory state. The
// hitpoints field is [[],[],[]] and never []: DUWS_fnc_vehSpecApply destructures it into three arrays
// and then walks the first, so a bare [] would throw on the first retrieval.
private _spec = [_class, [], [], [[],[],[]], 0, 1, [[[],[]],[[],[]],[[],[]],[[],[]]], -1];

if (_store) exitWith {
    DUWS_garage_stored pushBack _spec;
    publicVariable "DUWS_garage_stored";
    ["STR_DUWS_T_VENDOR_BOUGHT_GARAGE"] call _fnc_say;
};

// Radius 5 with "NONE" as the garage retrieval uses, so a second purchase lands beside the first
// rather than inside it. The spec is applied while the hull is still server-local, which is what lets
// the plain setFuel and setDamage in it replicate.
private _veh = createVehicle [_class, _spawnPos, [], 5, "NONE"];
[_veh, _spec] call DUWS_fnc_vehSpecApply;
["STR_DUWS_T_VENDOR_BOUGHT_VEHICLE"] call _fnc_say;
