if (!isServer) exitWith {};

if (isNil "DUWS_fnc_calculateVehicleValue") then {
    DUWS_fnc_calculateVehicleValue = compileFinal {
        params ["_veh"];
        private _type = typeOf _veh;
        private _value = 0;

        private _crewCount = count fullCrew [_veh, "", true];
        _value = _value + (_crewCount * 0.5);

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

// The recycle policy on top of the raw combat-value estimate, so the client's confirmation quote and
// the server's credit are one function and cannot drift. Civilian hulls (config side 3, the same test
// as fnc_disguiseAsCivilian, so modded civilian classes are covered) pay half; every reward floors at
// 1 CP so even a quad or tractor returns something. A missing side reads as East (0), so a military
// hull is never mistaken for civilian.
if (isNil "DUWS_fnc_vehicleRecycleReward") then {
    DUWS_fnc_vehicleRecycleReward = compileFinal {
        params ["_veh"];
        private _v = [_veh] call DUWS_fnc_calculateVehicleValue;
        if (getNumber (configFile >> "CfgVehicles" >> typeOf _veh >> "side") == 3) then { _v = _v * 0.5; };
        1 max round _v
    };
    publicVariable "DUWS_fnc_vehicleRecycleReward";
};

if (isNil "fnc_veh_recycle_action") then {
    fnc_veh_recycle_action = {
        params ["_caller", "_vehNetId"];
        // The reward is re-derived at commit: the server is authority, so a pad that changed between
        // the client's confirmation and the Yes cannot mis-credit. A crewed hull is refused -- the pad
        // list only offers empty ones, but deleting an occupied vehicle would kill its crew.
        private _veh = objectFromNetId _vehNetId;
        if (isNull _veh) exitWith { [localize "STR_DUWS_T_DEPOT_VEHICLE_GONE"] remoteExec ["hint", _caller]; };
        if (count crew _veh > 0) exitWith {};

        private _name = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName");
        private _reward = [_veh] call DUWS_fnc_vehicleRecycleReward;
        deleteVehicle _veh;
        [_reward, "recycle_station"] call fnc_cp_adjust;

        [format [localize "STR_DUWS_T_GARAGE_RECYCLED", _name, _reward]] remoteExec ["hint", _caller];
        [] remoteExec ["fnc_depot_menu_fill", _caller];
    };
    publicVariable "fnc_veh_recycle_action";
};
