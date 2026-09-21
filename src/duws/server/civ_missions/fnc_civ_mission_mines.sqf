// Locality: server, spawned by fnc_civ_mission_request. An old OPFOR field thinned to the few mines it still
// holds, registered as a revealed standalone hardpoint so its mines show on the map and its row clears on the
// hardpoint poller's own test. It outlives a failed or canceled job: the field is OPFOR's, not the giver's.
#define MINES_LEFT_MIN 0.10
#define MINES_LEFT_MAX 0.17
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
private _townPos = getPos ((missionNamespace getVariable ["civ_locations", []]) select (_e get "town"));
private _ring = 100 + selectMax (_mines apply { _x distance2D _site });
private _patrols = [];
{
    // random [min, mid, max] peaks at mid, so most groups start on the field's far side from town.
    private _at = [_site getPos [_ring, (_townPos getDir _site) + random [-180, 0, 180]], 25, 0, 5, 0.5, []] call fnc_safe_pos;
    if (_at isEqualTo []) then { continue };
    _patrols pushBack ([_x, _site, _ring, "widepatrol", _at] call fnc_spawn_team);
} forEach ((["team"] select [0, floor random 2]) + (["patrol", "patrol"] select [0, floor random 3]));
_e set ["patrols", _patrols];
_e set ["thanks", "STR_DUWS_T_CIVMISSION_MINES_THANKS"];
// Read from the entry, not a captured local: fnc_civ_mission_request re-runs it at the report.
_e set ["won", { params ["_e"]; ((_e get "mines") findIf { !isNull _x && {mineActive _x} }) < 0 }];
_e set ["lost", { false }];
_e set ["cleared", _e get "won"];

[_id, "STR_DUWS_T_CIVMISSION_MINES_TITLE", ["STR_DUWS_T_CIVMISSION_MINES_AT_DESC", "STR_DUWS_T_CIVMISSION_MINES_AP_DESC"] select (_variant == "AP"), "mine", false] call fnc_civ_mission_present;

private _status = "";
waitUntil { sleep 5; _status = [_id] call fnc_civ_mission_poll; _status != "" };
[_id, _status] call fnc_civ_mission_finish;
