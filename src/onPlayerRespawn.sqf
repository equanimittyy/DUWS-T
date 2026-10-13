#include "duws\shared\includes\action_style.hpp"

sleep 1;
{
    _x params ["_anchor", "_tp"];
    if (player distance2D _anchor < 4) exitWith {
        player setPosWorld _tp;
        hint localize "STR_DUWS_KILLHOUSE_ARRIVE";
    };
} forEach (missionNamespace getVariable ["killhouse_respawns", []]);

// The engine dresses a respawn in its class kit, so the death loadout replaces it. The corpse keeps the
// original, so only unlimited gear is copied: a copy of tracked gear, money or intel would mint it.
private _keep = {
    params ["_cls", "_isWeapon"];
    if (_isWeapon) then { _cls = [_cls] call fnc_arsenal_weapon_row };
    !(_cls in DUWS_forcedRemoveItems) && {([_cls] call DUWS_fnc_arsenal_countFor) < 0}
};
player setUnitLoadout ([DUWS_deathLoadout, _keep] call DUWS_fnc_loadout_keep);

private _savedFace = player getVariable ["Saved_Face", ""];
private _savedSpeaker = player getVariable ["Saved_Speaker", ""];
if (_savedFace != "") then { player setFace _savedFace; };
if (_savedSpeaker != "") then { player setSpeaker _savedSpeaker; };
player_fatigue = missionNamespace getVariable ["DUWS_paramFatigue", 1];
player enableStamina (player_fatigue != 0);
player addRating 10000000;

// The traits client_init.sqf grants stay on the old body, and the slot's class has none of them.
player setUnitTrait ["Medic",true];
player setUnitTrait ["Engineer",true];
player setUnitTrait ["uavHacker",true];
player setUnitTrait ["explosiveSpecialist",true];

// The earplug action was attached to the old body, but fadeSound survives respawn: without
// this re-add a player who died with earplugs in has no way to turn the volume back up.
player addaction [ACT_UTIL("STR_DUWS_T_2rc0nvug"),fnc_earplugs, [], 20, true, true, "", "_this == player && {profileNamespace getVariable ['DUWS_T_showEarplugs', true]}"];

// Same re-add reason as the earplug action above.
[] call fnc_intel_search_action;
[] call fnc_vehicle_collect_action;

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
// respawn spawns a fresh unit that carries no prior actions.
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