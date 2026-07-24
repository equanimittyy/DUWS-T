// Opens the disguise panel. Single entry point that replaces the two disguise
// hold-actions; the mode buttons remoteExec the unchanged server functions, which
// keep all requirement, cooldown and cover-break logic. Status, cooldowns and the
// Activate buttons refresh live once per second while the panel is open (the loop
// ends when the dialog closes).
if (!hasInterface) exitWith {};

if (!createDialog "disguise_dialog") exitWith {};
waitUntil { dialog };

// Civilian mode needs a living population to blend into. CIV_PRESENCE is fixed for the
// session, so set the unavailable card text once here; the button's enabled state is
// handled per refresh below (it also depends on the live cooldown).
private _civAllowed = (isNil "CIV_PRESENCE") || {!(CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"])};
if (!_civAllowed) then {
    ctrlSetText [8101, localize "STR_DUWS_T_DISGUISE_MENU_CIV_UNAVAIL"];
};

// One refresh pass: current-state line (DUWS_disguised / DUWS_enemyDisguised are broadcast),
// each cooldown countdown, and each Activate button's enabled state (enabled only when its
// cooldown is Ready -- civ additionally needs a population). serverTime reads the same on
// every machine, so the broadcast DUWS_*_cdEnd give an accurate countdown on host and clients.
private _fnc_refresh = {
    private _civAllowed = (isNil "CIV_PRESENCE") || {!(CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"])};
    private _civRem = (player getVariable ["DUWS_disguise_cdEnd", 0]) - serverTime;
    private _enemyRem = (player getVariable ["DUWS_enemyDisguise_cdEnd", 0]) - serverTime;

    private _fnc_cdText = {
        params ["_rem"];
        private _val = if (_rem <= 0) then {
            localize "STR_DUWS_T_COOLDOWN_READY"
        } else {
            format ["%1min%2sec", floor (_rem / 60), floor (_rem % 60)]
        };
        format [localize "STR_DUWS_T_DISGUISE_MENU_COOLDOWN", _val]
    };

    private _status = if (player getVariable ["DUWS_disguised", false]) then {
        localize "STR_DUWS_T_DISGUISE_MENU_STATUS_CIV"
    } else {
        if (player getVariable ["DUWS_enemyDisguised", false]) then {
            localize "STR_DUWS_T_DISGUISE_MENU_STATUS_ENEMY"
        } else {
            localize "STR_DUWS_T_DISGUISE_MENU_STATUS_NONE"
        };
    };

    ctrlSetText [8100, _status];
    ctrlSetText [8102, [_civRem] call _fnc_cdText];
    ctrlSetText [8105, [_enemyRem] call _fnc_cdText];
    ctrlEnable [8201, _civAllowed && (_civRem <= 0)];
    ctrlEnable [8202, _enemyRem <= 0];
};

call _fnc_refresh;
[_fnc_refresh] spawn {
    params ["_fnc_refresh"];
    while { dialog } do { sleep 1; call _fnc_refresh; };
};
