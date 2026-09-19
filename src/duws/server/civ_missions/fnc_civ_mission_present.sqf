// Locality: server. No operation name, title card or music: those announce an HQ operation (fnc_missionTaskCreate).
params ["_id", "_titleKey", "_descKey", "_taskType", ["_search", true]];
private _e = DUWS_civMissions get _id;

// A job with nothing to find pins its site exactly.
private _centre = _e get "site";
if (_search) then {
    _centre = _centre getPos [random 150, random 360];
    _e set ["marker", [_centre, 250] call fnc_missionMarkerData];
};

// fnc_civ_mission_poll moves it on its 5 s tick; the giver's walk indoors leaves the task pin behind.
private _giverMarker = format ["civ_mission_giver_%1", _id];
createMarker [_giverMarker, getPosATL (_e get "giver")];
_giverMarker setMarkerShape "ICON";
_giverMarker setMarkerType "mil_warning";
_giverMarker setMarkerColor "ColorBlue";
_giverMarker setMarkerText localize "STR_DUWS_T_civ";
_e set ["giverMarker", _giverMarker];

private _taskId = format ["civ_mission_%1", _id];
_e set ["taskId", _taskId];
private _title = localize _titleKey;
private _townName = text ((missionNamespace getVariable ["civ_locations", []]) select (_e get "town"));
if (_townName != "") then { _title = format ["%1: %2", _townName, _title] };
_e set ["title", _title];
(_e get "reward") params ["_cp", "_money", "_rep"];
private _pay = if (_money > 0) then {
    format [localize "STR_DUWS_T_CIVMISSION_CPMONEY", floor (_cp * cp_reward_multiplier), _money]
} else {
    format [localize "STR_DUWS_T_CIVMISSION_CP", floor (_cp * cp_reward_multiplier)]
};
private _desc = (format [localize _descKey, _e get "target"]) + "<br />" + (localize "STR_DUWS_T_mission_divider")
    + _pay + format [localize "STR_DUWS_T_mission_rep", _rep];
// Server-side, never remoteExec'd (arma_engine_gotchas.md). "CREATED" leaves the HQ mission the current task.
[west, [_taskId], [_desc, _title, ""], [_centre select 0, _centre select 1], "CREATED", 1, true, _taskType, false] call BIS_fnc_taskCreate;
