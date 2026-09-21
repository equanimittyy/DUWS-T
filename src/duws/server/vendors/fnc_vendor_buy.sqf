// Locality: server -- owns the money, the arsenal pool and the garage, and re-tests everything the
// catalogue only greyed. Nothing a client sends is trusted: its town list is a broadcast copy, its
// money count is a snapshot, and in co-op two players can spend the same note.
/*
    Sells one class to one player. Params: [_vendor, _buyer, _class, _list, _store].
    _list is the stock list the class was picked from, which sets its price. _store picks the second
    destination -- the arsenal for gear, the garage for a vehicle -- against taking it here and now.
    Every answer goes to the buyer alone; a purchase is nobody else's news.

    Everything that can refuse the sale is asked before the money moves. A charge that cannot be
    delivered would have to be refunded, and a refund is a second place for the price to be wrong.
*/
if (!isServer) exitWith {};
params ["_vendor", "_buyer", "_class", ["_list", ""], ["_store", false]];
if (isNull _vendor || isNull _buyer) exitWith {};

private _fnc_say = {
    params ["_line"];
    [localize "STR_DUWS_T_civ", localize _line] remoteExec ["fnc_duws_dialogue", _buyer];
};
private _fnc_bought = {
    params ["_key"];
    private _name = getText (([_class] call fnc_vendor_classCfg) >> "displayName");
    [format [localize _key, [_name, _class] select (_name isEqualTo "")]] remoteExec ["hint", _buyer];
};

// The reach the action opens at, with a metre of slack for the walk to the dialog button.
if (!alive _vendor || {_buyer distance _vendor > 4}) exitWith {};

private _type = _vendor getVariable ["DUWS_vendor_type", ""];
private _kind = [_type] call fnc_vendor_kind;
private _gear = _kind isEqualTo "gear";

// The OPFOR ownership band, read here rather than from the client's copy:
// civ_town_rep is server-only, and DUWS_enemy_town_pos is a derivative that rebuilds on a crossing.
if (([_vendor getVariable ["DUWS_vendor_town", -1]] call fnc_civ_repAt) <= -10) exitWith {
    [format [localize "STR_DUWS_T_VENDOR_HOSTILE", _vendor getVariable ["DUWS_vendor_townName", ""]]] remoteExec ["hint", _buyer];
};

// A hand-made remoteExec must not buy a tank from an arms dealer, nor name the BLUFOR list for an
// OPFOR class to dodge the markup, so the class has to be on the list it is priced from.
if !(_list in ([_type] call fnc_vendor_lists)) exitWith {};
if ((([_kind, _list] call fnc_vendor_stock) findIf { (_x select 1) isEqualTo _class }) < 0) exitWith {};

private _price = [_class, _list] call fnc_vendor_price;
if (_price < 0) exitWith {};

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

if !([_buyer, _price] call fnc_money_spend) exitWith { [localize "STR_DUWS_T_VENDOR_BROKE"] remoteExec ["hint", _buyer] };

if (_gear) exitWith {
    if (_store) exitWith {
        [_class, ([_class] call fnc_captured_pool_getCount) + 1] call fnc_captured_pool_setCount;
        // The setter deliberately does not broadcast -- its other callers batch several writes behind
        // one publish -- so a single sale has to publish for itself or no client sees the shelf move.
        publicVariable "DUWS_capturedPool";
        ["STR_DUWS_T_VENDOR_BOUGHT_ARSENAL"] call _fnc_bought;
    };
    [_class] remoteExec ["fnc_vendor_grant", _buyer];
};

// A bought vehicle has no live original to capture a spec from, so one is built in factory state. The
// hitpoints field is [[],[],[]] and never []: DUWS_fnc_vehSpecApply destructures it into three arrays
// and then walks the first, so a bare [] would throw on the first retrieval.
private _spec = [_class, [], [], [[],[],[]], 0, 1, [[[],[]],[[],[]],[[],[]],[[],[]]], -1];

if (_store) exitWith {
    DUWS_garage_stored pushBack _spec;
    publicVariable "DUWS_garage_stored";
    ["STR_DUWS_T_VENDOR_BOUGHT_GARAGE"] call _fnc_bought;
};

private _veh = [_spec, getPosATL _buyer] call fnc_depot_carry_spawn;
[netId _veh, false, "STR_DUWS_T_VENDOR_BOUGHT"] remoteExec ["fnc_depot_place_r3f", _buyer];
