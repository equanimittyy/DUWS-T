// Locality: client -- invoked from a dialog action.
// Submit handler for the single-side custom-faction paste window. duws_custom_side
// (set by fnc_startup_faction_resolve before the dialog opens) says which side this
// is. A blank box, or one missing required keys / naming a class that doesn't exist,
// is rejected with a message and the dialog stays open -- it must never close and
// leave setup waiting on data that never arrives (a permanent black screen).
//
// No exitWith: a single trailing commit/reject branch keeps closeDialog unreachable
// whenever the paste was rejected, without depending on exitWith's scope unwinding.

private _side = duws_custom_side;
private _text = ctrlText 2100;

// Blank once tabs/newlines/spaces are stripped: splitString drops runs of the
// given delimiter chars, so an all-whitespace box joins back to "".
private _fnc_isBlank = {
    ((_this splitString (toString [9, 10, 13, 32])) joinString "") isEqualTo ""
};

private _error = "";
if (_text call _fnc_isBlank) then {
    _error = localize "STR_DUWS_T_vho23y9e";
} else {
    ([_side, _text] call fnc_custom_faction_parse) params ["", "_valid", "_bad"];
    if (!_valid) then { _error = format [localize "STR_DUWS_T_ow2fwl24", _bad joinString ", "]; };
};

if (_error isEqualTo "") then {
    if (_side isEqualTo "blufor") then {
        BLUfactionDataTemp = _text;
        publicVariable "BLUfactionDataTemp";
        diag_log format ["BLUFOR Faction data pasted: %1", BLUfactionDataTemp];
    } else {
        OPFfactionDataTemp = _text;
        publicVariable "OPFfactionDataTemp";
        diag_log format ["OPFOR Faction data pasted: %1", OPFfactionDataTemp];
    };
    closeDialog 0;
} else {
    hint _error;
};
