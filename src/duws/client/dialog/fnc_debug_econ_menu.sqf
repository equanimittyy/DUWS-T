// Locality: client -- the button handlers below run on whoever opened the menu.
/*
    fnc_debug_econ_menu.sqf
    Developer tool: type a signed amount, click the pool it lands in. Reached from
    fnc_debug_menu.sqf. Strings are English-only for the same reason as that file.
*/
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every
// client holds a copy it can call, and unlike the request menus nothing here charges for
// what it hands out.
if (!((vehiclevarname player) in game_master)) exitWith {};

disableSerialization;
private _display = createDialog ["RscDisplayEmpty", false];
if (isNull _display) exitWith {};

private _bg = _display ctrlCreate ["RscText", 9510];
_bg ctrlSetPosition [0.3, 0.30, 0.4, 0.30];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.7];
_bg ctrlCommit 0;

private _titleCtrl = _display ctrlCreate ["RscText", 9511];
_titleCtrl ctrlSetPosition [0.3, 0.30, 0.4, 0.05];
_titleCtrl ctrlSetText "Adjust CP / AP";
_titleCtrl ctrlSetBackgroundColor [0, 0, 0, 0.9];
_titleCtrl ctrlCommit 0;

private _label = _display ctrlCreate ["RscText", 9512];
_label ctrlSetPosition [0.31, 0.36, 0.38, 0.04];
_label ctrlSetText "Amount (negative subtracts; pools floor at 0):";
_label ctrlCommit 0;

private _edit = _display ctrlCreate ["RscEdit", 9513];
_edit ctrlSetPosition [0.31, 0.40, 0.38, 0.04];
_edit ctrlSetText "50";
_edit ctrlCommit 0;

// A control event handler cannot see this scope, so the amount is read back off the edit
// box by IDC and the target pool is carried by the clicked button's own IDC.
private _apply = {
    private _dlg = ctrlParent (_this select 0);
    // Whole points only: the CP pool is printed raw on the HUD, so a fraction reaching it
    // renders as "32.05". parseNumber yields 0 for anything unparseable, which is also the
    // one delta worth refusing -- so a typo reports itself instead of closing silently.
    private _delta = round (parseNumber (ctrlText (_dlg displayCtrl 9513)));
    if (_delta == 0) exitWith { hint "Enter a non-zero number."; };

    private _i = [9514, 9515, 9516] find (ctrlIDC (_this select 0));
    closeDialog 0;
    switch (_i) do {
        case 0: { [_delta, "debug menu"] remoteExec ["fnc_cp_adjust", 2]; };
        case 1: { ["BLU", _delta, "debug menu"] remoteExec ["fnc_ap_adjust", 2]; };
        case 2: { ["OPF", _delta, "debug menu"] remoteExec ["fnc_ap_adjust", 2]; };
    };
    // Reports the delta sent, not the resulting total: the server owns both pools and
    // broadcasts them back, so the local copies are still the pre-change values here.
    hint format ["Sent %1 %2.", _delta, ["to BLUFOR CP", "to BLUFOR AP", "to OPFOR AP"] select _i];
};

{
    private _btn = _display ctrlCreate ["RscButton", _x];
    _btn ctrlSetPosition [0.31 + 0.13 * _forEachIndex, 0.46, 0.12, 0.05];
    _btn ctrlSetText ([
        format ["BLU CP (%1)", commandpointsblu1],
        format ["BLU AP (%1)", WARCOM_blufor_ap],
        format ["OPF AP (%1)", WARCOM_opfor_ap]
    ] select _forEachIndex);
    _btn ctrlCommit 0;
    _btn ctrlAddEventHandler ["ButtonClick", _apply];
} forEach [9514, 9515, 9516];

private _closeBtn = _display ctrlCreate ["RscButton", 9517];
_closeBtn ctrlSetPosition [0.31, 0.53, 0.38, 0.05];
_closeBtn ctrlSetText (localize "STR_DUWS_T_MENU_CLOSE");
_closeBtn ctrlCommit 0;
_closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
