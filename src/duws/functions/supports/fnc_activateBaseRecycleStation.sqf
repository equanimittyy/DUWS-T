if (!isServer) exitWith {};

// ====== 价值计算 ======
if (isNil "DUWS_fnc_calculateVehicleValue") then {
    DUWS_fnc_calculateVehicleValue = compileFinal {
        params ["_veh"];
        private _type = typeOf _veh;
        private _value = 0;

        // 乘员位置
        private _crewCount = count fullCrew [_veh, "", true];
        _value = _value + (_crewCount * 0.5);

        // 统计武器类型
        private _weaponTypes = [];

        private _fnc_processTurrets = {
            params ["_turretConfig", "_path"];
            {
                private _turret = _x;
                private _weapons = getArray (_turret >> "weapons");
                { _weaponTypes pushBackUnique toLowerANSI _x; } forEach _weapons;
                private _subTurrets = "true" configClasses (_turret >> "Turrets");
                if (count _subTurrets > 0) then {
                    [_subTurrets, _path + [_forEachIndex]] call _fnc_processTurrets;
                };
            } forEach _turretConfig;
        };

        private _mainTurrets = "true" configClasses (configFile >> "CfgVehicles" >> _type >> "Turrets");
        [_mainTurrets, []] call _fnc_processTurrets;

        {
            private _weapon = _x;
            private _parents = [configFile >> "CfgWeapons" >> _weapon, true] call BIS_fnc_returnParents;
            _parents = _parents apply {toLowerANSI _x};

            if (("mguncore" in _parents) || ("machinegun" in _parents)) then { _value = _value + 3; };
            if (("gmg_f" in _parents) || ("grenadelauncher" in _parents)) then { _value = _value + 4.5; };
            if (("cannoncore" in _parents) || ("autocannon_base_f" in _parents)) then { _value = _value + 8; };
            if (("launchercore" in _parents) || ("missilelauncher" in _parents)) then { _value = _value + 6; };
        } forEach _weaponTypes;

        // 补给倍率
        private _isSupply = (getNumber (configFile >> "CfgVehicles" >> _type >> "transportAmmo") > 0) ||
                            (getNumber (configFile >> "CfgVehicles" >> _type >> "transportRepair") > 0) ||
                            (getNumber (configFile >> "CfgVehicles" >> _type >> "transportMedical") > 0);
        if (_isSupply) then {
            _value = _value * 5;
        } else {
            if (_veh isKindOf "Car") then { _value = _value * 0.8; };
            if (_veh isKindOf "Tank") then { _value = _value * 1.1; };
            if (_veh isKindOf "Helicopter" || _veh isKindOf "Plane") then { _value = _value * 1.5; };
        };

        _value
    };
    publicVariable "DUWS_fnc_calculateVehicleValue";
};

// ====== 预览 ======
if (isNil "fnc_veh_recycle_preview_server") then {
    fnc_veh_recycle_preview_server = {
        params ["_caller", "_trg"];

        private _excludedClasses = ["B_Quadbike_01_F","C_Hatchback_01_F","C_Hatchback_01_sport_F","C_Offroad_01_F","C_SUV_01_F","C_Tractor_01_F","C_Van_01_Transport_F","C_Van_01_Box_F","C_Van_02_Vehicle_F","C_Van_02_transport_F","C_Truck_02_transport_F","C_Truck_02_covered_F"];

        private _vehicles = vehicles inAreaArray _trg;
        private _recyclableVehicles = [];
        { if (count crew _x == 0 && !(typeOf _x in _excludedClasses)) then { _recyclableVehicles pushBack _x; }; } forEach _vehicles;

        private _totalValue = 0;
        { _totalValue = _totalValue + ([_x] call DUWS_fnc_calculateVehicleValue); } forEach _recyclableVehicles;

        private _msg = format [localize "STR_DUWS_T_PREVIEW_VALUE", count _recyclableVehicles, _totalValue];
        [_msg] remoteExec ["hint", _caller];
    };
    publicVariable "fnc_veh_recycle_preview_server";
};

// ====== 回收执行 ======
if (isNil "fnc_veh_recycle_action") then {
    fnc_veh_recycle_action = {
        params ["_caller", "_trg"];

        private _excludedClasses = ["B_Quadbike_01_F","C_Hatchback_01_F","C_Hatchback_01_sport_F","C_Offroad_01_F","C_SUV_01_F","C_Tractor_01_F","C_Van_01_Transport_F","C_Van_01_Box_F","C_Van_02_Vehicle_F","C_Van_02_transport_F","C_Truck_02_transport_F","C_Truck_02_covered_F"];

        private _vehicles = vehicles inAreaArray _trg;
        private _recyclableVehicles = [];
        private _hasExcluded = false;
        {
            if (count crew _x == 0) then {
                if (typeOf _x in _excludedClasses) then { _hasExcluded = true; }
                else { _recyclableVehicles pushBack _x; };
            };
        } forEach _vehicles;

        private _count = count _recyclableVehicles;
        if (_count > 0) then {
            private _totalReward = 0;
            { _totalReward = _totalReward + ([_x] call DUWS_fnc_calculateVehicleValue); deleteVehicle _x; } forEach _recyclableVehicles;
            commandpointsblu1 = commandpointsblu1 + _totalReward;
            publicVariable "commandpointsblu1";
            [format [localize "STR_DUWS_T_chenggonghuishou", _count, _totalReward]] remoteExec ["hint", _caller];
        } else {
            if (_hasExcluded) then { [localize "STR_DUWS_T_gaizaijvwufahuishou"] remoteExec ["hint", _caller]; }
            else { [localize "STR_DUWS_T_gaizaijvkongde"] remoteExec ["hint", _caller]; };
        };
    };
    publicVariable "fnc_veh_recycle_action";
};

// ====== 主逻辑 ======
private _helipad = objectFromNetId (missionNamespace getVariable ["HQ_helipad_netId", ""]);
private _depot = objectFromNetId (missionNamespace getVariable ["HQ_repairDepot_netId", ""]);
if (isNull _helipad || isNull _depot) exitWith { diag_log "[RECYCLE] Helipad/Depot not found"; };

if (missionNamespace getVariable ["HQ_recycleStation_active", false]) exitWith {};
missionNamespace setVariable ["HQ_recycleStation_active", true, true];

private _trg = createTrigger ["EmptyDetector", getPosATL _helipad, true];
_trg setTriggerArea [5, 5, 0, false, 5];

[_depot, netId _trg] remoteExec ["fnc_client_addRecycleActions", 0, true];

["info", [localize "STR_DUWS_T_zaijvhuishouzhan2", localize "STR_DUWS_T_zaijvhuishouzhan3"]] remoteExec ["BIS_fnc_showNotification", 0];