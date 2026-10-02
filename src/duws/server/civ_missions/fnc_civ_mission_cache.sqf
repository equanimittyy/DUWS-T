// Locality: server, spawned by fnc_civ_mission_request.
#define PAY_WINDOW 1200
#define REP_KEPT -15
#define EXTRA_MIN 3
#define EXTRA_MAX 8
#define CRATE_MAX 20
params ["_id"];
private _e = DUWS_civMissions get _id;
private _site = _e get "site";
private _key = _e get "compKey";
private _cut = _e get "target";
[["duws_mission_destroy_cache"] call fnc_composition_rows, _site, _key, [0, ["Land_HBarrier_5_F", "Land_Razorwire_F"], "all"]] call fnc_composition_place;

private _total = _cut + EXTRA_MIN + floor random (EXTRA_MAX - EXTRA_MIN + 1);
// The first crate takes at least what the second cannot hold.
private _first = (_total - CRATE_MAX) + floor random (2 * CRATE_MAX - _total + 1);
private _crates = [[[0, 0], _first], [[2.23633, -0.296875], _total - _first]] apply {
    _x params ["_off", "_money"];
    private _c = createVehicle ["Box_FIA_Ammo_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    [_c, _key] call fnc_duws_keep;
    _c setPosATL [(_site select 0) + (_off select 0), (_site select 1) + (_off select 1), 0];
    // A stray grenade must not burn the cut.
    _c allowDamage false;
    clearMagazineCargoGlobal _c;
    clearWeaponCargoGlobal _c;
    clearItemCargoGlobal _c;
    clearBackpackCargoGlobal _c;
    _c addMagazineCargoGlobal ["Money_roll", _money];
    _c
};

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
_e set ["patrols", [_site, floor random 3] call fnc_bandit_pairs];
_e set ["payBy", -1];
_e set ["thanks", "STR_DUWS_T_CIVMISSION_CACHE_THANKS"];
(_e get "giver") setVariable ["DUWS_civMission_funds", [0, _cut], true];
// Read from the entry, not captured locals: fnc_civ_mission_request re-runs "won" at the report.
_e set ["cleared", { params ["_e"]; (_e get "payBy") >= 0 }];
_e set ["won", { params ["_e"]; (_e get "raised") >= (_e get "target") }];
_e set ["lost", { params ["_e"]; (_e get "payBy") >= 0 && {time > (_e get "payBy")} }];

[_id, "STR_DUWS_T_CIVMISSION_CACHE_TITLE", "STR_DUWS_T_CIVMISSION_CACHE_DESC", "attack", true, "STR_DUWS_T_CIVMISSION_CACHE_NOTE"] call fnc_civ_mission_present;

private _status = "";
waitUntil {
    sleep 5;
    if ((_e get "payBy") < 0) then {
        private _left = 0;
        { _left = _left + ({ _x == "Money_roll" } count magazineCargo _x) } forEach _crates;
        if (_left < _cut) then { _e set ["payBy", time + PAY_WINDOW] };
    };
    _status = [_id] call fnc_civ_mission_poll;
    _status != ""
};
if ((_e get "payBy") >= 0 && {_status != "SUCCEEDED"}) then { [_e get "town", REP_KEPT, "civ_cache_kept"] call fnc_town_rep_adjust };
[_id, _status] call fnc_civ_mission_finish;
