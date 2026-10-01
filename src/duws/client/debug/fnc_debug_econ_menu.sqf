// Locality: client -- the button handlers below run on whoever opened the menu.
/*
    Developer tool: type a signed amount, click what it lands in. Money lands in the player's own
    inventory, so it is granted here; everything else is server-owned and is sent there. Also fires
    one economy tick. English-only like fnc_debug_menu.
*/
if (!hasInterface) exitWith {};

// Re-checked, not trusted to the caller: this is publicVariable'd, so every client holds a callable copy.
if (!((vehiclevarname player) in game_master)) exitWith {};

disableSerialization;
private _display = createDialog ["RscDisplayEmpty", false];
if (isNull _display) exitWith {};

// Recorded for fnc_debug_econ_fill: its snapshot arrives frames later and can't be handed this display. Cleared on close.
uiNamespace setVariable ["DUWS_debug_econ_display", _display];

private _bg = _display ctrlCreate ["RscText", 9510];
_bg ctrlSetPosition [0.25, 0.18, 0.5, 0.78];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.7];
_bg ctrlCommit 0;

private _titleCtrl = _display ctrlCreate ["RscText", 9511];
_titleCtrl ctrlSetPosition [0.25, 0.18, 0.5, 0.05];
_titleCtrl ctrlSetText "Adjust CP / AP / Money / Town / Escalation";
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
    // Round: the CP pool prints raw on the HUD, so a fraction would land as "32.05". parseNumber
    // yields 0 on garbage -- the one delta worth refusing, so a typo reports itself.
    private _delta = round (parseNumber (ctrlText (_dlg displayCtrl 9513)));
    if (_delta == 0) exitWith { hint "Enter a non-zero number."; };

    private _idc = ctrlIDC (_this select 0);
    private _i = [9514, 9515, 9516, 9518] find _idc;

    // Stays open like the town and escalation edits: the pools are client globals the server
    // broadcasts back, so a trailing snapshot request re-labels these buttons once the new totals land.
    if (_i >= 0) exitWith {
        switch (_i) do {
            case 0: { [_delta, "debug menu"] remoteExec ["fnc_cp_adjust", 2]; };
            // Delta doubles as _earned so debug AP advances the tier like income; clamped at 0 -- the
            // earned counter is a one-way ratchet a negative test delta must not credit.
            case 1: { ["BLU", _delta, "debug menu", _delta max 0] remoteExec ["fnc_ap_adjust", 2]; };
            case 2: { ["OPF", _delta, "debug menu", _delta max 0] remoteExec ["fnc_ap_adjust", 2]; };
            case 3: {
                if (_delta < 0) exitWith { hint "Money takes a positive count."; };
                ["Money_roll", _delta, format ["Spawned %1 money.", _delta]] call fnc_loot_grant;
            };
        };
        ["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
    };

    // Remaining buttons edit server-only state, then request a snapshot. Same target runs them in
    // send order, so the snapshot always reflects the edit before it.
    if (_idc == 9521) exitWith {
        ["escalation", player, [_delta]] remoteExec ["fnc_debug_econ_server", 2];
        ["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
    };

    // Row data carries the town index, not its list position.
    private _list = _dlg displayCtrl 9522;
    private _sel = lbCurSel _list;
    if (_sel < 0) exitWith { hint "Pick a town first."; };
    private _townIndex = parseNumber (_list lbData _sel);
    private _mode = ["rep", "ap"] select (_idc == 9524);
    [_mode, player, [_townIndex, _delta]] remoteExec ["fnc_debug_econ_server", 2];
    ["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
};

{
    private _btn = _display ctrlCreate ["RscButton", _x];
    _btn ctrlSetPosition [0.26 + 0.12 * _forEachIndex, 0.33, 0.115, 0.05];
    _btn ctrlSetText ([
        format ["BLU CP (%1)", commandpointsblu1],
        format ["BLU AP (%1)", WARCOM_blufor_ap],
        format ["OPF AP (%1)", WARCOM_opfor_ap],
        format ["Money (%1)", [player] call fnc_money_count]
    ] select _forEachIndex);
    _btn ctrlCommit 0;
    _btn ctrlAddEventHandler ["ButtonClick", _apply];
} forEach [9514, 9515, 9516, 9518];

// Filled by fnc_debug_econ_fill; until then says so rather than showing a stale zero.
private _escReadout = _display ctrlCreate ["RscText", 9520];
_escReadout ctrlSetPosition [0.26, 0.39, 0.48, 0.04];
_escReadout ctrlSetText "Escalation: asking the server...";
_escReadout ctrlCommit 0;

private _escBtn = _display ctrlCreate ["RscButton", 9521];
_escBtn ctrlSetPosition [0.26, 0.43, 0.48, 0.05];
_escBtn ctrlSetText "Destroyed houses +/- amount";
_escBtn ctrlCommit 0;
_escBtn ctrlAddEventHandler ["ButtonClick", _apply];

// Listbox, not a map click: every town's standing and worth readable side by side.
private _townLabel = _display ctrlCreate ["RscText", 9525];
_townLabel ctrlSetPosition [0.26, 0.49, 0.48, 0.04];
_townLabel ctrlSetText "Towns (rep clamps to +/-20):";
_townLabel ctrlCommit 0;

private _list = _display ctrlCreate ["RscListBox", 9522];
_list ctrlSetPosition [0.26, 0.53, 0.48, 0.30];
_list ctrlCommit 0;

{
    private _btn = _display ctrlCreate ["RscButton", _x];
    _btn ctrlSetPosition [0.26 + 0.12 * _forEachIndex, 0.84, 0.115, 0.05];
    _btn ctrlSetText (["Rep +/-", "Worth +/-"] select _forEachIndex);
    _btn ctrlCommit 0;
    _btn ctrlAddEventHandler ["ButtonClick", _apply];
} forEach [9523, 9524];

private _tickBtn = _display ctrlCreate ["RscButton", 9528];
_tickBtn ctrlSetPosition [0.26, 0.90, 0.235, 0.05];
_tickBtn ctrlSetText "Fire economy tick";
_tickBtn ctrlCommit 0;
_tickBtn ctrlAddEventHandler ["ButtonClick", {
    remoteExec ["fnc_debug_econ_tick", 2];
    ["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
}];

private _closeBtn = _display ctrlCreate ["RscButton", 9517];
_closeBtn ctrlSetPosition [0.505, 0.90, 0.235, 0.05];
_closeBtn ctrlSetText (localize "STR_DUWS_T_MENU_CLOSE");
_closeBtn ctrlCommit 0;
_closeBtn ctrlAddEventHandler ["ButtonClick", {
    uiNamespace setVariable ["DUWS_debug_econ_display", displayNull];
    closeDialog 0;
}];

// Asked last, so every control the answer writes into already exists by the time it arrives.
["snapshot", player] remoteExec ["fnc_debug_econ_server", 2];
