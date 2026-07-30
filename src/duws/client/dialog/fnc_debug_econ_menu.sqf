// Locality: client -- the button handlers below run on whoever opened the menu.
/*
    fnc_debug_econ_menu.sqf
    Developer tool: type a signed amount, click what it lands in. The two campaign pools are read
    and written from here; a town's reputation and worth and the escalation counter are server-only
    state, so those arrive from fnc_debug_econ_server and their edits go back to it.
    Reached from fnc_debug_menu.sqf. Strings are English-only for the same reason as that file.
*/
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every
// client holds a copy it can call, and unlike the request menus nothing here charges for
// what it hands out.
if (!((vehiclevarname player) in game_master)) exitWith {};

disableSerialization;
private _display = createDialog ["RscDisplayEmpty", false];
if (isNull _display) exitWith {};

// Recorded for fnc_debug_econ_fill, which arrives with the server's snapshot several frames from
// now and cannot be handed a display it was not open for. Cleared by the close handler.
uiNamespace setVariable ["DUWS_debug_econ_display", _display];

private _bg = _display ctrlCreate ["RscText", 9510];
_bg ctrlSetPosition [0.25, 0.18, 0.5, 0.62];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.7];
_bg ctrlCommit 0;

private _titleCtrl = _display ctrlCreate ["RscText", 9511];
_titleCtrl ctrlSetPosition [0.25, 0.18, 0.5, 0.05];
_titleCtrl ctrlSetText "Adjust CP / AP / Town / Escalation";
_titleCtrl ctrlSetBackgroundColor [0, 0, 0, 0.9];
_titleCtrl ctrlCommit 0;

private _label = _display ctrlCreate ["RscText", 9512];
_label ctrlSetPosition [0.26, 0.24, 0.48, 0.04];
_label ctrlSetText "Amount (negative subtracts; pools and worth floor at 0):";
_label ctrlCommit 0;

private _edit = _display ctrlCreate ["RscEdit", 9513];
_edit ctrlSetPosition [0.26, 0.28, 0.48, 0.04];
_edit ctrlSetText "50";
_edit ctrlCommit 0;

// A control event handler cannot see this scope, so the amount is read back off the edit
// box by IDC and the target is carried by the clicked button's own IDC.
private _apply = {
    private _dlg = ctrlParent (_this select 0);
    // Whole points only: the CP pool is printed raw on the HUD, so a fraction reaching it
    // renders as "32.05". parseNumber yields 0 for anything unparseable, which is also the
    // one delta worth refusing -- so a typo reports itself instead of closing silently.
    private _delta = round (parseNumber (ctrlText (_dlg displayCtrl 9513)));
    if (_delta == 0) exitWith { hint "Enter a non-zero number."; };

    private _idc = ctrlIDC (_this select 0);
    private _i = [9514, 9515, 9516] find _idc;

    // The three pools close the window, matching how this tool has always behaved. The town and
    // escalation buttons leave it open: those are the ones a tester nudges repeatedly, and the
    // readout they are aiming at is in this window.
    if (_i >= 0) exitWith {
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

    // Every remaining button edits server-only state, so it travels and the window then asks for a
    // fresh snapshot. Both calls go to the same target, which runs them in the order they were sent,
    // so the snapshot always reflects the edit that preceded it.
    if (_idc == 9521) exitWith {
        ["escalation", player, [_delta]] remoteExec ["fnc_debug_econ_server", 2];
        ["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
    };

    // Town rep and worth. The row's data carries the town index rather than its list position.
    private _list = _dlg displayCtrl 9522;
    private _sel = lbCurSel _list;
    if (_sel < 0) exitWith { hint "Pick a town first."; };
    private _townIndex = parseNumber (_list lbData _sel);
    [(["rep", "ap"] select (_idc == 9524)), player, [_townIndex, _delta]] remoteExec ["fnc_debug_econ_server", 2];
    ["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
};

{
    private _btn = _display ctrlCreate ["RscButton", _x];
    _btn ctrlSetPosition [0.26 + 0.16 * _forEachIndex, 0.33, 0.155, 0.05];
    _btn ctrlSetText ([
        format ["BLU CP (%1)", commandpointsblu1],
        format ["BLU AP (%1)", WARCOM_blufor_ap],
        format ["OPF AP (%1)", WARCOM_opfor_ap]
    ] select _forEachIndex);
    _btn ctrlCommit 0;
    _btn ctrlAddEventHandler ["ButtonClick", _apply];
} forEach [9514, 9515, 9516];

// Escalation. Filled by fnc_debug_econ_fill; until then it says so rather than showing a stale zero.
private _escReadout = _display ctrlCreate ["RscText", 9520];
_escReadout ctrlSetPosition [0.26, 0.39, 0.48, 0.04];
_escReadout ctrlSetText "Escalation: asking the server...";
_escReadout ctrlCommit 0;

private _escBtn = _display ctrlCreate ["RscButton", 9521];
_escBtn ctrlSetPosition [0.26, 0.43, 0.48, 0.05];
_escBtn ctrlSetText "Destroyed houses +/- amount";
_escBtn ctrlCommit 0;
_escBtn ctrlAddEventHandler ["ButtonClick", _apply];

// Towns. A listbox rather than a map click: the same choice in one control, with the standing and
// worth of every town readable side by side instead of one per click.
private _townLabel = _display ctrlCreate ["RscText", 9525];
_townLabel ctrlSetPosition [0.26, 0.49, 0.48, 0.04];
_townLabel ctrlSetText "Towns (reputation clamps to +/-20):";
_townLabel ctrlCommit 0;

private _list = _display ctrlCreate ["RscListBox", 9522];
_list ctrlSetPosition [0.26, 0.53, 0.48, 0.14];
_list ctrlCommit 0;

private _repBtn = _display ctrlCreate ["RscButton", 9523];
_repBtn ctrlSetPosition [0.26, 0.68, 0.235, 0.05];
_repBtn ctrlSetText "Town rep +/- amount";
_repBtn ctrlCommit 0;
_repBtn ctrlAddEventHandler ["ButtonClick", _apply];

private _apBtn = _display ctrlCreate ["RscButton", 9524];
_apBtn ctrlSetPosition [0.505, 0.68, 0.235, 0.05];
_apBtn ctrlSetText "Town worth +/- amount";
_apBtn ctrlCommit 0;
_apBtn ctrlAddEventHandler ["ButtonClick", _apply];

private _closeBtn = _display ctrlCreate ["RscButton", 9517];
_closeBtn ctrlSetPosition [0.26, 0.74, 0.48, 0.05];
_closeBtn ctrlSetText (localize "STR_DUWS_T_MENU_CLOSE");
_closeBtn ctrlCommit 0;
_closeBtn ctrlAddEventHandler ["ButtonClick", {
    uiNamespace setVariable ["DUWS_debug_econ_display", displayNull];
    closeDialog 0;
}];

// Asked last, so every control the answer writes into already exists by the time it arrives.
["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
