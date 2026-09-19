// Locality: server. The answer to a job offer: fnc_civ_bribe_answer hands it over once the answer is proven the
// asker's, and fnc_civ_mission_request calls it with a decline when the prompt times out.
params ["_civ", "_caller", ["_accepted", false]];
private _id = _civ getVariable ["DUWS_civMission_id", -1];
private _e = DUWS_civMissions getOrDefault [_id, createHashMap];
if ((_e getOrDefault ["state", ""]) != "offering") exitWith {};
_civ setVariable ["DUWS_civ_pending", nil];

if (!_accepted || {!alive _civ}) exitWith {
    DUWS_civMissions deleteAt _id;
    _civ setVariable ["DUWS_civMission_id", nil];
    _civ enableAI "PATH";
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_CIVMISSION_DECLINED"] remoteExec ["fnc_duws_dialogue", _caller];
    [_civ, _caller, "WORK", false] call fnc_civ_close;
};

_e set ["state", "active"];
// Off the town's roster, so a town that sleeps leaves them standing; PATH stays off, so the task pin holds.
[[_e get "town"] call fnc_town_site_key, _civ, "crowd"] call fnc_site_roster_drop;
_civ setVariable ["DUWS_civMission_state", "active", true];
["INFO", "CIV", format ["civilian mission %1 accepted by %2", _id, name _caller]] call fnc_log;
[_id] spawn (missionNamespace getVariable (_e get "thread"));
