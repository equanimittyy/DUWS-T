#include "duws\shared\includes\action_style.hpp"

sleep 1;
// The respawn menu does not report which position was picked, so arriving beside the tent is what
// spends a rally respawn.
private _rally = missionNamespace getVariable ["DUWS_rally_tent", objNull];
if (!isNull _rally && {player distance _rally < 20}) then { [_rally] remoteExec ["fnc_rally_spawned", 2] };

// Explicit strip: the engine dresses a respawned unit in its class kit, free gear on every death.
player setUnitLoadout [[], [], [], [], [], [], "", "", [], ["", "", "", "", "", ""]];

private _savedFace = player getVariable ["Saved_Face", ""];
private _savedSpeaker = player getVariable ["Saved_Speaker", ""];
if (_savedFace != "") then { player setFace _savedFace; };
if (_savedSpeaker != "") then { player setSpeaker _savedSpeaker; };
player_fatigue = ["DUWS_Fatigue", 1] call BIS_fnc_getParamValue;
player enableStamina (player_fatigue != 0);
player addRating 10000000;

// The earplug action was attached to the old body, but fadeSound survives respawn: without
// this re-add a player who died with earplugs in has no way to turn the volume back up.
player addaction [ACT_UTIL("STR_DUWS_T_2rc0nvug"),fnc_earplugs, [], 20, true, true, "", "_this == player && {profileNamespace getVariable ['DUWS_T_showEarplugs', true]}"];

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
    "alive _target && vehicle _target == _target && {profileNamespace getVariable ['DUWS_T_showDisguise', true]}"
];
player setVariable ["DUWS_disguiseMenu_actionAdded", true];
player setCaptive false;