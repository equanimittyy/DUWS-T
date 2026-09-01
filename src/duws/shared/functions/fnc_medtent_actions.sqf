// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (the caller remoteExecs to target 0).
//
// Everything the tent carries, in one pass: the caller keys its broadcast on the tent's netId, so
// a second broadcast against the same object would silently evict the first.
//
// Rest and the squad-leader reset live here rather than in the request menu -- both are things a
// player walks to the medical area to do, and resting treats who is standing near this tent.
#include "..\includes\action_style.hpp"

params ["_tent"];
if (isNull _tent) exitWith {};

_tent addAction [ACT_AID("STR_DUWS_T_xfgokhbc"), { [] spawn fnc_AI_rearm }, [], 60, false, true, "", "_this distance _target < 12"];

// Run on the server, not the pressing client: fnc_rest_heal deletes and heals server-local AI.
if ((vehiclevarname player) in game_master) then {
    _tent addAction [ACT_AID("STR_DUWS_T_9eiwr3bt"), {
        params ["_target"];
        [player, _target] remoteExec ["fnc_restHealServer", 2];
    }, [], 55, false, true, "", "_this distance _target < 12"];
};

if ((vehiclevarname player) in Squad_Leaders) then {
    _tent addAction [ACT_UTIL("STR_DUWS_T_4jabuvz6"), { [] spawn fnc_groupReset }, [], 50, false, true, "", "_this distance _target < 12"];
};

// Per-player display/audio options: mission-music mute plus the show/hide flags for the earplugs,
// disguise and view-distance actions. All stored in profileNamespace (the profile, not the campaign
// save) so each co-op client keeps its own and it survives death and reload with no server state.
// The menu is its own function so a row can re-open it to show the flipped state.
_tent addAction [ACT_PRIMARY_MENU("STR_DUWS_T_USEROPT_TITLE"), { [] call fnc_user_options_menu }, [], 100, false, true, "", "_this distance _target < 12"];
