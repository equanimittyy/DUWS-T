// Submit handler for the custom-faction paste screen.
// Only sides actually set to CUSTOM require pasted data; validate those before
// committing. A blank (or whitespace-only) box used to be accepted and the dialog
// closed, leaving the setup flow waiting on a never-set temp var -> permanent black
// screen. Reject it instead and keep the dialog open so the player can fix it.

private _bluText = ctrlText 2100;
private _opfText = ctrlText 2101;

// Blank once tabs/newlines/spaces are stripped: splitString drops runs of the
// given delimiter chars, so an all-whitespace box joins back to "".
private _fnc_isBlank = {
    ((_this splitString (toString [9, 10, 13, 32])) joinString "") isEqualTo ""
};

if (BLUFOR_Faction_X == "CUSTOM" && {_bluText call _fnc_isBlank}) exitWith {
    hint localize "STR_DUWS_T_vho23y9e";
};
if (OPFOR_Faction_X == "CUSTOM" && {_opfText call _fnc_isBlank}) exitWith {
    hint localize "STR_DUWS_T_vho23y9e";
};

BLUfactionDataTemp = _bluText;
publicVariable "BLUfactionDataTemp";
diag_log format ["BLUFOR Faction data pasted: %1", BLUfactionDataTemp];

OPFfactionDataTemp = _opfText;
publicVariable "OPFfactionDataTemp";
diag_log format ["OPFOR Faction data pasted: %1", OPFfactionDataTemp];

closeDialog 0;
