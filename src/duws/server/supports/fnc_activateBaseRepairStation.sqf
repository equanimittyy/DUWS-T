if (!isServer) exitWith {};

// ====== 修理执行 ======
if (isNil "fnc_veh_repair_action") then {
    fnc_veh_repair_action = {
        params ["_caller", "_trg"];
        private _vehicles = vehicles inAreaArray _trg;
        private _count = count _vehicles;
        if (_count == 0) exitWith { [localize "STR_DUWS_T_repair_no_vehicle"] remoteExec ["hint", _caller]; };
        if (_count > 1) exitWith { [localize "STR_DUWS_T_repair_too_many"] remoteExec ["hint", _caller]; };
        private _veh = _vehicles select 0;
        private _fuel = fuel _veh;
        private _needsFuel = _fuel < 0.8;
        private _hitPoints = getAllHitPointsDamage _veh select 0;
        private _needsRepair = false;
        {
            private _dmg = _veh getHitPointDamage _x;
            if (typeName _dmg == "STRING") then { _dmg = parseNumber _dmg; };
            if (typeName _dmg == "ARRAY") then { _dmg = if (count _dmg > 0) then { _dmg select 0 } else { 0 }; };
            if (_dmg > 0.3) then { _needsRepair = true; };
        } forEach _hitPoints;
        if (!_needsFuel && !_needsRepair) exitWith { [localize "STR_DUWS_T_repair_no_need"] remoteExec ["hint", _caller]; };
        if (commandpointsblu1 < 2) exitWith { [localize "STR_DUWS_T_repair_not_enough_cp"] remoteExec ["hint", _caller]; };
        // call, not remoteExec to self: a queued debit runs a frame later and splits the
        // check above from the deduction.
        [-2] call fnc_cp_adjust;
        if (_needsFuel) then { _veh setFuel 1; };
        if (_needsRepair) then {
            {
                private _dmg = _veh getHitPointDamage _x;
                if (typeName _dmg == "STRING") then { _dmg = parseNumber _dmg; };
                if (typeName _dmg == "ARRAY") then { _dmg = if (count _dmg > 0) then { _dmg select 0 } else { 0 }; };
                if (_dmg > 0.3) then { _veh setHitPointDamage [_x, 0.3]; };
            } forEach _hitPoints;
        };
        [localize "STR_DUWS_T_repair_done"] remoteExec ["hint", _caller];
    };
    publicVariable "fnc_veh_repair_action";
};

// ====== 状态检查（完全恢复原始递归收集 + getHitPointDamage） ======
if (isNil "fnc_veh_repair_check_status") then {
    fnc_veh_repair_check_status = {
        params ["_caller", "_trgNetId"];
        if (!isServer) exitWith {};
        private _trg = objectFromNetId _trgNetId;
        if (isNull _trg) exitWith {};
        private _vehicles = vehicles inAreaArray _trg;
        if (count _vehicles == 0) exitWith { [localize "STR_DUWS_T_repair_no_vehicle"] remoteExec ["hint", _caller]; };
        if (count _vehicles > 1) exitWith { [localize "STR_DUWS_T_repair_too_many"] remoteExec ["hint", _caller]; };
        private _veh = _vehicles select 0;
        private _vehName = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName");

        // 收集 HitPoints（原始递归逻辑）
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
        _hitPoints = _hitPoints arrayIntersect _hitPoints;  // 去重

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

        // 后备：使用 getAllHitPointsDamage
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

// ====== 主逻辑 ======
private _helipad = objectFromNetId (missionNamespace getVariable ["HQ_helipad_netId", ""]);
private _depot = objectFromNetId (missionNamespace getVariable ["HQ_repairDepot_netId", ""]);
if (isNull _helipad || isNull _depot) exitWith { ["ERROR", "SUPPORT", "Helipad/Depot not found"] call fnc_log; };

if (missionNamespace getVariable ["HQ_repairStation_active", false]) exitWith {};
missionNamespace setVariable ["HQ_repairStation_active", true, true];

private _trg = createTrigger ["EmptyDetector", getPosATL _helipad, true];
_trg setTriggerArea [5, 5, 0, false, 5];

[_depot, netId _trg] remoteExec ["fnc_client_addRepairActions", 0, true];

["info", [localize "STR_DUWS_T_vehicle_repair", localize "STR_DUWS_T_repair_station_deployed"]] remoteExec ["BIS_fnc_showNotification", 0];