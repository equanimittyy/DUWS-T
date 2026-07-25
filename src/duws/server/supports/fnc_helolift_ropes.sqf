// Locality: server only (remoteExec target 2). Callers: client/supports/fnc_helolift.sqf.
// ropeCreate, setMass and allowDamage all need the helo and the slung vehicle local, and
// fnc_helolift_spawnHeli keeps both here. The setMass/allowDamage pairs are repeated after
// every step that can disturb the physics: a lift heavier than 4200 kg tears its own ropes
// the moment one client's copy reverts to the real mass, so re-assert and re-broadcast.
params ["_caller", "_mode", "_params"];
if (!isServer) exitWith {};

private _varPrefix = format ["LiftTask_%1", getPlayerUID _caller];

// Re-assert the slung vehicle's carry state on every machine. Called between each rope step.
private _pinPhysics = {
    params ["_targetVehicle", "_originalMass"];
    if (isNull _targetVehicle) exitWith {};
    if (_originalMass > 4200) then {
        _targetVehicle setMass 4200;
        [_targetVehicle, 4200] remoteExec ["setMass", 0];
    };
    _targetVehicle allowDamage false;
    [_targetVehicle, false] remoteExec ["allowDamage", 0];
};

// Hand the slung vehicle back to the world: real mass, damageable again.
private _restorePhysics = {
    params ["_targetVehicle", "_originalMass"];
    if (isNull _targetVehicle) exitWith {};
    _targetVehicle setMass _originalMass;
    [_targetVehicle, _originalMass] remoteExec ["setMass", 0];
    _targetVehicle allowDamage true;
    [_targetVehicle, true] remoteExec ["allowDamage", 0];
};

switch (_mode) do {
    case "create": {
        _params params ["_helo", "_targetVehicle", "_allPairs", "_heliPoints", "_vehPoints",
                        "_ropeLength", "_originalMass"];
        [_targetVehicle, _originalMass] call _pinPhysics;

        private _ropes = [];
        {
            _x params ["_heliIdx", "_vehIdx"];
            _ropes pushBack (ropeCreate [_helo, _heliPoints select _heliIdx,
                                         _targetVehicle, _vehPoints select _vehIdx, _ropeLength]);
        } forEach _allPairs;
        [_targetVehicle, _originalMass] call _pinPhysics;

        _helo setVariable ["attachedRopes", _ropes, true];
        _helo flyInHeight 10;
        [_targetVehicle, _originalMass] call _pinPhysics;

        [localize "STR_DUWS_T_pilot", localize "STR_DUWS_T_helolift4"]
            remoteExec ["BIS_fnc_showSubtitle", 0];
        [] remoteExec ["fnc_broadcastRadioChatter", 0];
        [_targetVehicle, _originalMass] call _pinPhysics;

        { ropeUnwind [_x, 3.5, _ropeLength * 0.2]; } forEach _ropes;
        [_targetVehicle, _originalMass] call _pinPhysics;

        missionNamespace setVariable [_varPrefix + "_ropesTight", true, true];
    };
    case "release": {
        _params params ["_helo", "_ropeLength", "_targetVehicle", "_originalMass"];
        private _ropes = _helo getVariable ["attachedRopes", []];
        if (_ropes isEqualTo []) exitWith {};
        { ropeUnwind [_x, 7, _ropeLength * 1.1]; } forEach _ropes;
        sleep 8;
        { ropeDestroy _x } forEach _ropes;
        _helo setVariable ["attachedRopes", nil, true];
        [_targetVehicle, _originalMass] call _restorePhysics;
    };
    case "abort": {
        _params params ["_helo", "_targetVehicle", "_originalMass", "_heloGroup"];
        if (!isNull _helo) then {
            { ropeDestroy _x } forEach (_helo getVariable ["attachedRopes", []]);
            _helo setVariable ["attachedRopes", nil, true];
        };
        [_targetVehicle, _originalMass] call _restorePhysics;
        if (!isNull _helo) then {
            _helo land "LAND";
            _helo engineOn false;
            [_helo, _heloGroup] spawn {
                params ["_helo", "_heloGroup"];
                sleep 160;
                if (!isNull _heloGroup) then { { deleteVehicle _x } forEach units _heloGroup; };
                if (!isNull _helo) then { deleteVehicle _helo; };
            };
        };
    };
    // Belt-and-braces sweep after a completed lift: "release" already destroyed the ropes,
    // but a rope survives its helo being deleted and then hangs in the air forever.
    case "cleanup": {
        _params params ["_helo"];
        if (isNull _helo) exitWith {};
        { ropeDestroy _x } forEach (_helo getVariable ["attachedRopes", []]);
        _helo setVariable ["attachedRopes", nil, true];
    };
};
