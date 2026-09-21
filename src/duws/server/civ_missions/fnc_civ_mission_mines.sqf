// Locality: server, spawned by fnc_civ_mission_request. An old OPFOR field thinned to the few mines it still
// holds, registered as a revealed standalone hardpoint so its mines show on the map and its row clears on the
// hardpoint poller's own test. It outlives a failed or canceled job: the field is OPFOR's, not the giver's.
#define MINES_LEFT_MIN 0.15
#define MINES_LEFT_MAX 0.22
params ["_id"];
private _e = DUWS_civMissions get _id;
private _site = _e get "site";

private _variant = selectRandom ["AP", "AT"];
private _dir = random 360;
private _key = format ["hpcivmine_%1", _id];
private _mines = [];
{
    if (!surfaceIsWater _x) then { _mines append ([_x, _dir, _variant, _key] call fnc_hardpoint_minefield) };
} forEach ([_site, _dir, 1 + floor random 2, 1 + floor random 2] call fnc_hardpoint_minefield_grid);
if (_mines isEqualTo []) exitWith {
    ["WARN", "CIV", format ["civilian mission %1: no mines laid", _id]] call fnc_log;
    [_id, "FAILED"] call fnc_civ_mission_finish;
};

private _laid = count _mines;
private _left = 1 max round (_laid * (MINES_LEFT_MIN + random (MINES_LEFT_MAX - MINES_LEFT_MIN)));
_mines = _mines call BIS_fnc_arrayShuffle;
{ deleteVehicle _x } forEach (_mines select [_left]);
_mines resize _left;
// Survivors only: the list rides the JIP reveal to every client.
missionNamespace setVariable [format ["DUWS_hpMines_%1", _key], _mines];
[_key, "MINEFIELD", _site, "opfor", "", _dir] call fnc_hardpoint_register;
["ONE", _key, true] call fnc_hardpoint_reveal;
["INFO", "CIV", format ["civilian mission %1: %2 field %3 keeps %4 of %5 mines", _id, _variant, _key, _left, _laid]] call fnc_log;

_e set ["mines", _mines];
// Measured now: a cleared mine reads null, and a null's distance is not the field's.
private _ring = 200 + selectMax (_mines apply { _x distance2D _site });
_e set ["thanks", "STR_DUWS_T_CIVMISSION_MINES_THANKS"];
// Read from the entry, not a captured local: fnc_civ_mission_request re-runs it at the report.
_e set ["won", { params ["_e"]; ((_e get "mines") findIf { !isNull _x && {mineActive _x} }) < 0 }];
_e set ["lost", { false }];
_e set ["cleared", _e get "won"];

[_id, "STR_DUWS_T_CIVMISSION_MINES_TITLE", ["STR_DUWS_T_CIVMISSION_MINES_AT_DESC", "STR_DUWS_T_CIVMISSION_MINES_AP_DESC"] select (_variant == "AP"), "mine", false] call fnc_civ_mission_present;

private _status = "";
waitUntil { sleep 5; _status = [_id] call fnc_civ_mission_poll; _status != "" || {(_mines findIf { isNull _x || {!mineActive _x} }) >= 0} };
if (_status == "") then {
    private _near = (call BIS_fnc_listPlayers) select { alive _x && {(_x distance2D _site) < 600} };
    private _from = getPos ((missionNamespace getVariable ["civ_locations", []]) select (_e get "town"));
    if (_near isNotEqualTo []) then {
        _from = [0, 0, 0];
        { _from = _from vectorAdd (getPosATL _x) } forEach _near;
        _from = _from vectorMultiply (1 / count _near);
    };
    private _away = _from getDir _site;
    // Each side on its own flank of the far side, so both close on the field and meet there.
    private _swing = selectRandom [45, -45];
    // Prefer hidden, accept the fewest eyes: open ground rarely hides a spawn this close.
    private _fnc_spot = {
        params ["_dist", "_bearing"];
        private _best = [];
        private _bestSeen = 1e9;
        {
            private _p = _site getPos [_dist, _bearing + _x];
            if (surfaceIsWater _p) then { continue };
            private _seen = { [_p, _x] call DUWS_fnc_posSeenBy } count _near;
            if (_seen < _bestSeen) then { _bestSeen = _seen; _best = _p };
            if (_seen == 0) exitWith {};
        } forEach [0, 20, -20, 40, -40];
        _best
    };
    private _roll = { params ["_team", "_patrol"]; ([_team] select [0, floor random 2]) + ([_patrol, _patrol] select [0, floor random 3]) };

    private _groups = [];
    private _at = [_ring, _away + _swing] call _fnc_spot;
    if (_at isNotEqualTo []) then {
        {
            _groups pushBack ([_x, _site, _ring, "hunt", [_at, 15, 0, 3, 0.5] call fnc_safe_pos] call fnc_spawn_team);
        } forEach (["team", "patrol"] call _roll);
    };
    private _opfor = count _groups;
    _at = [_ring + 100, _away - _swing] call _fnc_spot;
    if (_at isNotEqualTo []) then {
        // The OPFOR team and patrol rosters, man for man in bandit roles.
        {
            private _grp = [[_at, 15, 0, 3, 0.5] call fnc_safe_pos, _x] call fnc_bandit_spawn;
            [_grp, "hunt", _site, _ring] call fnc_apply_posture;
            _groups pushBack _grp;
        } forEach ([["rifleman", "autogunner", "grenadier", "rifleman", "at", "medic"], ["rifleman", "autogunner"]] call _roll);
    };
    _e set ["patrols", _groups];
    ["INFO", "CIV", format ["civilian mission %1: first mine gone, %2 OPFOR and %3 bandit groups move on the field", _id, _opfor, count _groups - _opfor]] call fnc_log;

    waitUntil { sleep 5; _status = [_id] call fnc_civ_mission_poll; _status != "" };
};
[_id, _status] call fnc_civ_mission_finish;
