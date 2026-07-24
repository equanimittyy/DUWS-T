// Opens the disguise panel. Single entry point that replaces the two disguise
// hold-actions; the mode buttons remoteExec the unchanged server functions, which
// keep all requirement, cooldown and cover-break logic. Status and civ availability
// are read once on open (re-open to refresh) -- no polling loop needed for a picker.
if (!hasInterface) exitWith {};

if (!createDialog "disguise_dialog") exitWith {};
waitUntil { dialog };

// DUWS_disguised / DUWS_enemyDisguised carry the global flag (the disguise functions
// broadcast them), so the current-state line is correct on the client without a round-trip.
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

// Civilian mode needs a living population to blend into: same gate the old civ
// hold-action used. Grey the button and swap the card text when it can't run.
private _civAllowed = (isNil "CIV_PRESENCE") || {!(CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"])};
if (!_civAllowed) then {
    ctrlEnable [8201, false];
    ctrlSetText [8101, localize "STR_DUWS_T_DISGUISE_MENU_CIV_UNAVAIL"];
};
