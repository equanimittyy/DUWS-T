if (!isServer) exitWith {};

// Half the hire price, so no hull can be hired and recycled at a profit. Config side 3 is civilian (a
// missing side reads 0, East); the 1 CP floor lets even a quad or tractor return something.
if (isNil "DUWS_fnc_vehicleRecycleReward") then {
    DUWS_fnc_vehicleRecycleReward = compileFinal {
        params ["_veh"];
        private _v = 0.5 * ([typeOf _veh] call DUWS_fnc_vehPrice);
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
