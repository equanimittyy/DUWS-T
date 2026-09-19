// Locality: server, spawned by fnc_civ_mission_request.
params ["_id"];
private _e = DUWS_civMissions get _id;
private _site = _e get "site";
[[["Land_Campfire_F", 0, 0, 0, 0], ["Land_TentA_F", 5, 3, 0, 200], ["Land_TentA_F", -4, 4, 0, 140]], _site, _e get "compKey"] call fnc_composition_place;

private _roles = ["rifleman", "rifleman", "rifleman", "autogunner", "autogunner", "grenadier"];
if (random 1 < 0.5) then { _roles pushBack "grenadier" };
if (random 1 < 0.5) then { _roles pushBack "at" };
if (random 1 < 0.5) then { _roles pushBack "medic" };
private _grp = [_site, _roles] call fnc_bandit_spawn;
if (isNull _grp) exitWith {
    ["WARN", "CIV", format ["civilian mission %1: no bandits spawned", _id]] call fnc_log;
    [_id, "FAILED"] call fnc_civ_mission_finish;
};
[_grp, "closepatrol", _site, 100] call fnc_apply_posture;
_e set ["group", _grp];
_e set ["pairs", [_site, floor random 3] call fnc_bandit_pairs];
// Read from the entry, not a captured local: fnc_civ_mission_request re-runs it at the report.
_e set ["won", { params ["_e"]; ({ alive _x } count units (_e get "group")) == 0 }];
_e set ["lost", { false }];

[_id, "STR_DUWS_T_CIVMISSION_CAMP_TITLE", "STR_DUWS_T_CIVMISSION_CAMP_DESC", "attack"] call fnc_civ_mission_present;

private _status = "";
waitUntil { sleep 5; _status = [_id] call fnc_civ_mission_poll; _status != "" };
[_id, _status] call fnc_civ_mission_finish;
