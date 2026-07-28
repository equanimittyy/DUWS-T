// Locality: all machines; the addAction body below runs on the machine that triggers it, not
// here (fnc_civ_handler remoteExecs this to target 0 with the JIP flag).
//
// One action in front of what was five. Nothing is decided on the machine that opens the menu:
// picking a row remoteExecs the server, which rolls the town's reaction and owns every spend.
params ["_unit"];

if (isNull _unit) exitWith {};

// The spawn paths re-add on respawn and the JIP queue replays for every joining client, so a
// duplicate is a real risk -- and it would read as two identical entries in one scroll menu.
if (_unit getVariable ["DUWS_civ_menuAdded", false]) exitWith {};
_unit setVariable ["DUWS_civ_menuAdded", true];

private _actionID = _unit addAction [
    localize "STR_DUWS_T_CIV_MENU_ACTION",
    {
        params ["_target"];
        // Spawned: fnc_civ_menu waits on the dialog before it can fill anything in.
        [_target] spawn fnc_civ_menu;
    },
    nil,
    6,
    true,
    true,
    "",
    // Gated on the call-over: a local who has not been told to stop is walking their waypoints,
    // and a menu that opens on someone mid-stride lets the player talk to a whole town without
    // ever announcing themselves. fnc_civ_moveToPlayerServer broadcasts the flag.
    //
    // 15 m, not the 3 m the conversational rows work at, because the menu carries arrest -- an
    // order shouted from a standoff, and walking into arm's reach to give it defeats the point.
    // fnc_civ_menu greys the four talking rows beyond 3 m.
    //
    // A surrendered civilian drops out entirely: what follows an arrest is the search action,
    // which lives on the scroll wheel, and two entries competing there is what this replaced.
    "alive _target && {_target getVariable ['DUWS_civ_stopped', false]} && {_this distance _target < 15} && {!(_target getVariable ['isSurrendered', false])}"
];

_unit setVariable ["civ_menuActionID", _actionID];

_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["removeAllActions", 0];
}];
