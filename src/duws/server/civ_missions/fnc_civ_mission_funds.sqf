// Locality: server, spawned by fnc_civ_mission_request. No bandits: players give the money at the giver through
// fnc_civ_mission_give, and the gift that meets the target is the report.
params ["_id"];
private _e = DUWS_civMissions get _id;
// No group, so the poll's all-bandits-dead notice would fire at once.
_e set ["announced", true];
_e set ["thanks", "STR_DUWS_T_CIVMISSION_FUNDS_THANKS"];
_e set ["won", { params ["_e"]; (_e get "raised") >= (_e get "target") }];
_e set ["lost", { false }];
(_e get "giver") setVariable ["DUWS_civMission_funds", [0, _e get "target"], true];

[_id, "STR_DUWS_T_CIVMISSION_FUNDS_TITLE", "STR_DUWS_T_CIVMISSION_FUNDS_DESC", "help", false] call fnc_civ_mission_present;

private _status = "";
waitUntil { sleep 5; _status = [_id] call fnc_civ_mission_poll; _status != "" };
[_id, _status] call fnc_civ_mission_finish;
