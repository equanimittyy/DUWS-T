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

// Client-local audio preference: silence the sting that plays when a side mission spawns
// (server/missions/fnc_missionTaskCreate.sqf reads the same flag before playing). Stored in
// profileNamespace, not the campaign save -- a per-player choice that should outlast a reload
// without riding in shared mission state, so each co-op client keeps its own.
private _musicKey = ["STR_DUWS_T_TENT_MUSIC_ON", "STR_DUWS_T_TENT_MUSIC_OFF"] select (profileNamespace getVariable ["DUWS_T_muteMissionMusic", false]);
_tent addAction [ACT_UTIL(_musicKey), {
    params ["_target", "_caller", "_id"];
    private _muted = !(profileNamespace getVariable ["DUWS_T_muteMissionMusic", false]);
    profileNamespace setVariable ["DUWS_T_muteMissionMusic", _muted];
    saveProfileNamespace;
    private _key = ["STR_DUWS_T_TENT_MUSIC_ON", "STR_DUWS_T_TENT_MUSIC_OFF"] select _muted;
    _target setUserActionText [_id, ACT_UTIL(_key)];
}, [], 45, false, true, "", "_this distance _target < 12"];
