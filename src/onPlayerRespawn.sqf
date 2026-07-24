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
// onPlayerRespawn.sqf 末尾添加
if (CIV_PRESENCE != "RAVAGE" && CIV_PRESENCE != "WBK" && CIV_PRESENCE != "NONE") then {
    // 清除旧防重标记，允许重新添加
    player setVariable ["DUWS_disguise_actionAdded", nil];
    
    // 重新添加长按动作
    [
        player,
        localize "STR_DUWS_T_DISGUISE_CIV",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
        "alive _target && vehicle _target == _target",
        "alive _target && vehicle _target == _target",
        {
                params ["_target", "_caller", "_actionId", "_arguments"];
                [localize "STR_DUWS_T_DISGUISE_START"] remoteExec ["hint", _caller];
                [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_DISGUISE_START_SUB"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        },
        {},
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            [_caller] remoteExec ["fnc_disguiseAsCivilian", 2];
        },
        {},
        [],
        3,
        0,
        false,  // 完成后不移除动作
        false
    ] call BIS_fnc_holdActionAdd;
    
    player setVariable ["DUWS_disguise_actionAdded", true];
};
// ========== 重新添加伪装敌人动作（重生后） ==========
// 清除旧防重标记，允许重新添加
player setVariable ["DUWS_enemyDisguise_actionAdded", nil];

// 添加长按动作
[
    player,
    localize "STR_DUWS_T_ENEMY_DISGUISE_ACTION",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
    "alive _target",
    "alive _target",
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        [localize "STR_DUWS_T_ENEMY_DISGUISE_START"] remoteExec ["hint", _caller];
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_ENEMY_DISGUISE_START_SUB"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    },
    {},
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        [_caller] remoteExec ["fnc_disguiseAsEnemy", 2];
    },
    {},
    [],
    3,
    0,
    false,
    false
] call BIS_fnc_holdActionAdd;
player setVariable ["DUWS_enemyDisguise_actionAdded", true];
player setCaptive false;