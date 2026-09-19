// Locality: server, spawned by fnc_civ_mission_request.
params ["_id"];
private _e = DUWS_civMissions get _id;
private _site = _e get "site";

private _car = [selectRandom (missionNamespace getVariable ["civ_veh_array", []]), _site getPos [8, random 360], random 360] call fnc_civ_spawnCar;
// Kept under the mission's key: an empty car is litter to the map sweep, and a mission with no deadline can
// outlast the litter lifetime.
[_car, _e get "compKey"] call fnc_duws_keep;
_e set ["car", _car];

private _roles = ["rifleman", "rifleman", "autogunner"];
if (random 1 < 0.5) then { _roles pushBack "grenadier" };
private _grp = [_site, _roles] call fnc_bandit_spawn;
if (isNull _grp) exitWith {
    ["WARN", "CIV", format ["civilian mission %1: no bandits spawned", _id]] call fnc_log;
    [_id, "FAILED"] call fnc_civ_mission_finish;
};
[_grp, _site, 30] call BIS_fnc_taskPatrol;
_e set ["group", _grp];
// Read from the entry, not captured locals: fnc_civ_mission_request re-runs "won" at the report.
_e set ["won", { params ["_e"]; private _c = _e get "car"; alive _c && {_c distance (_e get "giver") < 30} }];
_e set ["lost", { params ["_e"]; !alive (_e get "car") }];

[_id, "STR_DUWS_T_CIVMISSION_STOLEN_TITLE", "STR_DUWS_T_CIVMISSION_STOLEN_DESC", "STR_DUWS_T_CIVMISSION_STOLEN_BRIEF", "car"] call fnc_civ_mission_present;

private _status = "";
waitUntil { sleep 5; _status = [_id] call fnc_civ_mission_poll; _status != "" };
[_id, _status] call fnc_civ_mission_finish;
