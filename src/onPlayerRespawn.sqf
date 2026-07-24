sleep 1;
player setUnitLoadout(player getVariable["Saved_Loadout",[]]);

private _savedFace = player getVariable ["Saved_Face", ""];
private _savedSpeaker = player getVariable ["Saved_Speaker", ""];
private _savedGoggles = player getVariable ["Saved_Goggles", ""];
if (_savedFace != "") then { player setFace _savedFace; };
if (_savedSpeaker != "") then { player setSpeaker _savedSpeaker; };
if (_savedGoggles != "") then { player addGoggles _savedGoggles; };
player enableStamina true;
player_fatigue = 1;
player addRating 10000000;

if (!isNil "apocalypse_mode" && apocalypse_mode) then {
    call DUWS_fnc_applyApocalypseFilter;
};

// ========== 清除所有情报物品和金钱 ==========
private _itemsToRemove = [
    "Money_roll",
    "SmartPhone",
    "MobilePhone",
    "FlashDisk",
    "Files",
    "FilesSecret",
    "Wallet_ID",
    "FileTopSecret"
];

private _removedList = [];

// 从物品栏中移除
{
    private _count = 0;
    while {_x in (items player)} do {
        player removeItem _x;
        _count = _count + 1;
    };
    if (_count > 0) then {
        _removedList pushBack format ["%1 x%2", _x, _count];
    };
} forEach _itemsToRemove;

// 从弹匣栏中移除
{
    private _count = 0;
    while {_x in (magazines player)} do {
        player removeMagazine _x;
        _count = _count + 1;
    };
    if (_count > 0) then {
        _removedList pushBack format ["%1 x%2", _x, _count];
    };
} forEach _itemsToRemove;

// 如果有物品被移除，发送本地化通知
if (count _removedList > 0) then {
    private _removedText = _removedList joinString ", ";
    private _title = localize "STR_DUWS_T_RESPAWN_LOSS_TITLE";
    private _desc = format [localize "STR_DUWS_T_RESPAWN_LOSS_DESC", _removedText];
    ["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", player];
};
sleep 10;
// Single hold-action opens the disguise panel (fnc_disguise_menu), which fronts
// both modes -- replaces the two per-mode re-adds. Guard cleared so respawn re-adds.
player setVariable ["DUWS_disguiseMenu_actionAdded", nil];
[
    player,
    localize "STR_DUWS_T_DISGUISE_MENU_ACTION",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
    "alive _target && vehicle _target == _target",
    "alive _target && vehicle _target == _target",
    {},
    {},
    { [] spawn fnc_disguise_menu; },
    {},
    [],
    1.5,
    0,
    false,
    false
] call BIS_fnc_holdActionAdd;
player setVariable ["DUWS_disguiseMenu_actionAdded", true];
player setCaptive false;