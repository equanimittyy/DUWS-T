// Locality: server. The accepted path, reached both from the reaction roll and from a paid
// bribe -- one function so the two cannot end up serving different things for the same row.
if (!isServer) exitWith {};

params ["_civilian", "_caller", ["_row", ""]];

if (isNull _civilian || isNull _caller) exitWith {};

if (([_row] call fnc_civ_rowPrice) < 0) exitWith {};

// Both item rows drop their goods at the civilian's feet on the same 60 s timer. The timer is
// the same for both now that neither carries a price or a roll of its own: the item is handed
// over to be picked up, and a persistent one would let a single friendly town furnish a squad's
// repairs for the rest of the campaign. Returns the holder so a caller can load it further.
private _fnc_hand = {
    params ["_class", "_line"];
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
    _item
};

switch (toUpper _row) do {

    // fnc_intel_payout decides what one piece of intel is worth for every source in the mission,
    // and speaks its own result -- including having nothing left to give. The position is what
    // its town bucket ranks by, so it has to be the asking player's and not the civilian's.
    case "INTEL": {
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocyes"] remoteExec ["fnc_duws_dialogue", _caller];
        [getPos _caller, _caller] call fnc_intel_payout;
    };

    // The informant-hunt ask, reached only when its bribe was paid: the ping lives with the mission
    // (fnc_intel_ask_reveal), reused here so a paid answer and a free one say the same thing.
    case "INFORMANT": {
        [_civilian, _caller] call fnc_intel_ask_reveal;
    };

    // Clears captive and broadcasts it itself, so no client-side setCaptive pairs with this.
    case "RECRUIT": {
        [_civilian, _caller, netId _civilian] call fnc_recruitSuccessServer;
    };

    // Dressings alongside the medikit: a medikit is unusable without the medic trait, so a squad
    // without one got nothing it could actually spend out of the only favour this person does.
    case "AID": {
        private _box = ["Item_Medikit", "STR_DUWS_T_ASK_AID_GRANT"] call _fnc_hand;
        _box addItemCargoGlobal ["FirstAidKit", 3];
    };

    case "TOOLKIT": {
        ["Item_Toolkit", "STR_DUWS_T_ASK_TOOLKIT_GRANT"] call _fnc_hand;
    };

};

// Back to what they were doing, the same exit a refusal takes. A recruit is excluded: they have
// just joined the player's group and take their orders from it.
if ((toUpper _row) != "RECRUIT") then {
    [_civilian] call fnc_civ_resume;
};
