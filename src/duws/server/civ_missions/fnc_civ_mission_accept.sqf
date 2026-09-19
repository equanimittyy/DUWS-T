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
// Off the town's roster, so a town that sleeps leaves them standing.
[[_e get "town"] call fnc_town_site_key, _civ, "crowd"] call fnc_site_roster_drop;
_civ setVariable ["DUWS_civMission_state", "active", true];

// Indoors, off the street, where traffic cannot run them over; PATH goes off again on arrival so they stay.
private _house = ([getPos _civ, 3, 150] call fnc_usableBuildings) param [0, objNull];
if (!isNull _house) then {
    private _spots = [_house] call BIS_fnc_buildingPositions;
    private _floor = selectMin (_spots apply { _x select 2 });
    // Ground floor: a roof or balcony slot is not indoors, and upstairs is harder to reach within talk range.
    private _spot = selectRandom (_spots select { (_x select 2) < _floor + 1 });
    _civ enableAI "PATH";
    _civ doMove _spot;
    [_civ, _spot] spawn {
        params ["_civ", "_spot"];
        private _giveUp = time + 120;
        waitUntil { sleep 2; !alive _civ || {_civ distance _spot < 2} || {time > _giveUp} };
        // The finish hands a giver back to the town; only a giver still on a job is pinned.
        if (alive _civ && {(_civ getVariable ["DUWS_civMission_state", ""]) != ""}) then { _civ disableAI "PATH" };
    };
};
["INFO", "CIV", format ["civilian mission %1 accepted by %2", _id, name _caller]] call fnc_log;
[_id] spawn (missionNamespace getVariable (_e get "thread"));
