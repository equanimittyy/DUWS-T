// Locality: client -- invoked from the environment screen's preset combo
// (shared/includes/enviro_menu.hpp) and once at the end of fnc_enviro_menu.sqf.
//
// A preset answers both parameter screens at once, so applying one clears the selection snapshots
// the two screens restore from and lets each fall back to its own (Default)-marked entries.
// Classic *is* those defaults, which is why the preset carries no values of its own: a second
// preset would be a list of overrides applied on top of this, not a replacement for it.
private _sel = lbCurSel 2200;
if (_sel < 0) exitWith {};

private _display = uiNamespace getVariable ["duws_startup_display", displayNull];
if (isNull _display) exitWith {};

// Row order is fixed by fnc_enviro_menu.sqf: Classic first, Custom second.
duws_preset = ["classic", "custom"] select _sel;
(_display displayCtrl 1900) ctrlSetText localize
    (["STR_DUWS_T_preset_classic_desc", "STR_DUWS_T_preset_custom_desc"] select _sel);

// Custom is a state the screens fall into, not an answer: it leaves every option where the
// player put it.
if (_sel != 0) exitWith {};

duws_enviro_sel = nil;
duws_campaign_sel = nil;

// Guarded, because lbSetCurSel raises the very LBSelChanged handlers that drop the row to Custom.
duws_preset_applying = true;
{ lbSetCurSel _x } forEach duws_enviro_defaults;
duws_preset_applying = false;
