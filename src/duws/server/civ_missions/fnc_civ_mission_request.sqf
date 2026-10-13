// Locality: server. The civilian menu's first row: Work on a local, or Report / Cancel on the giver of a live
// civilian side mission. The giver branch only writes the entry's state -- the mission's thread owns every
// exit, so a report and the giver's death on one tick cannot both run the teardown.
//
// Contract: [_civ, _caller, _row, _force]
//   _row    "WORK" | "CANCEL"
//   _force  debug only: skips the roll and the cap.
#define CIV_MISSION_CAP 3
#define CIV_MISSION_OFFER_CHANCE 0.9
#define CIV_MISSION_AP 5
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

// [thread, brief key, cp, [money min, money max], rep, gate, [target min, target max], site check, on a house, in town].
// A target is money the players pay the giver. An in-town job's site is the town centre; the optional site check vets
// each outside-town draw.
private _types = [
    ["fnc_civ_mission_camp",   "STR_DUWS_T_CIVMISSION_CAMP_BRIEF",   10, [3, 5], 3, { true }, []],
    ["fnc_civ_mission_stolen", "STR_DUWS_T_CIVMISSION_STOLEN_BRIEF",  5, [5, 8], 3, { (missionNamespace getVariable ["civ_veh_array", []]) isNotEqualTo [] }, []],
    ["fnc_civ_mission_funds",  "STR_DUWS_T_CIVMISSION_FUNDS_BRIEF",  15, [0, 0], 5, { true }, [9, 15], { true }, false, true],
    // 100 m off the centre keeps the widest field's mines about 25 m clear of a road, out of the traffic.
    ["fnc_civ_mission_mines",  "STR_DUWS_T_CIVMISSION_MINES_BRIEF",  10, [3, 5], 3, { true }, [], { params ["_p"]; (_p nearRoads 100) isEqualTo [] }],
    // REP is the most it pays, one per hostage. The check is the thread's HOSTAGES houses within CLUSTER_RADIUS.
    ["fnc_civ_mission_hostages", "STR_DUWS_T_CIVMISSION_HOSTAGES_BRIEF", 15, [1, 5], 5, { true }, [], { params ["_p"]; count ([_p, 3, 150] call fnc_usableBuildings) >= 5 }, true],
    // The HQ cache's level-ground gate, for the same composition.
    ["fnc_civ_mission_cache",  "STR_DUWS_T_CIVMISSION_CACHE_BRIEF",  15, [0, 0], 3, { true }, [20, 25], { params ["_p"]; ([_p] call fnc_site_terrain) isNotEqualTo [] }]
] select { call (_x select 5) };
(selectRandom _types) params ["_thread", "_briefKey", "_cp", "_money", "_rep", "", "_target", ["_siteOk", { true }], ["_onHouse", false], ["_inTown", false]];
private _town = _civ getVariable ["civ_locIndex", -1];

// A flat chance, not the reputation curve: a hostile town is where the player most needs the reputation a
// mission pays, and the curve offers nothing at -20.
private _site = [];
if (_id >= 0 && {alive _civ} && {_town >= 0} && {_force || {random 1 < CIV_MISSION_OFFER_CHANCE}}) then {
    _site = if (!_inTown) then { [_town, _siteOk, _onHouse] call fnc_civ_mission_site } else {
        getPos ((missionNamespace getVariable ["civ_locations", []]) select _town)
    };
};
if (_site isEqualTo []) exitWith {
    if (_id >= 0) then { DUWS_civMissions deleteAt _id };
    _civ enableAI "PATH";
    [_civ, _caller, "WORK"] call fnc_civ_close;
};

private _roll = { params ["_min", "_max"]; _min + floor random (_max - _min + 1) };
private _reward = [_cp, _money call _roll, _rep, CIV_MISSION_AP];
private _goal = 0;
if (_target isNotEqualTo []) then { _goal = _target call _roll };
private _e = DUWS_civMissions get _id;
{ _e set _x } forEach [
    ["thread", _thread], ["ready", false], ["announced", false], ["giver", _civ], ["town", _town], ["site", _site],
    ["reward", _reward], ["target", _goal], ["raised", 0],
    ["group", grpNull], ["patrols", []], ["compKey", format ["civ_mission_%1", _id]], ["marker", ""], ["giverMarker", ""], ["taskId", ""], ["title", ""],
    ["cleared", { params ["_e"]; ({ alive _x } count units (_e get "group")) == 0 }]
];

// The offer rides the bribe prompt: fnc_civ_bribe_answer checks the answer is the asker's and hands a "WORK"
// row to fnc_civ_mission_accept. Keys and numbers, not text, so the prompt reads in the asker's language.
_civ setVariable ["DUWS_civMission_id", _id];
_civ setVariable ["DUWS_civ_pending", [_caller, "WORK", 0]];
[netId _civ, 0, [_briefKey, floor (_cp * cp_reward_multiplier), floor (CIV_MISSION_AP * cp_reward_multiplier), _reward select 1, _rep, _goal]] remoteExec ["fnc_civ_bribe_prompt", _caller];
[localize "STR_DUWS_T_civ", format [localize _briefKey, _goal]] remoteExec ["fnc_duws_dialogue", _caller];
["INFO", "CIV", format ["civilian mission %1 (%2) offered in town %3 at %4", _id, _thread, _town, _site]] call fnc_log;

// Declined for the asker if the prompt goes unanswered, so a lost client cannot hold a slot for the session.
sleep 120;
if (((DUWS_civMissions getOrDefault [_id, createHashMap]) getOrDefault ["state", ""]) == "offering") then {
    [_civ, _caller, false] call fnc_civ_mission_accept;
};
