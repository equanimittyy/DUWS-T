// Locality: client -- invoked from the environment screen's preset combo
// (shared/includes/enviro_menu.hpp) and once at the end of fnc_enviro_menu.sqf.
//
// A preset answers both parameter screens at once, so applying one clears the selection snapshots
// the two screens restore from and lets each fall back to its own (Default)-marked entries.
// Classic *is* those defaults; Hardcore is those defaults with a short list of overrides layered
// on top, so both presets share this rebuild-from-defaults path and Hardcore adds its own values.
private _sel = lbCurSel 2200;
if (_sel < 0) exitWith {};

private _display = uiNamespace getVariable ["duws_startup_display", displayNull];
if (isNull _display) exitWith {};

// Row order is fixed by fnc_enviro_menu.sqf: Classic, Hardcore, Custom.
duws_preset = ["classic", "hardcore", "custom"] select _sel;
(_display displayCtrl 1900) ctrlSetText localize
    (["STR_DUWS_T_preset_classic_desc", "STR_DUWS_T_preset_hardcore_desc", "STR_DUWS_T_preset_custom_desc"] select _sel);

// Custom is a state the screens fall into, not an answer: it leaves every option where the
// player put it.
if (duws_preset == "custom") exitWith {};

// The preset the config now descends from. duws_preset itself is flipped to "custom" by the first
// edit on either screen, so it cannot answer "did this config start from Hardcore" once the player
// tweaks anything. The campaign screen seeds its Hardcore overrides off this instead, so editing an
// unrelated environment option no longer drops that screen back to Classic defaults.
duws_preset_base = duws_preset;

duws_enviro_sel = nil;
duws_campaign_sel = nil;

// Guarded, because lbSetCurSel raises the very LBSelChanged handlers that drop the row to Custom.
duws_preset_applying = true;
{ lbSetCurSel _x } forEach duws_enviro_defaults;
// Hardcore's environment-screen override goes on here (this screen is live); its campaign-screen
// overrides are applied by fnc_campaign_menu.sqf when that screen builds.
if (duws_preset == "hardcore") then {
    lbSetCurSel [2110, index_hardcore_true];
};
duws_preset_applying = false;
