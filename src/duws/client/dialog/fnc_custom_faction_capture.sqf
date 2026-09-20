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
    // The server's mods decide, so the server checks. Buttons off while it answers: a second click
    // would close the next dialog.
    { ctrlEnable [_x, false]; } forEach [1600, 1601];
    (["validate", [_side, _text], [false, []]] call fnc_faction_ask) params ["_valid", "_bad"];
    { ctrlEnable [_x, true]; } forEach [1600, 1601];
    if (!_valid) then { _error = format [localize "STR_DUWS_T_ow2fwl24", _bad joinString ", "]; };
};

if (_error isEqualTo "") then {
    if (_side isEqualTo "blufor") then {
        BLUfactionDataTemp = _text;
        publicVariable "BLUfactionDataTemp";
        ["INFO", "FACTION", format ["BLUFOR Faction data pasted: %1", BLUfactionDataTemp]] call fnc_log;
    } else {
        OPFfactionDataTemp = _text;
        publicVariable "OPFfactionDataTemp";
        ["INFO", "FACTION", format ["OPFOR Faction data pasted: %1", OPFfactionDataTemp]] call fnc_log;
    };
    closeDialog 0;
} else {
    hint _error;
};
