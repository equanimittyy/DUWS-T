// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
#include "..\includes\action_style.hpp"

params ["_unit"];

if (isNull _unit) exitWith {};

_unit addAction [
    ACT_CIVILIAN_INTERACTION("STR_DUWS_T_CIV_STOP"),
{
    params ["_target", "_caller", "_actionId"];

    [name _caller, localize "STR_DUWS_T_STOP"] remoteExec ["fnc_duws_dialogue", _caller];
    // No reply line: the local walking over is the answer.
    [_target, _caller] remoteExec ["fnc_civ_moveToPlayerServer", 2];
},
    [],
    50,
    true,
    true,
    "",
    // Facing test on top of the range. getRelDir is 0 straight ahead and wraps through 360, so
    // this is a 15 degree cone either side -- close to an aim test, where the 30 it was read as
    // "roughly on screen" and picked up whoever was standing beside the person meant. Horizontal
    // only: looking over someone's head still counts, which is the intended slack.
    //
    // 6 m, twice the reach of the menu this gates. Calling someone over and then talking to them
    // are two different distances: halting a local you can see, walking up to them and only then
    // getting an exchange is the shape of the interaction, where matching the two meant standing
    // close enough to talk before you were allowed to ask for their attention. The menu still
    // holds at 3 m, so the walk is what earns it.
    //
    // Panicking civilians drop out: someone running from gunfire is not stopping to be called,
    // and the entry coming back is what tells the player the town has settled. fnc_civ_panic
    // broadcasts the flag and clears it once they are pathing normally again.
    //
    // Hidden while already halted, rather than removed on click: DUWS_civ_stopped goes up when the
    // call-over lands and stays up until the halt lapses (fnc_civ_moveToPlayerServer's expiry) or a
    // panic clears it, at which point this entry returns on its own. That is what makes the halt
    // re-usable -- the condition does the one-shot, no add/remove round trip across every machine.
    "_this distance _target < 6 && {abs (180 - (_this getRelDir _target)) > 165} && {!(_target getVariable ['DUWS_civ_panicked', false])} && {!(_target getVariable ['DUWS_civ_stopped', false])}"
];