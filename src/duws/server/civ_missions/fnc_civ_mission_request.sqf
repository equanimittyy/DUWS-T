// Locality: server. The civilian menu's first row: Work on a local, or Report / Cancel on the giver of a live
// civilian side mission. The giver branch only writes the entry's state -- the mission's thread owns every
// exit, so a report and the giver's death on one tick cannot both run the teardown.
//
// Contract: [_civ, _caller, _row, _force]
//   _row    "WORK" | "CANCEL"
//   _force  debug only: skips the roll and the cap.
#define CIV_MISSION_CAP 3
#define CIV_MISSION_OFFER_CHANCE 0.75
if (!isServer) exitWith {};
params ["_civ", "_caller", ["_row", "WORK"], ["_force", false]];
if (isNull _civ || {isNull _caller} || {!alive _civ}) exitWith {};
if (_caller distance _civ > 3) exitWith {};

private _id = _civ getVariable ["DUWS_civMission_id", -1];
if (_id >= 0) exitWith {
    private _e = DUWS_civMissions getOrDefault [_id, createHashMap];
    if ((_e getOrDefault ["state", ""]) != "active") exitWith {};
    if (_row == "CANCEL") exitWith {
        _e set ["by", _caller];
        _e set ["state", "canceled"];
    };
    if ((_e get "ready") && {[_e] call (_e get "won")}) then {
        _e set ["by", _caller];
        _e set ["state", "reported"];
    };
};

if (_row != "WORK") exitWith {};
if (_civ getVariable ["DUWS_civ_closed", false]) exitWith {};
if (_civ getVariable ["DUWS_civ_arrested", false]) exitWith {};
// Claimed before the pause, as fnc_civ_request claims its civilian: two players at one local must not both pass.
_civ setVariable ["DUWS_civ_closed", true, true];

// The slot is held from the ask, so asks still in their pause cannot overfill the cap.
if (_force || {count DUWS_civMissions < CIV_MISSION_CAP}) then {
    DUWS_civMissionSeq = DUWS_civMissionSeq + 1;
    _id = DUWS_civMissionSeq;
    DUWS_civMissions set [_id, createHashMapFromArray [["state", "offering"]]];
};

[name _caller, localize "STR_DUWS_T_CIVMISSION_ASK"] remoteExec ["fnc_duws_dialogue", _caller];
_civ disableAI "PATH";
sleep 3;

// [thread, cp, [money min, money max], rep, gate]
private _types = [
    ["fnc_civ_mission_camp",   10, [3, 5], 3, { true }],
    ["fnc_civ_mission_stolen",  5, [5, 8], 3, { (missionNamespace getVariable ["civ_veh_array", []]) isNotEqualTo [] }]
] select { call (_x select 4) };
private _town = _civ getVariable ["civ_locIndex", -1];

// A flat chance, not the reputation curve: a hostile town is where the player most needs the reputation a
// mission pays, and the curve offers nothing at -20.
private _site = [];
if (_id >= 0 && {alive _civ} && {_town >= 0} && {_force || {random 1 < CIV_MISSION_OFFER_CHANCE}}) then {
    _site = [_town] call fnc_civ_mission_site;
};
if (_site isEqualTo []) exitWith {
    if (_id >= 0) then { DUWS_civMissions deleteAt _id };
    _civ enableAI "PATH";
    [_civ, _caller, "WORK"] call fnc_civ_close;
};

(selectRandom _types) params ["_thread", "_cp", "_money", "_rep"];
_money params ["_moneyMin", "_moneyMax"];
private _e = DUWS_civMissions get _id;
{ _e set _x } forEach [
    ["state", "active"], ["ready", false], ["announced", false], ["giver", _civ], ["asker", _caller],
    ["town", _town], ["site", _site], ["reward", [_cp, _moneyMin + floor random (_moneyMax - _moneyMin + 1), _rep]],
    ["group", grpNull], ["compKey", format ["civ_mission_%1", _id]], ["marker", ""], ["taskId", ""], ["title", ""]
];

// Off the town's roster, so a town that sleeps leaves them standing; PATH stays off, so the task pin holds.
[[_town] call fnc_town_site_key, _civ, "crowd"] call fnc_site_roster_drop;
_civ setVariable ["DUWS_civMission_id", _id];
_civ setVariable ["DUWS_civMission_state", "active", true];

["INFO", "CIV", format ["civilian mission %1 (%2) offered in town %3 at %4", _id, _thread, _town, _site]] call fnc_log;
[_id] spawn (missionNamespace getVariable _thread);
