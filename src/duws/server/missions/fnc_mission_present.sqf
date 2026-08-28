// Locality: server -- mission threads call it, all server-side.
//
// The presentation step every side mission owes before it spawns anything: draw the search marker,
// issue the task, then play the opening brief. Kept in this order and ahead of the objective spawn
// because the marker and task are the only things telling the player where to go, and a spawn can run
// for tens of seconds -- the brief reads only the nearest place name, never the objective, so it is
// free to run first and the player hears the opening line while the guard force is still standing up.
//
// _pos       the marker/task position (the search-ring centre); the nearest settlement to it names
//            the "near %1" brief.
// _taskId    caller-built task id (unique per instance -- callers append a rounded position).
// _descText  the task description, already localised by the caller.
// _brief     optional [[speakerKey, msgKey, delayAfter], ...]; each line is callsign-substituted
//            (fnc_cs) and its message formatted with the place name, played in order.
//
// Returns the marker name, which the caller hands to fnc_mission_finish to clear at teardown.
params ["_pos", "_radius", "_taskId", "_descText", "_mission_name", "_taskType", ["_brief", []]];

private _marker = [_pos, _radius] call fnc_missionMarkerData;
[_taskId, _descText, _mission_name, _pos, _taskType] call fnc_missionTaskCreate;

private _place = [_pos] call fnc_place_name;
{
    _x params ["_spk", "_msg", ["_delay", 0]];
    [localize _spk, [format [localize _msg, _place]] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    if (_delay > 0) then { sleep _delay };
} forEach _brief;

_marker
