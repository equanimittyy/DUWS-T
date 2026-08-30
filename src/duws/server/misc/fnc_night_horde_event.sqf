// Gated at the call site: only spawned when CIV_PRESENCE is "RAVAGE".

if (!isServer) exitWith {};

private _lastHordeDate = missionNamespace getVariable ["Horde_LastDay", -1];

private _zombieClasses = [
    "zombie_runner"
];

if (!isClass (configFile >> "CfgVehicles" >> "zombie_runner")) then {
    _zombieClasses = [
        "C_Man_casual_1_F"
    ];
    ["ERROR", "MISSION", "Ravage mod not found, using default civilian for horde."] call fnc_log;
};

while {true} do {
    // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
    try {
    waitUntil {
        sleep 60;
        (daytime >= 20 || daytime < 5)
    };

    private _checkInterval = 2; // Test value; restore to 600 for production.

    while {daytime >= 20 || daytime < 5} do {
        private _currentDay = date select 2;

        if (_lastHordeDate != _currentDay) then {
            if (random 1 < 0.1) then {
                _lastHordeDate = _currentDay;
                missionNamespace setVariable ["Horde_LastDay", _lastHordeDate];
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_hordealert1"] remoteExec ["fnc_duws_dialogue", 0];
                sleep 6;
                [localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_hordealert2"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
                sleep 6;

                if ("horde_task" call BIS_fnc_taskExists) then {
                    ["horde_task"] call BIS_fnc_deleteTask;
                };
                private _taskID = "horde_task";
                [
                    west,
                    _taskID,
                    [
                        localize "STR_DUWS_T_HORDE_TASK_DESC",
                        localize "STR_DUWS_T_HORDE_TASK_TITLE",
                        PosOfBLUHQ
                    ],
                    objNull,
                    true,
                    0,
                    true
                ] call BIS_fnc_taskCreate;

                private _hqPos = PosOfBLUHQ;
                private _waveCount = 3;

                for "_wave" from 1 to _waveCount do {
                    private _zombieGroup = createGroup [civilian, true];
                    private _spawnPos = [_hqPos, 130, 150, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;

                    for "_i" from 1 to 40 do {
                        private _unitType = selectRandom _zombieClasses;
                        private _unit = _zombieGroup createUnit [_unitType, _spawnPos, [], 0, "NONE"];
                        _unit setPos ([_spawnPos, 0, 10, 3, 0, 0.2, 0] call BIS_fnc_findSafePos);
                        _unit allowDamage false;
                        _unit setBehaviour "AWARE";
                        _unit setCombatMode "RED";
                        _unit setVariable ["Vcm_Disable", true];
                        _unit setSpeedMode "FULL";
                        sleep 0.2;
                    };

                    while {(count (waypoints _zombieGroup)) > 0} do {
                        deleteWaypoint ((waypoints _zombieGroup) select 0);
                    };
                    private _wp = _zombieGroup addWaypoint [_hqPos, 0];
                    _wp setWaypointType "SAD";
                    _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "AWARE";
                    _wp setWaypointCombatMode "RED";
                    _wp setWaypointCompletionRadius 50;

                    {
                        _x reveal [_x, 4];
                    } forEach units _zombieGroup;

                    [_zombieGroup] spawn {
                        params ["_group"];
                        sleep 5;
                        {
                            _x allowDamage true;
                        } forEach units _group;
                    };

                    if (_wave < _waveCount) then { sleep 40 };
                };

                ["INFO", "MISSION", "Event triggered successfully."] call fnc_log;

                [_taskID] spawn {
                    params ["_taskID"];
                    sleep 60;
                    [_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
                };
            };
        };

        sleep _checkInterval;
        if (daytime >= 5 && daytime < 20) then { break };
    };
    } catch {
        ["ERROR", "HORDE", format ["horde tick threw, thread held alive: %1", _exception]] call fnc_log;
        sleep 10;
    };
};