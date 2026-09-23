// Locality: client -- a command-column button body in the request menu, so it runs on whoever opened it.
/*
    One teleport for every place command can put the player: the main base, each FOB, and the rally
    point a squad leader planted. The rally is the only destination that is spent -- each arrival
    burns one of its ten and the server pulls the flag at zero.

    The enable_fast_travel parameter gates base-to-base travel only. A rally was bought and planted
    in play, so it stays reachable in a game hosted with fast travel off.
*/
if (!hasInterface) exitWith {};

private _travel = {
    params ["_pos", "_label", ["_rally", objNull]];
    // Scheduled thread: the fade below sleeps, and this fires from an unscheduled UI button handler.
    [_pos, _label, _rally] spawn {
        params ["_pos", "_label", "_rally"];
        // Only the traveller is faded: arriving elsewhere mid-stride reads as a glitch, but nobody
        // at either end of the trip has a reason to lose their screen.
        titleCut ["", "BLACK OUT", 1.5];
        sleep 1.7;

        private _dest = [(_pos select 0) + 3, (_pos select 1)];
        player setPos _dest;

        // A player subordinate is deliberately left behind: being teleported by someone else's menu
        // click is not something to discover mid-firefight. No player can be under another player's
        // command yet, so the filter drops nobody today.
        private _followers = (units group player) select {_x != player && {alive _x} && {!isPlayer _x}};
        {
            // Ringed, not stacked: setPos'd units sharing one spot end up inside one another and the
            // engine resolves it by shoving them apart.
            private _angle = 360 * _forEachIndex / (count _followers);
            _x setPos [(_dest select 0) + (sin _angle) * 5, (_dest select 1) + (cos _angle) * 5];
        } forEach _followers;

        titleCut ["", "BLACK IN", 1.5];
        // Spent on arrival, not on the pick: a trip the player backs out of costs the team nothing.
        if (!isNull _rally) then { [_rally] remoteExec ["fnc_rally_travelled", 2] };
        hint format [localize "STR_DUWS_T_s4i32jjh", _label];
    };
};

private _entries = [];

if (enable_fast_travel) then {
    // Matches the HQ's own map marker text (fnc_BluHQinit), which is what the player reads it as.
    private _base = "Main Base";
    _entries pushBack [_base, _travel, [PosOfBLUHQ, _base]];
    {
        private _name = Array_of_FOBname select _forEachIndex;
        _entries pushBack [_name, _travel, [getPos _x, _name]];
    } forEach Array_of_FOBS;
};

private _rally = missionNamespace getVariable ["DUWS_rally_tent", objNull];
if (!isNull _rally) then {
    _entries pushBack [
        format [localize "STR_DUWS_T_RALLY_MARKER", missionNamespace getVariable ["DUWS_rally_travels", 0]],
        _travel,
        [getPos _rally, localize "STR_DUWS_T_RALLY_POINT", _rally]
    ];
};

if (_entries isEqualTo []) exitWith { hint localize "STR_DUWS_T_gogv37ur" };

[localize "STR_DUWS_T_uwdgfnbc", _entries] call fnc_open_action_menu;
