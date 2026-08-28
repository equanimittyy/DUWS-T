// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([13, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_searchRadius   = 250;
_spawnDist      = 230;
_timeLimit      = 360;
_cpReward       = DUWS_curReward select 0;
_apReward       = DUWS_curReward select 1;
_repReward      = DUWS_curReward select 2;
_deadline       = DUWS_curDeadlineAt;

_speaker        = localize "STR_DUWS_T_OVERLORD";
_speakerinfomat = localize "STR_DUWS_T_infomat";
_speakeracteam  = localize "STR_DUWS_T_actionteam";
_message        = localize "STR_DUWS_T_pcletsdothis";
_messagewhoau   = localize "STR_DUWS_T_pcwhoau";
_messageiminfo  = localize "STR_DUWS_T_pciminfo";
_messageoverlord= ([localize "STR_DUWS_T_pcoverlord"] call fnc_cs);
_messageroger   = ([localize "STR_DUWS_T_pcroger"] call fnc_cs);
_message1       = localize "STR_DUWS_T_pcbequick";
_message2       = ([localize "STR_DUWS_T_pcend"] call fnc_cs);
_message3       = ([localize "STR_DUWS_T_pcfail"] call fnc_cs);


private _site = [_MissionPos, _searchRadius, 13] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Abort here rather than fall through: a null building would otherwise build the civilian, markers and
// triggers on nothing. exitWith leaves the thread because if/then is transparent to it and nothing above
// the body is a loop.
if (isNull _Building) exitWith {
    [13, "STR_DUWS_T_mission_no_building"] call fnc_mission_abort;
};

_buildingPositions = [_Building] call BIS_fnc_buildingPositions;
if (count _buildingPositions < 4) then {
    private _nearbyBuildings = nearestObjects [_MissionPos, ["House"], _searchRadius];
    private _found = false;
    {
        private _bpos = [_x] call BIS_fnc_buildingPositions;
        if (count _bpos >= 4) then {
            _Building = _x;
            _targetpos = getPosATL _Building;
            _buildingPositions = _bpos;
            _found = true;
            break;
        };
    } forEach _nearbyBuildings;
    if (!_found) exitWith {
        [13, "STR_DUWS_T_mission_no_building_4pos"] call fnc_mission_abort;
    };
};

// Marker + task via fnc_mission_present, sited on _targetpos rather than _randomPos because that is
// what the start trigger and the end sweep below both use, so all three describe one area. Drawn only
// once the 4-position rebuild above has settled which building it is; the brief below stays manual
// (multi-speaker sequence, callsign substitution already applied per line above).
private _VARtaskgeneratedName = format ["protectciv_%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
_markername2 = [_targetpos, _searchRadius, _VARtaskgeneratedName, localize "STR_DUWS_T_protectciv", _mission_name, "defend"] call fnc_mission_present;

_civilianClass = "C_Man_Fisherman_01_F";
_civGroup = [[0,0], WEST, [_civilianClass]] call BIS_fnc_spawnGroup;
_civilian = leader _civGroup;
_civilian allowDamage true;
_civilian setCaptive false;
_civilian setDamage 0.8;

if (count _buildingPositions > 0) then {
    _randIndex = floor random count _buildingPositions;
    _civilian setPosATL (_buildingPositions select _randIndex);
} else {
    _civilian setPosATL (getPosATL _Building);
};

_civilian disableAI "PATH";
_civilian setBehaviour "CARELESS";
_civilian setCombatMode "BLUE";

_civilianMarker = format ["civ_marker_%1", round(time + random 1000)];
createMarker [_civilianMarker, getPosATL _civilian];
_civilianMarker setMarkerShape "ICON";
_civilianMarker setMarkerType "o_unknown";
_civilianMarker setMarkerColor "ColorBlue";
_civilianMarker setMarkerText "Informant";
_civilianMarker setMarkerSize [1, 1];

[_civilian] spawn {
    params ["_unit"];
    sleep 1;
    // playMoveNow is local, so broadcast it or the informant animates only on the host's screen.
    // Unkeyed on purpose -- it reissues every 5 s, so a joiner picks it up on the next pass.
    while {alive _unit} do {
        [_unit, "ApanPpneMstpSnonWnonDnon_G02"] remoteExec ["playMoveNow", 0];
        sleep 5;
    };
};

_civGroup deleteGroupWhenEmpty true;
// The one WEST unit here needs an explicit owner so teardown flags it. Claim sets ownership only --
// DUWS_binMe is stamped later at cleanup -- so this cannot delete him mid-escort.
[_civGroup] call fnc_mission_claim;

[_speakerinfomat, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker, _messagewhoau] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakerinfomat, _messageiminfo] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker, _messageoverlord] remoteExec ["fnc_duws_dialogue", 0];
sleep 3;

sleep 5;
[_speakeracteam, _messageroger] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakerinfomat, _message1] remoteExec ["fnc_duws_dialogue", 0];

_startTrigger = createTrigger ["EmptyDetector", _targetpos];
_startTrigger setTriggerArea [_searchRadius, _searchRadius, 0, false];
_startTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", false];
_startTrigger setTriggerStatements ["this", "", ""]; // empty statements: the wait runs in the thread below

missionNamespace setVariable [format ["%1_started", _VARtaskgeneratedName], false];
publicVariable format ["%1_started", _VARtaskgeneratedName];

[_startTrigger, _VARtaskgeneratedName] spawn {
    params ["_trg", "_taskName"];
    waitUntil { sleep 1; triggerActivated _trg };
    missionNamespace setVariable [format ["%1_startTime", _taskName], time];
    missionNamespace setVariable [format ["%1_started", _taskName], true];
    [localize "STR_DUWS_T_infomat", localize "STR_DUWS_T_pcbehindme"] remoteExec ["fnc_duws_dialogue", 0];
    deleteVehicle _trg;
};


[_civilian, _VARtaskgeneratedName, _civilianMarker, _timeLimit, _cpReward, _apReward, _repReward, _targetpos, _searchRadius, _markername2, _deadline] spawn {
    params ["_civ", "_taskID", "_civMarker", "_timeLimit", "_cp", "_ap", "_rep", "_targetPos", "_radius", "_areaMarker", "_deadline"];

    // The escort only starts once a player reaches the informant. The deadline covers the abandon
    // case: an offer never engaged fails and frees the slot rather than waiting on the trigger forever.
    waitUntil { sleep 1; (missionNamespace getVariable [format ["%1_started", _taskID], false]) || time > _deadline };
    if (time > _deadline && !(missionNamespace getVariable [format ["%1_started", _taskID], false])) exitWith {
        // The informant marker is a raw createMarker (unwrapped name), so it is cleared by hand; only
        // the missionMarkerData ellipse routes through finish.
        if (!isNil "_civMarker" && {_civMarker != ""}) then { deleteMarker _civMarker; };
        // TODO: give this mission a bespoke Overlord timeout-fail line instead of the generic notice.
        ["Protect Civilian", _taskID, "FAILED", _targetPos, _radius, [_areaMarker], [], false, "", true, true] call fnc_mission_finish;
    };
    private _missionStartTime = missionNamespace getVariable [format ["%1_startTime", _taskID], time];

    Mission_Active = true;
    publicVariable "Mission_Active";

    waitUntil {
        sleep 2;
        if (!alive _civ) exitWith { true };
        if (time - _missionStartTime >= _timeLimit) exitWith { true };
        false
    };

    Mission_Active = false;
    publicVariable "Mission_Active";

    private _status = "FAILED";
    if (!alive _civ) then {
        // Reputation is a civilian-system currency: skip its change when off. Charged against
        // the town the escorted civilian belonged to, falling back to the global outside one.
        if (CIV_PRESENCE != "NONE") then {
            [_civ getVariable ["civ_locIndex", -1], -1, "protect_civ_casualty"] call fnc_town_rep_adjust;
        };
        ["alert", [localize "STR_DUWS_T_cycuqbvj", localize "STR_DUWS_T_ayhemuj4"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
        [_speaker, _message3] remoteExec ["fnc_duws_dialogue", 0];
    } else {
            _status = "SUCCEEDED";
            _speakeracteam  = localize "STR_DUWS_T_actionteam";
            _message2       = ([localize "STR_DUWS_T_pcend"] call fnc_cs);
            [_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
            sleep 8;
            [_cp, _ap, "Protect Civilian"] call fnc_mission_reward;
            if (CIV_PRESENCE != "NONE") then {
                [_civ getVariable ["civ_locIndex", -1], _rep, "protect_civ_success"] call fnc_town_rep_adjust;
            };
    };

    // Informant marker cleared by hand (raw createMarker name); the ellipse and the rest of teardown
    // go through finish. Reward is already paid inline above on the success branch, so pay is false.
    if (!isNil "_civMarker" && {_civMarker != ""}) then { deleteMarker _civMarker; };
    ["Protect Civilian", _taskID, _status, _targetPos, _radius, [_areaMarker], [], false, "", true, false] call fnc_mission_finish;
};

[_targetpos, _spawnDist, _civilian, _VARtaskgeneratedName] spawn {
    params ["_pos", "_dist", "_civ", "_taskName"];

    waitUntil { sleep 1; missionNamespace getVariable [format ["%1_started", _taskName], false] };

    private _spawnOpforWave = {
        params ["_center", "_dist", "_targetObject"];
        private _spawnPos = [];
        private _attempts = 0;
        private _validPos = false;

        while {_attempts < 15 && !_validPos} do {
            _angle = random 360;
            _spawnPos = _center getPos [_dist, _angle];
            if (!surfaceIsWater _spawnPos) then { _validPos = true; };
            _attempts = _attempts + 1;
            sleep 0.5;
        };
        if (!_validPos) then {
            _spawnPos = _center getPos [_dist, random 360];
        };
        _spawnPos set [2, 0];

        _group = [_spawnPos, EAST, [
            opfor_SOLDIER_X, opfor_SOLDIER_X,
            opfor_AR_SOLDIER_X, opfor_AR_SOLDIER_X,
            opfor_LAT_SOLDIER_X,
            opfor_GL_SOLDIER_X,
            opfor_AR_SOLDIER_X, opfor_SOLDIER_X
        ]] call BIS_fnc_spawnGroup;
        {
        [_x] call fnc_addRandomLoot;
        } forEach units _group;
        {
            _x allowFleeing 0;
            _x disableAI "AUTOCOMBAT";
            _x setBehaviour "AWARE";
            _x setCombatMode "RED";
        } forEach units _group;

        _group deleteGroupWhenEmpty true;
        [_group] call fnc_mission_claim;

        _wp = _group addWaypoint [getPosATL _targetObject, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointSpeed "NORMAL";

        _wp2 = _group addWaypoint [getPosATL _targetObject, 10];
        _wp2 setWaypointType "SAD";
        _wp2 setWaypointSpeed "NORMAL";
    };

    private _waveCount = 0;
    private _maxWaves = 4;
    private _initialDelay = 20;

    private _endTime = time + _initialDelay;
    waitUntil { sleep 1; time >= _endTime || !Mission_Active };
    if (!Mission_Active) exitWith {};
    sleep 20;
    [_pos, _dist, _civ] call _spawnOpforWave;
    _waveCount = 1;

    while {_waveCount < _maxWaves && Mission_Active} do {
        _endTime = time + 40;
        waitUntil { sleep 1; time >= _endTime || !Mission_Active };
        if (!Mission_Active) exitWith {};

        [_pos, _dist, _civ] call _spawnOpforWave;
        _waveCount = _waveCount + 1;
    };
};