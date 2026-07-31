// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (the caller remoteExecs to target 0).
//
// Everything the medical tent carries, added in one pass. One adder per object is a hard
// constraint rather than a preference: the caller keys its broadcast on the tent's netId, and a
// second broadcast against the same object silently evicts the first.
//
// Rest and the squad-leader reset live here rather than in the request menu. Both are things a
// player walks to the medical area to do -- resting treats who is standing near this tent, and a
// reset is a housekeeping act, not an order to the war.
#include "..\includes\action_style.hpp"

params ["_tent"];
if (isNull _tent) exitWith {};

_tent addAction [ACT_AID("STR_DUWS_T_xfgokhbc"), { [] spawn fnc_AI_rearm }, [], 60, false, true, "", "_this distance _target < 12"];

// The server decides, not the pressing client: the FOB's old copy stamped and published the
// cooldown from its own machine, so two players triggering it inside one propagation window both
// passed. The tent is the rest site, so only troops standing by it are treated.
if ((vehiclevarname player) in game_master) then {
    _tent addAction [ACT_AID("STR_DUWS_T_9eiwr3bt"), {
        params ["_target"];
        [player, _target] remoteExec ["fnc_restHealServer", 2];
    }, [], 55, false, true, "", "_this distance _target < 12"];
};

if ((vehiclevarname player) in Squad_Leaders) then {
    _tent addAction [ACT_UTIL("STR_DUWS_T_4jabuvz6"), { [] spawn fnc_groupReset }, [], 50, false, true, "", "_this distance _target < 12"];
};
