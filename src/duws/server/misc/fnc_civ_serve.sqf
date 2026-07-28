// Locality: server. The accepted path, reached both from the reaction roll and from a paid
// bribe -- one function so the two cannot end up serving different things for the same row.
if (!isServer) exitWith {};

params ["_civilian", "_caller", ["_row", ""]];

if (isNull _civilian || isNull _caller) exitWith {};

([_row] call fnc_civ_rowSpec) params ["_category"];
if (_category isEqualTo "") exitWith {};

// Spent before the payout, not after. Both the intel payout and the recruit hand-off take time,
// and a second click inside that window would otherwise be served twice.
_civilian setVariable [format ["DUWS_civ_spent_%1", _category], true, true];

// Both supplies rows drop their item at the civilian's feet on the same 60 s timer. The timer is
// the same for both now that neither carries a price or a roll of its own: the item is handed
// over to be picked up, and a persistent one would let a single friendly town furnish a squad's
// repairs for the rest of the campaign.
private _fnc_hand = {
    params ["_class", "_line", "_hint"];
    private _pos = getPosATL _civilian;
    private _item = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
    _item setPosATL [_pos select 0, _pos select 1, (_pos select 2) + 0.05];
    _item enableSimulation true;
    [_item] spawn {
        params ["_box"];
        sleep 60;
        if (!isNull _box) then { deleteVehicle _box };
    };
    [localize "STR_DUWS_T_civ", localize _line] remoteExec ["fnc_duws_dialogue", _caller];
    [localize _hint] remoteExec ["hint", _caller];
};

switch (toUpper _row) do {

    // fnc_intel_payout decides what one piece of intel is worth for every source in the mission,
    // and speaks its own result -- including having nothing left to give. The position is what
    // its town bucket ranks by, so it has to be the asking player's and not the civilian's.
    case "INTEL": {
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocyes"] remoteExec ["fnc_duws_dialogue", _caller];
        [getPos _caller, _caller] call fnc_intel_payout;
    };

    // Clears captive and broadcasts it itself, so no client-side setCaptive pairs with this.
    case "RECRUIT": {
        [_civilian, _caller, netId _civilian] call fnc_recruitSuccessServer;
    };

    case "AID": {
        ["Item_Medikit", "STR_DUWS_T_ASK_AID_GRANT", "STR_DUWS_T_ASK_AID_SUCCESS"] call _fnc_hand;
    };

    case "TOOLKIT": {
        ["Item_Toolkit", "STR_DUWS_T_ASK_TOOLKIT_GRANT", "STR_DUWS_T_ASK_TOOLKIT_SUCCESS"] call _fnc_hand;
    };

};
