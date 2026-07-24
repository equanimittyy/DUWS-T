// Submit handler for the custom-faction paste screen.
// Only sides actually set to CUSTOM require pasted data; validate those before
// committing. A blank box, or a paste that leaves a required key missing or
// pointing at a non-existent class, must NOT be accepted: accepting it closes the
// dialog and leaves setup waiting on data that never arrives -> permanent black
// screen. Collect a rejection message, and only when there is none commit the data
// and close.
//
// Structured as collect-message-then-branch rather than an early exitWith per
// failure: the commit path (closeDialog) must never run once any side is rejected,
// and one explicit trailing branch makes that unmissable without depending on how
// exitWith unwinds out of a nested then-block.

private _bluText = ctrlText 2100;
private _opfText = ctrlText 2101;

// Blank once tabs/newlines/spaces are stripped: splitString drops runs of the
// given delimiter chars, so an all-whitespace box joins back to "".
private _fnc_isBlank = {
    ((_this splitString (toString [9, 10, 13, 32])) joinString "") isEqualTo ""
};

private _error = "";

if (BLUFOR_Faction_X == "CUSTOM") then {
    if (_bluText call _fnc_isBlank) then {
        _error = localize "STR_DUWS_T_vho23y9e";
    } else {
        (["blufor", _bluText] call fnc_custom_faction_parse) params ["", "_valid", "_bad"];
        if (!_valid) then { _error = format [localize "STR_DUWS_T_ow2fwl24", _bad joinString ", "]; };
    };
};

if (_error isEqualTo "" && {OPFOR_Faction_X == "CUSTOM"}) then {
    if (_opfText call _fnc_isBlank) then {
        _error = localize "STR_DUWS_T_vho23y9e";
    } else {
        (["opfor", _opfText] call fnc_custom_faction_parse) params ["", "_valid", "_bad"];
        if (!_valid) then { _error = format [localize "STR_DUWS_T_ow2fwl24", _bad joinString ", "]; };
    };
};

if (_error isEqualTo "") then {
    BLUfactionDataTemp = _bluText;
    publicVariable "BLUfactionDataTemp";
    diag_log format ["BLUFOR Faction data pasted: %1", BLUfactionDataTemp];

    OPFfactionDataTemp = _opfText;
    publicVariable "OPFfactionDataTemp";
    diag_log format ["OPFOR Faction data pasted: %1", OPFfactionDataTemp];

    closeDialog 0;
} else {
    hint _error;
};
