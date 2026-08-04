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
if (_schema isEqualTo []) exitWith {};

duws_faction_edit_side = _side;
duws_faction_edit_key = _key;
duws_faction_edit_kind = (_schema select 0) select 2;

// Both lists: fnc_getAllFactionsClean returns the ordinary factions or the zombie ones, never
// both, and nothing should be unreachable from an explicit pick.
duws_faction_edit_list = ([false] call fnc_getAllFactionsClean) + ([true] call fnc_getAllFactionsClean);

// Every class of one faction that could fill a key of this kind. Rebuilt per faction rather than
// held for all of them: the enumeration walks the whole of CfgVehicles and only one faction's
// answer is ever on screen.
duws_faction_fill_classes = {
    params ["_faction"];

    private _classes = ("(getNumber(_x >> 'scope') in [1,2]) && (gettext (_x >> 'faction') == _faction)"
        configClasses (configFile >> "CfgVehicles")) apply { configName _x };

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
    _rows sort true;

    lbClear 8625;
    {
        private _i = lbAdd [8625, format ["%1  --  %2", _x select 0, _x select 1]];
        lbSetData [8625, _i, _x select 1];
    } forEach _rows;
};

// Preview of the class the class combo is on, plus the line naming it. Same fallback the AutoDetect
// picker carries: a class with no editorPreview gets a caption over the empty frame rather than a
// silently blank panel.
duws_faction_edit_preview = {
    private _class = lbData [8625, lbCurSel 8625];

    if (_class isEqualTo "") exitWith {
        ctrlSetText [8626, "#(argb,8,8,3)color(0,0,0,0.5)"];
        ctrlSetStructuredText [8627, parseText format ["<t align='center' size='1.4' font='PuristaMedium' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_edit_noclass"]];
        ctrlSetStructuredText [8628, parseText ""];
    };

    private _preview = getText (configFile >> "CfgVehicles" >> _class >> "editorPreview");
    ctrlSetText [8626, if (_preview isEqualTo "") then {"#(argb,8,8,3)color(0,0,0,0.5)"} else {_preview}];
    ctrlSetStructuredText [8627, parseText (if (_preview isEqualTo "") then {
        format ["<t align='center' size='1.4' font='PuristaMedium' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_edit_nopreview"]
    } else {""})];

    private _name = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    ctrlSetStructuredText [8628, parseText format ["<t size='0.8'>%1</t><br/><t size='0.7' color='#c0c0c0'>%2</t>",
        if (_name isEqualTo "") then {_class} else {format ["%1  --  %2", _name, _class]},
        localize "STR_DUWS_T_faction_edit_pool"]];
};

if (!createDialog "startup_faction_key_edit") exitWith {};
waitUntil { dialog };

private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
if (isNull _display) exitWith { closeDialog 0; };

private _short = (_key regexReplace ["^(blufor|opfor)_", ""]) regexReplace ["_X$", ""];
(_display displayCtrl 8621) ctrlSetText format ["%1 -- %2 / %3",
    localize "STR_DUWS_T_faction_edit_title", toUpper _side, _short];
(_display displayCtrl 8621) ctrlSetFont "PuristaMedium";

{
    private _i = lbAdd [8623, _x select 0];
    lbSetData [8623, _i, _x select 1];
} forEach duws_faction_edit_list;

// Attached after the fill so the lbSetCurSel below is the first thing that raises them.
(_display displayCtrl 8623) ctrlAddEventHandler ["LBSelChanged", {
    [lbData [8623, lbCurSel 8623]] call duws_faction_fill_classes;
    if (lbSize 8625 > 0) then { lbSetCurSel [8625, 0]; } else { [] call duws_faction_edit_preview; };
}];
(_display displayCtrl 8625) ctrlAddEventHandler ["LBSelChanged", { [] call duws_faction_edit_preview; }];

// Open on the faction and class the key already holds, so the screen starts from what it is
// changing rather than from whichever faction happens to sort first.
private _current = missionNamespace getVariable [_key, ""];
private _currentClass = if (_current isEqualType []) then { _current param [0, ""] } else { _current };
private _currentFaction = if (_currentClass isEqualTo "") then {""} else {
    getText (configFile >> "CfgVehicles" >> _currentClass >> "faction")
};

private _fIdx = duws_faction_edit_list findIf { (_x select 1) isEqualTo _currentFaction };
lbSetCurSel [8623, 0 max _fIdx];

if (_currentClass != "") then {
    private _cIdx = -1;
    for "_i" from 0 to (lbSize 8625 - 1) do {
        if (lbData [8625, _i] isEqualTo _currentClass) exitWith { _cIdx = _i; };
    };
    if (_cIdx >= 0) then { lbSetCurSel [8625, _cIdx]; };
};
