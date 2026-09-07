// Carry system for the rescue-pilot mission: carry a downed unit on the player's back, drop him, stow him in
// a vehicle and take him back out. Loaded by fnc_rescue_pilot_mission, which broadcasts it to every machine
// because the addAction bodies run on the carrier's own client, not the server. Kept out of the generic
// DUWS_fnc_unitCarry (fnc_unit_carry.sqf): it reads the mission's currentMissionPilot, so it is not reusable.

DUWS_fnc_autoDropPilot = {
    params ["_caller", "_pilot"];
    if (isNull _caller || isNull _pilot) exitWith {};

    private _dropAction = _caller getVariable ["dropAction", -1];
    if (_dropAction != -1) then { _caller removeAction _dropAction; };
    private _putAction = _caller getVariable ["putInVehicleAction", -1];
    if (_putAction != -1) then { _caller removeAction _putAction; };
    
    detach _pilot;
    _pilot setPos (_caller getPos [1.5, getDir _caller + 180]);
    [_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
    _pilot enableAI "ALL";
    _pilot disableAI "PATH";
    _pilot setVariable ["isCarried", false, true];
    _pilot setVariable ["carrier", nil, true];
    _caller setVariable ["carriedPilot", nil, true];
    _caller setVariable ["dropAction", nil];
    _caller setVariable ["putInVehicleAction", nil];

    [_pilot] remoteExec ["DUWS_fnc_removeCarryAction", 0];
    [_pilot] spawn {
        params ["_pilot"];
        sleep 0.5;
        [_pilot] remoteExec ["DUWS_fnc_addCarryAction", 0];
    };
};

DUWS_fnc_dropPilot = {
    params ["_caller", "_pilot"];
    private _dropAction = _caller getVariable ["dropAction", -1];
    if (_dropAction != -1) then { _caller removeAction _dropAction; };
    private _putAction = _caller getVariable ["putInVehicleAction", -1];
    if (_putAction != -1) then { _caller removeAction _putAction; };
    _speaker = localize "STR_DUWS_T_actionteam";
    _message = localize "STR_DUWS_T_stayhere";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    
    [_caller, "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon"] remoteExec ["switchMove", 0];
    sleep 1.5;
    detach _pilot;
    _pilot setPos (_caller modelToWorld [0, 2, 0]);
    [_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
    _pilot enableAI "ALL";
    _pilot disableAI "PATH";
    _pilot setVariable ["isCarried", false, true];
    _pilot setVariable ["carrier", nil, true];
    [_caller, ""] remoteExec ["switchMove", 0];
    _caller setVariable ["carriedPilot", nil, true];
    _caller setVariable ["dropAction", nil];
    _caller setVariable ["putInVehicleAction", nil];
    
    [_pilot] remoteExec ["DUWS_fnc_removeCarryAction", 0];
    [_pilot] spawn {
        params ["_pilot"];
        sleep 0.5;
        [_pilot] remoteExec ["DUWS_fnc_addCarryAction", 0];
    };
};

DUWS_fnc_putInVehicle = {
    params ["_caller", "_pilot"];
    private _vehicle = cursorTarget;
    if (isNull _vehicle || !(_vehicle isKindOf "AllVehicles") || _vehicle == _caller) then {
        private _nearVehicles = nearestObjects [_caller, ["Car","Tank","Helicopter","Ship"], 5];
        _vehicle = if (count _nearVehicles > 0) then { _nearVehicles select 0 } else { objNull };
    };
    if (isNull _vehicle) exitWith { hint localize "STR_DUWS_T_no_vehicle_near"; };

    [_caller, _pilot, _vehicle] remoteExec ["DUWS_fnc_serverPutInVehicle", 2];
};

DUWS_fnc_takeOutFromVehicle = {
    params ["_caller", "_pilot"];
    private _vehicle = _pilot getVariable ["inVehicle", objNull];
    if (isNull _vehicle) exitWith {};

    [_caller, _pilot, _vehicle] remoteExec ["DUWS_fnc_serverTakeOutFromVehicle", 2];
};

DUWS_fnc_serverPutInVehicle = {
    params ["_caller", "_pilot", "_vehicle"];
    if (isNull _vehicle || isNull _pilot || isNull _caller) exitWith {};

    if (_pilot getVariable ["carrier", objNull] != _caller) exitWith {
        [_caller, localize "STR_DUWS_T_cant_put_not_carried"] remoteExec ["hint", _caller];
    };
    if (vehicle _pilot != _pilot) exitWith {
        [_caller, localize "STR_DUWS_T_pilot_already_in_vehicle"] remoteExec ["hint", _caller];
    };

    // Pick a seat first, cargo before commander before gunner, before touching the pilot.
    private _seatType = "";
    if (_vehicle emptyPositions "cargo" > 0) then { _seatType = "cargo"; }
    else {
        if (_vehicle emptyPositions "commander" > 0) then { _seatType = "commander"; }
        else { if (_vehicle emptyPositions "gunner" > 0) then { _seatType = "gunner"; }; };
    };
    if (_seatType == "") exitWith {
        [_caller, localize "STR_DUWS_T_no_available_seat"] remoteExec ["hint", _caller];
    };

    // Detach from the carrier BEFORE seating. moveInCargo on a unit still attachTo the player leaves the
    // attachment pinning him to the player's back rather than the seat -- the "loaded but still carried"
    // bug. Carry state is cleared here so a failed grab below can restore it cleanly.
    detach _pilot;
    _pilot setVariable ["isCarried", false, true];
    _pilot setVariable ["carrier", nil, true];

    switch (_seatType) do {
        case "cargo": { _pilot moveInCargo _vehicle; };
        case "commander": { _pilot moveInCommander _vehicle; };
        case "gunner": { _pilot moveInGunner _vehicle; };
    };
    sleep 0.5;
    if (vehicle _pilot != _vehicle) then {
        switch (_seatType) do {
            case "cargo": { _pilot moveInCargo _vehicle; };
            case "commander": { _pilot moveInCommander _vehicle; };
            case "gunner": { _pilot moveInGunner _vehicle; };
        };
        sleep 0.5;
    };

    if (vehicle _pilot != _vehicle) exitWith {
        // Grab failed after the detach; put him back on the carrier's back so he is not left stranded.
        _pilot attachTo [_caller, [0.17, 0.1, 0.11]];
        [_pilot, -180] remoteExec ["setDir", 0];
        _pilot setVariable ["isCarried", true, true];
        _pilot setVariable ["carrier", _caller, true];
        [_caller, localize "STR_DUWS_T_failed_put_vehicle"] remoteExec ["hint", _caller];
    };

    _pilot setVariable ["inVehicle", _vehicle, true];
    _pilot disableAI "ALL";
    _speaker = localize "STR_DUWS_T_actionteam";
    _message = localize "STR_DUWS_T_pilotinveh";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

    [_caller] remoteExec ["DUWS_fnc_clearCarrierActions", _caller];
    [_vehicle] remoteExec ["DUWS_fnc_addVehicleTakeOutAction", 0];
};

DUWS_fnc_serverTakeOutFromVehicle = {
    params ["_caller", "_pilot", "_vehicle"];
    if (isNull _vehicle || isNull _pilot || isNull _caller) exitWith {};

    if (vehicle _pilot != _vehicle) exitWith {
        [_caller, localize "STR_DUWS_T_pilot_not_in_vehicle"] remoteExec ["hint", _caller];
    };
    if (!isNull (_caller getVariable ["carriedPilot", objNull])) exitWith {
        [_caller, localize "STR_DUWS_T_already_carrying_other"] remoteExec ["hint", _caller];
    };

    _pilot setVariable ["inVehicle", nil, true];

    moveOut _pilot;

    private _timeout = time + 0.5;
    waitUntil { vehicle _pilot == _pilot || time > _timeout };

    if (vehicle _pilot != _pilot) then {
        _pilot setPos (_caller modelToWorld [0, 1.5, 0]);
    };

    [_caller, "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon"] remoteExec ["switchMove", 0];
    sleep 2;
    if (!alive _pilot) exitWith {
        [_caller, ""] remoteExec ["switchMove", 0];
    };
    [_caller, "AcinPercMstpSrasWrflDnon"] remoteExec ["switchMove", 0];
    _speaker = localize "STR_DUWS_T_actionteam";
    _message = localize "STR_DUWS_T_comeonout";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

    _pilot attachTo [_caller, [0.17,0.1,0.11]];
    [_pilot, -180] remoteExec ["setDir", 0];
    [_pilot, "AinjPfalMstpSnonWnonDf_carried_dead"] remoteExec ["switchMove", 0];
    _pilot disableAI "ALL";

    _pilot setVariable ["isCarried", true, true];
    _pilot setVariable ["carrier", _caller, true];
    _pilot setVariable ["inVehicle", nil, true];
    _caller setVariable ["carriedPilot", _pilot, true];

    [_pilot] remoteExec ["DUWS_fnc_removeCarryAction", 0];
    [_caller, _pilot] remoteExec ["DUWS_fnc_addCarrierActions", _caller];

    if (!isNull _vehicle) then {
        [_vehicle] remoteExec ["DUWS_fnc_removeVehicleTakeOutAction", 0];
    };
};

DUWS_fnc_addCarrierActions = {
    params ["_caller", "_pilot"];
    if (!alive _caller || !alive _pilot) exitWith {};
    
    private _oldDrop = _caller getVariable ["dropAction", -1];
    if (_oldDrop != -1) then { _caller removeAction _oldDrop; };
    private _oldPut = _caller getVariable ["putInVehicleAction", -1];
    if (_oldPut != -1) then { _caller removeAction _oldPut; };
    private _oldHandle = _caller getVariable ["carryAutoDropHandle", scriptNull];
    if (!isNull _oldHandle) then { terminate _oldHandle; };
    
    private _autoDropHandle = [_caller, _pilot] spawn {
        params ["_caller", "_pilot"];
        while {!isNull _caller && alive _caller && !isNull (_caller getVariable ["carriedPilot", objNull])} do {
            if (vehicle _caller != _caller) then {
                [_caller, _pilot] call DUWS_fnc_autoDropPilot;
                hint localize "STR_DUWS_T_auto_drop_hint";
            };
            // Sampled here, not in the load action's condition: an action condition runs every
            // frame in range, so a spatial search there would run at frame rate through the whole
            // carry. This thread already lives that long and answers twice a second. Local, like
            // the condition that reads it.
            _caller setVariable ["DUWS_carryVehicleNear",
                count (_caller nearEntities [["Car","Tank","Helicopter","Ship"], 5]) > 0];
            sleep 0.5;
        };
    };
    _caller setVariable ["carryAutoDropHandle", _autoDropHandle];
    
    private _dropAction = _caller addAction [
        localize "STR_DUWS_T_drop_pilot",
        {
            params ["_target", "_caller", "_actionId"];
            private _pilot = _target getVariable ["carriedPilot", objNull];
            if (isNull _pilot) exitWith {};
            [_caller, _pilot] call DUWS_fnc_dropPilot;
        },
        [],
        40, true, true, "", "player == _target", 5
    ];
    _caller setVariable ["dropAction", _dropAction];
    
    private _putInVehicleAction = _caller addAction [
        localize "STR_DUWS_T_put_in_vehicle",
        {
            params ["_target", "_caller", "_actionId"];
            private _pilot = _target getVariable ["carriedPilot", objNull];
            if (isNull _pilot) exitWith {};
            [_caller, _pilot] call DUWS_fnc_putInVehicle;
        },
        [],
        40, true, true, "",
        "player == _target && !isNull (_target getVariable ['carriedPilot', objNull]) && {alive (_target getVariable ['carriedPilot', objNull])} && {_target getVariable ['DUWS_carryVehicleNear', false]}",
        5
    ];
    _caller setVariable ["putInVehicleAction", _putInVehicleAction];
};

DUWS_fnc_clearCarrierActions = {
    params ["_caller"];
    private _dropAction = _caller getVariable ["dropAction", -1];
    if (_dropAction != -1) then { _caller removeAction _dropAction; };
    private _putAction = _caller getVariable ["putInVehicleAction", -1];
    if (_putAction != -1) then { _caller removeAction _putAction; };
    
    private _autoDropHandle = _caller getVariable ["carryAutoDropHandle", scriptNull];
    if (!isNull _autoDropHandle) then { terminate _autoDropHandle; };
    _caller setVariable ["carryAutoDropHandle", nil];
    // Dropped with the thread that maintains it, or the next carry would open on
    // whatever the last one left behind until the new watcher's first pass.
    _caller setVariable ["DUWS_carryVehicleNear", nil];

    _caller setVariable ["carriedPilot", nil, true];
    [_caller, ""] remoteExec ["switchMove", 0];
    _caller setVariable ["dropAction", nil];
    _caller setVariable ["putInVehicleAction", nil];
};

DUWS_fnc_addCarryAction = {
    params ["_pilot"];
    if (!alive _pilot) exitWith {};
    if (_pilot getVariable ["isCarried", false]) exitWith {};

    // Stable per-pilot JIP id: a re-add (one per drop/pickup) overwrites this one slot instead of stacking a
    // fresh persistent order, and removeCarryAction clears it by the same id. JIP=true here grew the queue per re-add.
    private _jipId = format ["DUWS_carryAct_%1", netId _pilot];
    [_pilot, {
        params ["_pilot"];
        if (!isNil {_pilot getVariable "carryActionAdded"}) exitWith {};
        _pilot setVariable ["carryActionAdded", true];
        private _actionID = _pilot addAction [
            localize "STR_DUWS_T_carry_pilot",
            {
                params ["_target", "_caller", "_actionId"];
                if (_target getVariable ["isCarried", false]) exitWith {};
                if (!alive _target) exitWith {};
                _speaker = localize "STR_DUWS_T_actionteam";
                _message = localize "STR_DUWS_T_i_got_u";
                [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
                
                [_caller, "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon"] remoteExec ["switchMove", 0];
                
                // remove the carry action now: blocks a second trigger mid-animation
                [_target] remoteExec ["DUWS_fnc_removeCarryAction", 0];
                
                sleep 2;
                if (!alive _target || _target getVariable ["isCarried", false]) exitWith {
                    [_caller, ""] remoteExec ["switchMove", 0];
                };
                [_caller, "AcinPercMstpSrasWrflDnon"] remoteExec ["switchMove", 0];
                
                _target setVariable ["isCarried", true, true];
                _target setVariable ["carrier", _caller, true];
                _target attachTo [_caller, [0.17,0.1,0.11]];
                [_target, -180] remoteExec ["setDir", 0];
                [_target, "AinjPfalMstpSnonWnonDf_carried_dead"] remoteExec ["switchMove", 0];
                _target disableAI "ALL";

                [_caller, _target] remoteExec ["DUWS_fnc_addCarrierActions", _caller];
                
                _caller setVariable ["carriedPilot", _target, true];
            },
            [],
            40, true, true, "",
            "!isNull _target && {!(_target getVariable ['isCarried', false])} && {alive _target} && {(_this distance _target) < 2.5}",
            5
        ];
        _pilot setVariable ["carryActionID", _actionID];
    }] remoteExec ["call", 0, _jipId];
};

DUWS_fnc_removeCarryAction = {
    params ["_pilot"];
    if (isNull _pilot) exitWith {};
    // Clear the JIP order with the action, or it outlives the pilot and a late joiner re-adds a carry action on
    // a resolved mission. Server owns the queue -- clear once there.
    if (isServer) then { remoteExec ["", format ["DUWS_carryAct_%1", netId _pilot]] };
    private _carryActionID = _pilot getVariable ["carryActionID", -1];
    if (_carryActionID != -1) then {
        _pilot removeAction _carryActionID;
        _pilot setVariable ["carryActionID", nil];
    };
    _pilot setVariable ["carryActionAdded", nil];
};

DUWS_fnc_addVehicleTakeOutAction = {
    params ["_vehicle"];
    if (isNull _vehicle) exitWith {};
    if (!isNil {_vehicle getVariable "takeOutActionAdded"}) exitWith {};
    _vehicle setVariable ["takeOutActionAdded", true];
    private _actionID = _vehicle addAction [
        localize "STR_DUWS_T_take_out_pilot",
        {
            params ["_target", "_caller", "_actionId"];
            private _pilot = missionNamespace getVariable ["currentMissionPilot", objNull];
            if (isNull _pilot) exitWith {};
            if (!alive _pilot) exitWith { hint localize "STR_DUWS_T_pilot_dead"; };
            if (_pilot getVariable ["inVehicle", objNull] != _target) exitWith {};
            if (!isNull (_caller getVariable ["carriedPilot", objNull])) exitWith { hint localize "STR_DUWS_T_already_carrying_other"; };
            [_caller, _pilot] call DUWS_fnc_takeOutFromVehicle;
        },
        [],
        40, true, true, "", "vehicle _this == _this", 5
    ];
    _vehicle setVariable ["takeOutActionID", _actionID];
};

DUWS_fnc_removeVehicleTakeOutAction = {
    params ["_vehicle"];
    if (isNull _vehicle) exitWith {};
    private _takeActionID = _vehicle getVariable ["takeOutActionID", -1];
    if (_takeActionID != -1) then {
        _vehicle removeAction _takeActionID;
        _vehicle setVariable ["takeOutActionID", nil];
    };
    _vehicle setVariable ["takeOutActionAdded", nil];
};

DUWS_fnc_cleanupPilotActions = {
    params ["_pilot"];
    if (isNull _pilot) exitWith {};
    private _carrier = _pilot getVariable ["carrier", objNull];
    if (!isNull _carrier) then {
        [_carrier] call DUWS_fnc_clearCarrierActions;
    };
    private _vehicle = _pilot getVariable ["inVehicle", objNull];
    if (!isNull _vehicle) then {
        [_vehicle] call DUWS_fnc_removeVehicleTakeOutAction;
    };
    [_pilot] call DUWS_fnc_removeCarryAction;
    _pilot setVariable ["isCarried", false, true];
    _pilot setVariable ["carrier", nil, true];
    _pilot setVariable ["inVehicle", nil, true];
};
