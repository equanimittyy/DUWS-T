// Locality: all machines; the addAction body below runs on the machine that triggers it, not
// here (fnc_civ_handler remoteExecs this to target 0 with the JIP flag).
//
// One action in front of what was five. Nothing is decided on the machine that opens the menu:
// picking a row remoteExecs the server, which rolls the town's reaction and owns every spend.
#include "..\includes\action_style.hpp"

params ["_unit"];

if (isNull _unit) exitWith {};

// The spawn paths re-add on respawn and the JIP queue replays for every joining client, so a
// duplicate is a real risk -- and it would read as two identical entries in one scroll menu.
if (_unit getVariable ["DUWS_civ_menuAdded", false]) exitWith {};
_unit setVariable ["DUWS_civ_menuAdded", true];

private _actionID = _unit addAction [
    ACT_CIVILIAN_INTERACTION("STR_DUWS_T_CIV_MENU_ACTION"),
    {
        params ["_target"];
        // Spawned: fnc_civ_menu waits on the dialog before it can fill anything in.
        [_target] spawn fnc_civ_menu;
    },
    [],
    50,
    true,
    true,
    "",
    // Gated on the call-over: a local who has not been told to stop is walking their waypoints,
    // and a menu that opens on someone mid-stride lets the player talk to a whole town without
    // ever announcing themselves. fnc_civ_moveToPlayerServer broadcasts the flag.
    //
    // 3 m, half the reach of the call-over that gates it, so everything a local will do for the
    // player happens at arm's length -- arrest included. The 15 m this was existed to let arrest
    // be shouted from a standoff, which skipped walking up to the person, and walking up is what
    // puts the player in the town rather than over it: the call-over halts someone at 6 m and the
    // player closes the rest. fnc_civ_menu no longer range-tests its rows: nothing can open this
    // menu from outside the range they work at.
    //
    // A surrendered civilian drops out entirely: what follows an arrest is the search action,
    // which lives on the scroll wheel, and two entries competing there is what this replaced.
    //
    // Spent civilians drop out on the same principle. One exchange -- talked to, or ordered to
    // put their hands up -- is all a person is worth, so the entry going away is what tells the
    // player this one is finished. Leaving it up invited arresting whoever had just refused.
    //
    // The giver of a civilian side mission is the exception: spent, but open for Report and Cancel, and
    // with no call-over, since they already stand where the task pin shows them.
    "alive _target && {_this distance _target < 3} && {((_target getVariable ['DUWS_civMission_state', '']) != '') || {_target getVariable ['DUWS_civ_stopped', false] && {!(_target getVariable ['isSurrendered', false])} && {!(_target getVariable ['DUWS_civ_closed', false])} && {!(_target getVariable ['DUWS_civ_arrested', false])}}}"
];

_unit setVariable ["civ_menuActionID", _actionID];

_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["removeAllActions", 0];
}];
