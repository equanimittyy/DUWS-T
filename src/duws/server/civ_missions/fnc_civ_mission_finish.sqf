// Locality: server; a mission's own thread is its only caller.
//
// A job's men are owned by their group handles, not by fnc_mission_claim's token: the token belongs to the
// single HQ slot, and advancing it here would re-stamp a running HQ mission's later claims.
params ["_id", "_status"];
private _e = DUWS_civMissions getOrDefault [_id, createHashMap];
if (count _e == 0) exitWith {};
private _giver = _e get "giver";

if ((_e get "marker") != "") then { [_e get "marker"] call fnc_missionMarkerClear };
if ((_e get "giverMarker") != "") then { deleteMarker (_e get "giverMarker") };
if ((_e get "taskId") != "") then { [_e get "taskId", _status] call fnc_missionTaskEnd };

switch (_status) do {
    case "SUCCEEDED": {
        (_e get "reward") params ["_cp", "_money", "_rep"];
        private _cpPaid = floor (_cp * cp_reward_multiplier);
        [_cpPaid, format ["civilian mission %1", _id]] call fnc_cp_adjust;
        // Paid into the hands of whoever reported the job, not onto the giver's feet: a player who walks
        // away without looking down is a player who was not paid. A reporter who has since left the
        // session is paid where the giver stands, for whoever is there to take it.
        // fnc_money_drop leaves an empty holder on the ground for a zero count.
        private _reporter = _e getOrDefault ["by", objNull];
        if (_money > 0) then {
            if (isNull _reporter) then { [[["Money_roll", _money]], getPosATL _giver] call fnc_money_drop }
            else { ["Money_roll", _money, format [localize "STR_DUWS_T_CIVMISSION_PAID", _money]] remoteExec ["fnc_loot_grant", _reporter] };
        };
        [_e get "town", _rep, "civ_mission"] call fnc_town_rep_adjust;
        private _near = allPlayers select { _x distance _giver < 30 };
        [localize "STR_DUWS_T_civ", localize (_e getOrDefault ["thanks", "STR_DUWS_T_CIVMISSION_THANKS"])] remoteExec ["fnc_duws_dialogue", _near];
        ["cpaddedmission", [_cpPaid]] remoteExec ["BIS_fnc_showNotification", [0, -2] select isDedicated];
    };
    case "CANCELED": {
        private _by = _e get "by";
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_CIVMISSION_CANCELED"] remoteExec ["fnc_duws_dialogue", _by];
    };
};

private _men = units (_e get "group");
{ _men append units _x } forEach (_e get "patrols");
{ _x setVariable ["DUWS_binMe", true] } forEach (_men select { alive _x });
[_e get "compKey"] call fnc_duws_release;

if (!isNull _giver) then {
    _giver setVariable ["DUWS_civMission_state", nil, true];
    _giver setVariable ["DUWS_civMission_funds", nil, true];
    _giver setVariable ["DUWS_civMission_id", nil];
    // Not back on the roster: the town may have slept and refilled without them. The sweep takes them
    // once no player is near.
    _giver setVariable ["DUWS_binMe", true];
    if (alive _giver) then {
        _giver enableAI "PATH";
        [_giver] call fnc_civ_resume;
    };
};

DUWS_civMissions deleteAt _id;
["INFO", "CIV", format ["civilian mission %1 ended %2", _id, _status]] call fnc_log;
