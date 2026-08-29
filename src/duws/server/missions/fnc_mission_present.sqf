// Locality: server -- mission threads call it, all server-side.
//
// Draw the search marker, issue the task, then play the opening brief -- in that order, ahead of the
// objective spawn (which can run tens of seconds), because the marker and task are all that tell the
// player where to go. The brief reads only the nearest place name, never the objective, so it runs first.
//
// _taskId is unique per instance (callers append a rounded position); _descText arrives already localised;
// _brief is [[speakerKey, msgKey, delayAfter], ...], each callsign-substituted (fnc_cs) and formatted with
// the place name. Returns the marker name, which the caller hands to fnc_mission_finish at teardown.
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
