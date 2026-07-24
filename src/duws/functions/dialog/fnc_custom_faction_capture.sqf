// Submit handler for the custom-faction paste screen.
// Only sides actually set to CUSTOM require pasted data; validate those before
// committing. A blank box, or a paste missing required faction keys, used to be
// accepted and the dialog closed, leaving setup waiting on data that never arrives
// -> permanent black screen. Reject and keep the dialog open with a specific
// message so the player can fix it on the spot instead of hanging after START.

private _bluText = ctrlText 2100;
private _opfText = ctrlText 2101;

// Blank once tabs/newlines/spaces are stripped: splitString drops runs of the
// given delimiter chars, so an all-whitespace box joins back to "".
private _fnc_isBlank = {
    ((_this splitString (toString [9, 10, 13, 32])) joinString "") isEqualTo ""
};

if (BLUFOR_Faction_X == "CUSTOM") then {
    if (_bluText call _fnc_isBlank) exitWith { hint localize "STR_DUWS_T_vho23y9e"; };
    (["blufor", _bluText] call fnc_custom_faction_parse) params ["", "_valid", "_missing"];
    if (!_valid) exitWith { hint format [localize "STR_DUWS_T_customfaction_missing", _missing joinString ", "]; };
};
if (OPFOR_Faction_X == "CUSTOM") then {
    if (_opfText call _fnc_isBlank) exitWith { hint localize "STR_DUWS_T_vho23y9e"; };
    (["opfor", _opfText] call fnc_custom_faction_parse) params ["", "_valid", "_missing"];
    if (!_valid) exitWith { hint format [localize "STR_DUWS_T_customfaction_missing", _missing joinString ", "]; };
};

BLUfactionDataTemp = _bluText;
publicVariable "BLUfactionDataTemp";
diag_log format ["BLUFOR Faction data pasted: %1", BLUfactionDataTemp];

OPFfactionDataTemp = _opfText;
publicVariable "OPFfactionDataTemp";
diag_log format ["OPFOR Faction data pasted: %1", OPFfactionDataTemp];

closeDialog 0;
