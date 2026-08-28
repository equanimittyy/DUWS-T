// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];

    // The objective itself: kept for the mission's duration so the abandoned-vehicle clause cannot
    // collect it. A player who disables it and takes half an hour would otherwise find the thing they
    // were sent for gone, with no way left to finish.
    private _truck1 = opfor_TRANS_TRUCK_X createVehicle _targetpos;
    [_truck1, "mission_steal_supply"] call fnc_duws_keep;
    clearMagazineCargoGlobal _truck1;
    clearWeaponCargoGlobal _truck1;
    clearItemCargoGlobal _truck1;
    clearBackpackCargoGlobal _truck1;

    private _box1 = "";
    private _box2 = "";
    switch (VERSION_X) do {
        case "MODERN": {
            _box1 = "O_supplyCrate_F" createVehicle _targetpos;
            _box2 = "O_supplyCrate_F" createVehicle _targetpos;
            { [_x, "mission_steal_supply"] call fnc_duws_keep; } forEach [_box1, _box2];
            _box1 attachTo [_truck1, [0, -0.5, 0]];
            _box1 setDir 90;
            _box2 attachTo [_truck1, [0, -2.2, 0]];
            _box2 setDir 75;
            { clearMagazineCargoGlobal _x; clearWeaponCargoGlobal _x; clearItemCargoGlobal _x; clearBackpackCargoGlobal _x; } forEach [_box1, _box2];
        };
    };

    // Clutter the truck cluster south of the objective so it reads as a parked supply point.
    [[(_targetpos select 0), (_targetpos select 1) - 10], "mission_steal_supply"] call fnc_mission_dressing;

    // Guard force: idle team on the prize, a close and two wide foot patrols, plus vehicle patrols that
    // scale with the enemy's earned AP -- DUWS_fnc_tokenClass returns "" for a token gated out at the
    // current tier, so a car joins from motorised (60 AP) and a second car-or-ifv from mechanised (150 AP).
    private _claim = { [_this] call fnc_mission_claim };
    (["team", _targetpos, _radius, "none", _targetpos] call fnc_spawn_team) call _claim;   // idle, on the objective
    (["team", _targetpos, _radius, "closepatrol"] call fnc_spawn_team) call _claim;
    for "_i" from 1 to 2 do { (["patrol", _targetpos, _radius, "widepatrol"] call fnc_spawn_team) call _claim; };
    private _car = ["car"] call DUWS_fnc_tokenClass;
    if (_car != "") then { ([_car, _targetpos, _radius, "widepatrol"] call fnc_spawn_vehicle) call _claim; };
    if ((["ifv"] call DUWS_fnc_tokenClass) != "") then {
        private _cls = [selectRandom ["car", "ifv"]] call DUWS_fnc_tokenClass;
        if (_cls != "") then { ([_cls, _targetpos, _radius, "widepatrol"] call fnc_spawn_vehicle) call _claim; };
    };

    [_truck1, _box1, _box2]
};

// On win: drop the two decorative crates a beat apart (they rode the truck as visible cargo), then bank
// the enemy stores as a limited arsenal into the captured pool.
private _onWin = {
    params ["_truck1", "_box1", "_box2"];
    sleep 2;
    deleteVehicle _box2;
    sleep 2;
    deleteVehicle _box1;
    ["opfor", [3, 2, 2, 2, 2], [localize "STR_DUWS_T_SUPPLY_ARSENAL_TITLE", localize "STR_DUWS_T_arsenalfound2"]] call fnc_arsenal_reward;
};

// Win: the recovered truck reaches BLUFOR HQ intact. Early-lose: the truck is destroyed (the _done
// test requires it alive, so win and loss stay mutually exclusive).
private _done = { alive (_this select 0) && ((_this select 0) distance PosOfBLUHQ) < 100 };
private _lost = [[{ !alive (_this select 0) }, ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_supplytruckfail"]]];

if (!([1, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

private _radius = 600;
private _site = [_MissionPos, _radius, 1] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["rescue%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_p7qawzl4", _mission_name, "getin",
    [["STR_DUWS_T_ALLSEER", "STR_DUWS_T_supplytruckletsdothis", 3], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_supplytruckoverlord", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_supplytruckcopy", 0]]
] call fnc_mission_present;

private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

sleep 5; // let the guard force finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || (_lost findIf { _handles call (_x select 0) } >= 0) || time > _deadline };

// Loss ranked ahead of the timeout so a truck destroyed as the clock runs out reads as destroyed.
private _lostIdx = _lost findIf { _handles call (_x select 0) };
if (!(_handles call _done) && _lostIdx >= 0) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], (_lost select _lostIdx) select 1, false, "mission_steal_supply", false, false] call fnc_mission_finish;
};

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_steal_supply"] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_supplytruckwin"], true, "mission_steal_supply", false, false, _onWin, _handles] call fnc_mission_finish;
