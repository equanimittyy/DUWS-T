// Opens the disguise panel. Single entry point that replaces the two disguise
// hold-actions; the mode buttons remoteExec the unchanged server functions, which
// keep all requirement, cooldown and cover-break logic. Status and civ availability
// are read once on open (re-open to refresh) -- no polling loop needed for a picker.
if (!hasInterface) exitWith {};

disableSerialization;
private _display = createDialog ["disguise_dialog", false];
if (isNull _display) exitWith {};

// DUWS_disguised carries the global flag (fnc_disguiseAsCivilian broadcasts it), so the
// current-state line is correct on the client without a round-trip. The status row doubles as a
// state light -- civilian purple, none dark grey (dark, not light, to hold contrast against the
// white row text). Only this one row is tinted.
private _status = "";
private _statusBg = [];
if (player getVariable ["DUWS_disguised", false]) then {
    _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_CIV";
    _statusBg = [0.4, 0, 0.5, 0.7];
} else {
    _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_NONE";
    _statusBg = [0.25, 0.25, 0.25, 0.7];
};
private _statusCtrl = _display displayCtrl 8100;
_statusCtrl ctrlSetText _status;
_statusCtrl ctrlSetBackgroundColor _statusBg;

// Civilian mode needs a living population to blend into: same gate the old civ
// hold-action used. Grey the button and swap the card text when it can't run.
// Cooldown is deliberately not gated here -- the Activate button always fires, and
// the server function hints the remaining cooldown on demand. No client countdown to
// drift out of sync.
private _civAllowed = (isNil "CIV_PRESENCE") || {!(CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"])};
if (!_civAllowed) then {
    (_display displayCtrl 8201) ctrlEnable false;
    (_display displayCtrl 8101) ctrlSetText (localize "STR_DUWS_T_DISGUISE_MENU_CIV_UNAVAIL");
};
