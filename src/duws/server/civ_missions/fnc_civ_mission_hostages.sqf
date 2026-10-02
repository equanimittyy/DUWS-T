// Locality: server, spawned by fnc_civ_mission_request.
#define HOSTAGES 5
#define CLUSTER_RADIUS 150
#define REP_FREED 1
#define REP_ALL_LOST -3
// The sighting gate and clock of fnc_rescue_hostage_mission, which carries the why.
#define CONFIRM 1.5
#define DET_RANGE 300
#define DET_FRESH 5
#define CLOCK 300
#define CONFIRM_HOLD 3
params ["_id"];
private _e = DUWS_civMissions get _id;
private _site = _e get "site";
private _town = _e get "town";

// Nearest first, so the houses are the tightest cluster round the vetted one.
private _houses = ([_site, 3, CLUSTER_RADIUS] call fnc_usableBuildings) select [0, HOSTAGES];
if (count _houses < HOSTAGES) exitWith {
    ["WARN", "CIV", format ["civilian mission %1: %2 of %3 houses left", _id, count _houses, HOSTAGES]] call fnc_log;
    [_id, "FAILED"] call fnc_civ_mission_finish;
};
// Before any unit spawns: a piece that thaws over a unit flings it, lethally.
{ [_x, _e get "compKey", 0] call fnc_furnish_building } forEach _houses;
sleep 1;

private _teams = _houses apply { [getPosATL _x, ["rifleman", "autogunner", "grenadier"]] call fnc_bandit_spawn };
_e set ["patrols", (_teams select { !isNull _x }) + ([_site, floor random 5] call fnc_bandit_pairs)];
if ((_teams findIf { isNull _x }) >= 0) exitWith {
    ["WARN", "CIV", format ["civilian mission %1: no bandits spawned", _id]] call fnc_log;
    [_id, "FAILED"] call fnc_civ_mission_finish;
};

private _civClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_2_F", "C_man_polo_4_F", "C_man_p_fugitive_F", "C_man_hunter_1_F", "C_Man_casual_1_F", "C_Man_casual_4_F"];
private _hostages = [];
// [hostage, guard team, marker] while the hostage is held.
private _held = [];
{
    private _house = _x;
    private _grp = _teams select _forEachIndex;
    _house setVariable ["DUWS_garrisonedBy", _grp];
    [_grp, [_house], 3, "AUTO"] call fnc_spreadIntoBuildings;

    // Captive so the guards hold fire; MOVE, not PATH, off so he can still walk once freed.
    private _hpos = selectRandom ([_house] call BIS_fnc_buildingPositions);
    private _hgrp = [_hpos, WEST, [selectRandom _civClasses]] call BIS_fnc_spawnGroup;
    _hgrp deleteGroupWhenEmpty true;
    private _h = leader _hgrp;
    _h setPosATL _hpos;
    _h setDir (random 360);
    _h setCaptive true;
    _h setBehaviour "CARELESS";
    _h setUnitPos "MIDDLE";
    _h disableAI "MOVE";
    _h setVariable ["AIS_noReviveInit", true, true];
    // Halved hits survive a stray round mid-firefight; the execution backstop's setDamage skips HandleDamage.
    _h addEventHandler ["HandleDamage", {
        params ["_u", "", "_dmg", "", "", "_hi"];
        private _old = if (_hi < 0) then { damage _u } else { _u getHitIndex _hi };
        _old + ((_dmg - _old) * 0.5)
    }];
    _hostages pushBack _h;

    private _mk = format ["civ_mission_hostage_%1_%2", _id, _forEachIndex];
    createMarker [_mk, _hpos];
    _mk setMarkerShape "ICON";
    _mk setMarkerType "mil_warning";
    _mk setMarkerColor "ColorBlue";
    _mk setMarkerText localize "STR_DUWS_T_pc_icon_hostage";
    _held pushBack [_h, _grp, _mk];
} forEach _houses;

_e set ["hostages", _hostages];
_e set ["freed", 0];
_e set ["thanks", "STR_DUWS_T_CIVMISSION_HOSTAGES_THANKS"];
// Read from the entry, not captured locals: fnc_civ_mission_request re-runs "won" at the report.
_e set ["cleared", { params ["_e"]; ((_e get "hostages") findIf { alive _x && {!(_x getVariable ["DUWS_hostage_freed", false])} }) < 0 }];
_e set ["won", { params ["_e"]; (_e get "freed") > 0 && {[_e] call (_e get "cleared")} }];
_e set ["lost", { params ["_e"]; (_e get "freed") == 0 && {((_e get "hostages") findIf { alive _x }) < 0} }];

[_id, "STR_DUWS_T_CIVMISSION_HOSTAGES_TITLE", "STR_DUWS_T_CIVMISSION_HOSTAGES_DESC", "help", false, "STR_DUWS_T_CIVMISSION_HOSTAGES_NOTE"] call fnc_civ_mission_present;
// Paid per hostage as each is freed, so the report pays none; the offer and the task still show the most it can pay.
(_e get "reward") set [2, 0];

private _home = getPos ((missionNamespace getVariable ["civ_locations", []]) select _town);
private _hintTgt = [0, -2] select isDedicated;
private _alarmAt = -1;
private _confirmSince = -1;
private _status = "";
waitUntil {
    sleep 1;
    private _keep = [];
    {
        _x params ["_h", "_grp", "_mk"];
        if (alive _h && {({ alive _x } count units _grp) > 0}) then {
            _keep pushBack _x;
        } else {
            deleteMarker _mk;
            if (alive _h) then {
                _h setVariable ["DUWS_hostage_freed", true];
                _e set ["freed", (_e get "freed") + 1];
                [_town, REP_FREED, "civ_hostage_freed"] call fnc_town_rep_adjust;
                // Still captive, so nobody shoots him on the walk home.
                _h enableAI "MOVE";
                _h setUnitPos "AUTO";
                _h doMove _home;
                _h setVariable ["DUWS_binMe", true];
            };
        };
    } forEach _held;
    _held = _keep;

    if (_alarmAt >= 0) then {
        if (_held isEqualTo [] || {time > _alarmAt}) then {
            {
                _x params ["_h", "_grp", "_mk"];
                deleteMarker _mk;
                _h removeAllEventHandlers "HandleDamage";
                _h setCaptive false;
                private _guards = units _grp select { alive _x };
                { _x reveal [_h, 4] } forEach _guards;
                _grp setBehaviour "COMBAT";
                _grp setCombatMode "RED";
                private _range = _guards apply { _x distance _h };
                [_guards select (_range find (selectMin _range)), _h] spawn {
                    params ["_g", "_h"];
                    private _by = time + 12;
                    // Re-issued each tick so group formation cannot pull him off it.
                    waitUntil { sleep 1; _g doMove getPosATL _h; !alive _h || !alive _g || _g distance _h < 4 || time > _by };
                    if (alive _h && { alive _g }) then { _g doTarget _h; _g doFire _h };
                };
                [_h] spawn { params ["_h"]; sleep 20; if (alive _h) then { _h setDamage 1 }; };
            } forEach _held;
            _held = [];
            _alarmAt = -1;
            [""] remoteExec ["hintSilent", _hintTgt];
        } else {
            [format [localize "STR_DUWS_T_CIVMISSION_HOSTAGES_ALARM", ceil (_alarmAt - time)]] remoteExec ["hint", _hintTgt];
        };
    } else {
        if (_held isNotEqualTo []) then {
            private _players = allPlayers select { side _x == west && { alive _x } };
            private _obs = [];
            { _obs append (units _x select { alive _x }) } forEach (_e get "patrols");
            private _confirmed = (_obs findIf {
                private _u = _x;
                ((_u nearTargets DET_RANGE) findIf {
                    (_x select 5) <= DET_FRESH && { (_x select 4) in _players } && { (_u knowsAbout (_x select 4)) > CONFIRM }
                }) >= 0
            }) >= 0;
            if (!_confirmed) then { _confirmSince = -1 } else { if (_confirmSince < 0) then { _confirmSince = time } };
            if (_confirmSince >= 0 && { time - _confirmSince >= CONFIRM_HOLD }) then { _alarmAt = time + CLOCK };
        };
    };

    _status = [_id] call fnc_civ_mission_poll;
    _status != ""
};

if (_alarmAt >= 0) then { [""] remoteExec ["hintSilent", _hintTgt] };
{ deleteMarker (_x select 2) } forEach _held;
{ _x setVariable ["DUWS_binMe", true] } forEach (_hostages select { alive _x });
if (_status == "FAILED" && {[_e] call (_e get "lost")}) then { [_town, REP_ALL_LOST, "civ_hostages_lost"] call fnc_town_rep_adjust };
[_id, _status] call fnc_civ_mission_finish;
