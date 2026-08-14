#include "duws\shared\includes\action_style.hpp"

sleep 1;
player setUnitLoadout(player getVariable["Saved_Loadout",[]]);

private _savedFace = player getVariable ["Saved_Face", ""];
private _savedSpeaker = player getVariable ["Saved_Speaker", ""];
private _savedGoggles = player getVariable ["Saved_Goggles", ""];
if (_savedFace != "") then { player setFace _savedFace; };
if (_savedSpeaker != "") then { player setSpeaker _savedSpeaker; };
if (_savedGoggles != "") then { player addGoggles _savedGoggles; };
player_fatigue = ["DUWS_Fatigue", 0] call BIS_fnc_getParamValue;
player enableStamina (player_fatigue != 0);
player addRating 10000000;

// The earplug action was attached to the old body, but fadeSound survives respawn: without
// this re-add a player who died with earplugs in has no way to turn the volume back up.
player addaction [ACT_UTIL("STR_DUWS_T_2rc0nvug"),fnc_earplugs, [], 20, true, true, "", "_this == player"];

// Same re-add reason as the earplug action above.
[] call fnc_intel_search_action;

// Same re-add reason as the earplug action: the debug menu was attached to the old body.
// Both gates repeated from client_init.sqf -- the parameter alone is mission-wide.
if ((["DUWS_Debug", 0] call BIS_fnc_getParamValue) == 1 && {(vehiclevarname player) in game_master}) then {
    player addAction [ACT_UTIL("STR_DUWS_T_DEBUG_ACTION"), fnc_debug_menu, [], 20, true, true, "", "_this == player"];
};

if (!isNil "apocalypse_mode" && apocalypse_mode) then {
    call DUWS_fnc_applyApocalypseFilter;
};

// clear all intel items and money on respawn
private _itemsToRemove = [
    "Money_roll",
    "SmartPhone",
    "MobilePhone",
    "FlashDisk",
    "Files",
    "FilesSecret",
    "Wallet_ID",
    "Wallet_traitor",
    "FileTopSecret"
];

private _removedList = [];

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

if (count _removedList > 0) then {
    private _removedText = _removedList joinString ", ";
    private _title = localize "STR_DUWS_T_RESPAWN_LOSS_TITLE";
    private _desc = format [localize "STR_DUWS_T_RESPAWN_LOSS_DESC", _removedText];
    ["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", player];
};
sleep 10;
// Scroll-menu action opens the disguise panel (see client_init) -- re-added because
// respawn spawns a fresh unit that carries no prior actions. Guard cleared first.
player setVariable ["DUWS_disguiseMenu_actionAdded", nil];
player addAction [
    ACT_EQUIP("STR_DUWS_T_DISGUISE_MENU_ACTION"),
    { [] spawn fnc_disguise_menu; },
    nil,
    1,
    false,
    true,
    "",
    "alive _target && vehicle _target == _target"
];
player setVariable ["DUWS_disguiseMenu_actionAdded", true];
player setCaptive false;