// Locality: client -- spawned from a row's SELECT button on the confirmation screen.
//
// Picks a new class for one role key. Sits on top of the confirmation screen, which stays open
// behind it, and takes the AutoDetect picker's shape: choose a faction, choose a class from it,
// see the editor preview before committing.
//
// The class list is filtered to the row's kind so an infantry role is never offered a tank. That
// kind comes from fnc_faction_schema rather than from the current value, which may be empty.

params ["_side", "_key"];

private _schema = ([_side] call fnc_faction_schema) select { (_x select 0) isEqualTo _key };
if (_schema isEqualTo []) exitWith {
    ["ERROR", "FACTION", format ["Key editor: %1 is not a %2 schema key.", _key, _side]] call fnc_log;
};

duws_faction_edit_side = _side;
duws_faction_edit_key = _key;
duws_faction_edit_kind = (_schema select 0) select 2;

// Both lists: fnc_getAllFactionsClean returns the ordinary factions or the zombie ones, never
// both, and nothing should be unreachable from an explicit pick. Sorted by the display name the
// player reads; ALL is pinned on top afterwards so it never sorts down into the body.
duws_faction_edit_list = ([false] call fnc_getAllFactionsClean) + ([true] call fnc_getAllFactionsClean);
duws_faction_edit_list sort true;
duws_faction_edit_list = [[localize "STR_DUWS_T_faction_edit_all", "__ALL__"]] + duws_faction_edit_list;

// The editor's own controls. Every list command below takes a control rather than an IDC, because
// the confirmation screen is still open underneath this dialog and the IDC forms resolve against
// whichever display the engine holds current -- landing on the wrong one, they report an empty list
// and no selection instead of failing, so the class list fills from nothing and the pick reads back
// as "". Same reason the hpp stashes the display for displayCtrl.
duws_faction_edit_ctrl = {
    params ["_idc"];
    private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
    if (isNull _display) exitWith { controlNull };
    _display displayCtrl _idc
};

// Every class that could fill a key of this kind: one faction's, or every faction's when the pick
// is ALL. Rebuilt per pick rather than cached -- the enumeration walks the whole of CfgVehicles
// and only one answer is ever on screen.
duws_faction_fill_classes = {
    params ["_faction"];
    private _classCtrl = [8625] call duws_faction_edit_ctrl;
    if (isNull _classCtrl) exitWith {};

    // ALL drops the faction clause so the list spans every loaded faction; the text filter below
    // is what keeps that reachable.
    private _cond = if (_faction isEqualTo "__ALL__") then {
        "getNumber(_x >> 'scope') in [1,2]"
    } else {
        "(getNumber(_x >> 'scope') in [1,2]) && (gettext (_x >> 'faction') == _faction)"
    };
    private _classes = (_cond configClasses (configFile >> "CfgVehicles")) apply { configName _x };

    _classes = switch (duws_faction_edit_kind) do {
        case "man":    { _classes select { _x isKindOf "CAManBase" } };
        case "static": { _classes select { _x isKindOf "StaticWeapon" } };
        default {
            _classes select {
                !(_x isKindOf "CAManBase") && {!(_x isKindOf "StaticWeapon")}
                && {_x isKindOf "LandVehicle" || {_x isKindOf "Air"} || {_x isKindOf "Ship"}}
            }
        };
    };

    // Sorted by the name the player reads rather than by classname: a mod's classnames sort its
    // display names into no order at all.
    private _rows = _classes apply {
        private _name = getText (configFile >> "CfgVehicles" >> _x >> "displayName");
        [if (_name isEqualTo "") then {_x} else {_name}, _x]
    };

    // Case-insensitive substring over both the display name and the classname, so a filter matches
    // either what the player reads or the raw class they already know.
    private _filterCtrl = [8632] call duws_faction_edit_ctrl;
    private _filter = toLower (if (isNull _filterCtrl) then {""} else {ctrlText _filterCtrl});
    if (_filter != "") then {
        _rows = _rows select {
            ((toLower (_x select 0)) find _filter >= 0) || {(toLower (_x select 1)) find _filter >= 0}
        };
    };
    _rows sort true;

    lbClear _classCtrl;
    {
        private _i = _classCtrl lbAdd format ["%1  --  %2", _x select 0, _x select 1];
        _classCtrl lbSetData [_i, _x select 1];
    } forEach _rows;
};

// Preview of the class the class combo is on, plus the line naming it. Same fallback the AutoDetect
// picker carries: a class with no editorPreview gets a caption over the empty frame rather than a
// silently blank panel.
duws_faction_edit_preview = {
    private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
    if (isNull _display) exitWith {};
    private _classCtrl = _display displayCtrl 8625;
    private _class = _classCtrl lbData (lbCurSel _classCtrl);

    if (_class isEqualTo "") exitWith {
        (_display displayCtrl 8626) ctrlSetText "#(argb,8,8,3)color(0,0,0,0.5)";
        (_display displayCtrl 8627) ctrlSetStructuredText parseText format ["<t align='center' size='1.4' font='PuristaMedium' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_edit_noclass"];
        (_display displayCtrl 8628) ctrlSetStructuredText parseText "";
    };

    private _preview = getText (configFile >> "CfgVehicles" >> _class >> "editorPreview");
    (_display displayCtrl 8626) ctrlSetText (if (_preview isEqualTo "") then {"#(argb,8,8,3)color(0,0,0,0.5)"} else {_preview});
    (_display displayCtrl 8627) ctrlSetStructuredText parseText (if (_preview isEqualTo "") then {
        format ["<t align='center' size='1.4' font='PuristaMedium' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_edit_nopreview"]
    } else {""});

    private _name = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    (_display displayCtrl 8628) ctrlSetStructuredText parseText format ["<t size='0.8'>%1</t><br/><t size='0.7' color='#c0c0c0'>%2</t>",
        if (_name isEqualTo "") then {_class} else {format ["%1  --  %2", _name, _class]},
        localize "STR_DUWS_T_faction_edit_pool"];
};

// Logged rather than silent on both counts: a SELECT click that opens nothing is indistinguishable
// from a dead button, and this is the only place that can say which of the two it was.
if (!createDialog "startup_faction_key_edit") exitWith {
    ["ERROR", "FACTION", format ["Key editor for %1 failed to open.", _key]] call fnc_log;
};
waitUntil { dialog };

private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
if (isNull _display) exitWith {
    ["ERROR", "FACTION", format ["Key editor for %1 opened with no display handle.", _key]] call fnc_log;
    closeDialog 0;
};

private _short = (_key regexReplace ["^(blufor|opfor)_", ""]) regexReplace ["_X$", ""];
(_display displayCtrl 8621) ctrlSetText format ["%1 -- %2 / %3",
    localize "STR_DUWS_T_faction_edit_title", toUpper _side, _short];
(_display displayCtrl 8621) ctrlSetFont "PuristaMedium";

private _factionCtrl = _display displayCtrl 8623;
private _classCtrl = _display displayCtrl 8625;

{
    private _i = _factionCtrl lbAdd (_x select 0);
    _factionCtrl lbSetData [_i, _x select 1];
} forEach duws_faction_edit_list;

// Attached after the fill so the lbSetCurSel below is the first thing that raises them. Each handler
// works off the control it was attached to, which is the one thing here guaranteed to be the
// editor's rather than the confirmation screen's.
_factionCtrl ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl"];
    [_ctrl lbData (lbCurSel _ctrl)] call duws_faction_fill_classes;
    private _classCtrl = [8625] call duws_faction_edit_ctrl;
    if (!isNull _classCtrl && {lbSize _classCtrl > 0}) then {
        _classCtrl lbSetCurSel 0;
    } else {
        [] call duws_faction_edit_preview;
    };
}];
_classCtrl ctrlAddEventHandler ["LBSelChanged", { [] call duws_faction_edit_preview; }];

// Retyping the filter rebuilds the class list for the faction already chosen, then drops the
// selection to the top match so the preview tracks what the player is narrowing to.
(_display displayCtrl 8632) ctrlAddEventHandler ["KeyUp", {
    private _factionCtrl = [8623] call duws_faction_edit_ctrl;
    [_factionCtrl lbData (lbCurSel _factionCtrl)] call duws_faction_fill_classes;
    private _classCtrl = [8625] call duws_faction_edit_ctrl;
    if (!isNull _classCtrl && {lbSize _classCtrl > 0}) then {
        _classCtrl lbSetCurSel 0;
    } else {
        [] call duws_faction_edit_preview;
    };
}];

// Open on the side's AutoDetect faction, or on ALL (index 0) when that pick resolves to no combo
// row -- a custom faction need not be in CfgFactionClasses, and ALL is the sensible catch-all
// rather than whichever faction happens to sort first.
private _sideFaction = missionNamespace getVariable [
    ["selectedFaction_OPF", "selectedFaction_BLU"] select (_side isEqualTo "blufor"), ""];
private _fIdx = duws_faction_edit_list findIf { (_x select 1) isEqualTo _sideFaction };
_factionCtrl lbSetCurSel (0 max _fIdx);

// Still highlight the class the key holds when the chosen faction's list carries it, so an edit
// that only swaps the class starts from the one it is changing.
private _current = missionNamespace getVariable [_key, ""];
private _currentClass = if (_current isEqualType []) then { _current param [0, ""] } else { _current };

if (_currentClass != "") then {
    private _cIdx = -1;
    for "_i" from 0 to (lbSize _classCtrl - 1) do {
        if (_classCtrl lbData _i isEqualTo _currentClass) exitWith { _cIdx = _i; };
    };
    if (_cIdx >= 0) then { _classCtrl lbSetCurSel _cIdx; };
};
