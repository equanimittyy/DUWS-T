// Opens the disguise panel. Each Activate button remoteExecs its server function, which keeps all
// requirement, cooldown and cover-break logic. Status and card availability are read once on open
// (re-open to refresh) -- no polling loop needed for a picker.
if (!hasInterface) exitWith {};

disableSerialization;
private _display = createDialog ["disguise_dialog", false];
if (isNull _display) exitWith {};

// DUWS_disguised / DUWS_enemyDisguised carry the global flag (the disguise functions broadcast them),
// so the current-state line is correct on the client without a round-trip. The status row doubles as a
// state light -- civilian purple, enemy red, none dark grey (dark, not light, to hold contrast against
// the white row text). Only this one row is tinted.
private _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_NONE";
private _statusBg = [0.25, 0.25, 0.25, 0.7];
if (player getVariable ["DUWS_disguised", false]) then {
    _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_CIV";
    _statusBg = [0.4, 0, 0.5, 0.7];
};
if (player getVariable ["DUWS_enemyDisguised", false]) then {
    _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_ENEMY";
    _statusBg = [0.5, 0, 0, 0.7];
};
private _statusCtrl = _display displayCtrl 8100;
_statusCtrl ctrlSetText _status;
_statusCtrl ctrlSetBackgroundColor _statusBg;

// Neither mode runs without a civilian population or in the zombie modes. Grey the buttons and swap
// the card text when they can't run. Cooldown is deliberately not gated here -- the Activate button
// always fires, and the server function hints the remaining cooldown on demand. No client countdown
// to drift out of sync.
private _allowed = (isNil "CIV_PRESENCE") || {!(CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"])};
if (!_allowed) then {
    (_display displayCtrl 8201) ctrlEnable false;
    (_display displayCtrl 8101) ctrlSetText (localize "STR_DUWS_T_DISGUISE_MENU_CIV_UNAVAIL");
    (_display displayCtrl 8202) ctrlEnable false;
    (_display displayCtrl 8104) ctrlSetText (localize "STR_DUWS_T_DISGUISE_MENU_ENEMY_UNAVAIL");
};
