if (!isServer) exitWith {};

if (isNil "fnc_veh_repair_action") then {
    fnc_veh_repair_action = {
        params ["_caller", "_vehNetId"];
        private _veh = objectFromNetId _vehNetId;
        if (isNull _veh) exitWith { [localize "STR_DUWS_T_repair_no_vehicle"] remoteExec ["hint", _caller]; };

        // A third of the recycle reward, rounded up: a service always undercuts scrap-and-rebuy, and
        // ceil of a >=1 reward needs no separate floor.
        private _repairCost = ceil (([_veh] call DUWS_fnc_vehicleRecycleReward) * 0.33);
        if (commandpointsblu1 < _repairCost) exitWith { [format [localize "STR_DUWS_T_repair_not_enough_cp", _repairCost]] remoteExec ["hint", _caller]; };
        // call, not remoteExec to self: a queued debit runs a frame later and splits the
        // check above from the deduction.
        [-_repairCost, "repair_station"] call fnc_cp_adjust;

        // Ungated: services whatever the hull's state. The patch floors damage at 0.3, never a full heal.
        _veh setFuel 1;
        {
            private _dmg = _veh getHitPointDamage _x;
            if (typeName _dmg == "STRING") then { _dmg = parseNumber _dmg; };
            if (typeName _dmg == "ARRAY") then { _dmg = if (count _dmg > 0) then { _dmg select 0 } else { 0 }; };
            if (_dmg > 0.3) then { _veh setHitPointDamage [_x, 0.3]; };
        } forEach (getAllHitPointsDamage _veh select 0);
        _veh setVehicleAmmo 1;

        [localize "STR_DUWS_T_repair_done"] remoteExec ["hint", _caller];
    };
    publicVariable "fnc_veh_repair_action";
};

if (isNil "fnc_veh_repair_check_status") then {
    fnc_veh_repair_check_status = {
        params ["_caller", "_vehNetId"];
        if (!isServer) exitWith {};
        private _veh = objectFromNetId _vehNetId;
        if (isNull _veh) exitWith { [localize "STR_DUWS_T_repair_no_vehicle"] remoteExec ["hint", _caller]; };
        private _vehName = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName");

        private _hitPoints = [];
        private _fnc_collectHitpoints = {
            params ["_cfg"];
            {
                private _name = configName _x;
                if (isClass _x && {getNumber (_x >> "radius") > 0 || getNumber (_x >> "armor") > 0}) then {
                    _hitPoints pushBack _name;
                };
                [_x] call _fnc_collectHitpoints;
            } forEach ("true" configClasses _cfg);
        };

        private _vehCfg = configFile >> "CfgVehicles" >> typeOf _veh;
        if (isClass (_vehCfg >> "HitPoints")) then {
            [_vehCfg >> "HitPoints"] call _fnc_collectHitpoints;
        } else {
            { if (isClass (_vehCfg >> _x)) then { [_vehCfg >> _x] call _fnc_collectHitpoints; }; } forEach ["HitPoints","Components","Damage"];
        };
        _hitPoints = _hitPoints arrayIntersect _hitPoints;  // self-intersect dedups

        private _lines = [format ["=== %1 ===", _vehName]];
        private _hasDamage = false;
        {
            private _dmg = _veh getHitPointDamage _x;
            if (isNil "_dmg") then { _dmg = -1 };
            if (typeName _dmg != "SCALAR") then { _dmg = -1 };
            if (_dmg >= 0) then {
                _hasDamage = true;
                private _healthPercent = (1 - _dmg) * 100;
                if (_healthPercent < 0) then { _healthPercent = 0; };
                _lines pushBack format ["%1: %2%", _x, round _healthPercent];
            };
        } forEach _hitPoints;

        if (!_hasDamage) then {
            private _hpData = getAllHitPointsDamage _veh;
            private _parts = _hpData select 0;
            private _damages = _hpData select 1;
            for "_i" from 0 to (count _parts - 1) do {
                private _dmg = _damages select _i;
                if (typeName _dmg == "STRING") then { _dmg = parseNumber _dmg; };
                if (typeName _dmg == "ARRAY") then { _dmg = _dmg select 0; };
                if (isNil "_dmg" || {typeName _dmg != "SCALAR"}) then { _dmg = 0; };
                _lines pushBack format ["%1: %2%", _parts select _i, round ((1 - _dmg) * 100)];
            };
        };

        _lines pushBack format ["Fuel: %1%", round (fuel _veh * 100)];
        [_lines joinString "\n"] remoteExec ["hint", _caller];
    };
    publicVariable "fnc_veh_repair_check_status";
};

private _helipad = objectFromNetId (missionNamespace getVariable ["HQ_helipad_netId", ""]);
private _depot = objectFromNetId (missionNamespace getVariable ["HQ_repairDepot_netId", ""]);
if (isNull _helipad || isNull _depot) exitWith { ["ERROR", "SUPPORT", "Helipad/Depot not found"] call fnc_log; };

if (missionNamespace getVariable ["HQ_repairStation_active", false]) exitWith {};
missionNamespace setVariable ["HQ_repairStation_active", true, true];

// The one pad trigger for the whole depot: the recycle station and the garage read the empty vehicles
// standing in this area, so it is created once here and its netId handed to the client action.
private _trg = createTrigger ["EmptyDetector", getPosATL _helipad, true];
_trg setTriggerArea [5, 5, 0, false, 5];

// One "Vehicle Depot" client action opens the unified dialog (modification, storage, recycle). The
// depot-keyed JIP id keeps this registration distinct so a rejoin does not evict it.
[_depot, netId _trg] remoteExec ["fnc_client_addDepotActions", 0, format ["hq_depot_%1", netId _depot]];
