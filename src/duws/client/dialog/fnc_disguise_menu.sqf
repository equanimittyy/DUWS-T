// Opens the disguise panel. Each card's button remoteExecs its server function, which keeps all
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
private _activeBtn = -1;
if (player getVariable ["DUWS_disguised", false]) then {
    _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_CIV";
    _statusBg = [0.4, 0, 0.5, 0.7];
    _activeBtn = 8201;
};
if (player getVariable ["DUWS_enemyDisguised", false]) then {
    _status = localize "STR_DUWS_T_DISGUISE_MENU_STATUS_ENEMY";
    _statusBg = [0.5, 0, 0, 0.7];
    _activeBtn = 8202;
};
private _statusCtrl = _display displayCtrl 8100;
_statusCtrl ctrlSetText _status;
_statusCtrl ctrlSetBackgroundColor _statusBg;
if (_activeBtn >= 0) then {
    private _btn = _display displayCtrl _activeBtn;
    _btn ctrlSetText (localize "STR_DUWS_T_DISGUISE_MENU_DEACTIVATE");
    _btn buttonSetAction "closeDialog 0; [player] remoteExec ['fnc_disguise_cancel', 2];";
};

private _fnc_section = {
    params ["_titleKey", "_lines"];
    format ["<t size='1.15' color='#ffcc66'>%1</t><br/>%2", localize _titleKey, (_lines apply { "- " + _x }) joinString "<br/>"]
};
private _info = localize "STR_DUWS_T_DISGUISE_MENU_INFO_NONE";
if (_activeBtn == 8201) then {
    _info = ["STR_DUWS_T_DISGUISE_MENU_INFO_CIV_TITLE", [
        "STR_DUWS_T_DISGUISE_MENU_INFO_CIV_KIT", "STR_DUWS_T_DISGUISE_MENU_INFO_CIV_VEHICLE",
        "STR_DUWS_T_DISGUISE_MENU_INFO_CIV_THROW", "STR_DUWS_T_DISGUISE_MENU_INFO_CIV_SITE",
        "STR_DUWS_T_DISGUISE_MENU_INFO_CIV_SUSPICION"
    ] apply { localize _x }] call _fnc_section;
};
if (_activeBtn == 8202) then {
    // Set by the server's disguise monitor, because only the server holds the OPFOR kit.
    (player getVariable ["DUWS_enemyDisguise_kit", [0, []]]) params ["_floor", "_mismatch"];
    // Item names come from mod config, where an unescaped & or < voids the whole parseText.
    private _fnc_escape = { ((_this regexReplace ["&", "&amp;"]) regexReplace ["<", "&lt;"]) regexReplace [">", "&gt;"] };
    private _wrong = (_mismatch select { (_x select 1) != "" }) apply {
        _x params ["_slot", "_cls"];
        private _root = ["CfgWeapons", "CfgVehicles"] select (_slot in ["backpack", "vehicle"]);
        getText (configFile >> _root >> _cls >> "displayName") call _fnc_escape
    };
    private _lacking = (_mismatch select { (_x select 1) == "" }) apply { localize ("STR_DUWS_T_ENEMY_DISGUISE_SLOT_" + toUpper (_x select 0)) };
    private _gear = [];
    if (_wrong isNotEqualTo []) then { _gear pushBack format [localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_WRONG_FMT", _wrong joinString ", "] };
    if (_lacking isNotEqualTo []) then { _gear pushBack format [localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_MISSING_FMT", _lacking joinString ", "] };
    if (_gear isEqualTo []) then { _gear pushBack localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_CLEAN" };
    _info = ["STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_TITLE", [
        format [localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_FLOOR_FMT", _floor]
            + ((_gear apply { "<br/><t color='#b0b0b0'>    - " + _x + "</t>" }) joinString ""),
        localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_SUSPICION",
        localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_ATTACK",
        localize "STR_DUWS_T_DISGUISE_MENU_INFO_ENEMY_UNIFORM"
    ]] call _fnc_section;
};
(_display displayCtrl 8105) ctrlSetStructuredText parseText format ["<t align='left'>%1</t>", _info];

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
