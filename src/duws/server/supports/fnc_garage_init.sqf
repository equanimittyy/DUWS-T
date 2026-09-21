// The vehicle garage: store a pad vehicle to data and retrieve it. Capacity levels are bought from
// the REQUESTS menu as permanent supports (client/supports/fnc_supports_init.sqf).
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one place to
// see what reaches clients. Server-authoritative: clients call in with remoteExec [..., 2], and each
// path re-derives its own facts from the server's copy of the state rather than trusting the caller.

// Captures the selected empty pad vehicle to a spec, deletes it, and banks the spec against the
// vehicle's domain pool. Refuses a crewed vehicle or a full pool for that domain, so a full land pool
// never blocks storing an aircraft.
fnc_garage_store = {
    if (!isServer) exitWith {};
    params ["_caller", "_vehNetId"];
    private _veh = objectFromNetId _vehNetId;
    if (isNull _veh) exitWith { [localize "STR_DUWS_T_GARAGE_NONE_SELECTED"] remoteExec ["hint", _caller]; };
    if (count crew _veh > 0) exitWith { [localize "STR_DUWS_T_GARAGE_CREWED"] remoteExec ["hint", _caller]; };

    private _domain = [typeOf _veh] call DUWS_fnc_vehDomain;
    private _di = [_domain] call DUWS_fnc_garageDomainIndex;
    private _cap = ([] call DUWS_fnc_garageCaps) select _di;
    private _used = ([] call DUWS_fnc_garageUsed) select _di;
    if (_used >= _cap) exitWith { [localize "STR_DUWS_T_GARAGE_POOL_FULL"] remoteExec ["hint", _caller]; };

    private _spec = [_veh] call DUWS_fnc_vehSpecCapture;
    deleteVehicle _veh;
    DUWS_garage_stored pushBack _spec;
    publicVariable "DUWS_garage_stored";

    [format [localize "STR_DUWS_T_GARAGE_STORED", getText (configFile >> "CfgVehicles" >> (_spec select 0) >> "displayName")]] remoteExec ["hint", _caller];
    [] remoteExec ["fnc_depot_menu_fill", _caller];
};

// Spawns a spec for an R3F carry (fnc_depot_place_r3f) to place, invulnerable so the carry's clips
// cannot damage it. Radius-5 "NONE" drops it on an empty gap so it never stacks on a parked vehicle.
// The spec is applied while the hull is still server-local, which is what lets its plain setFuel and
// setDamage replicate.
fnc_depot_carry_spawn = {
    params ["_spec", "_pos"];
    private _veh = createVehicle [_spec select 0, _pos, [], 5, "NONE"];
    _veh allowDamage false;
    _veh enableSimulationGlobal false; // freeze for the carry so the dragged hull can't collision-damage objects it sweeps (units shielded via R3F HandleDamage)
    _veh lock true; // block entry while the player hand-places it; both cleared in fnc_depot_place_finish
    [_veh, _spec] call DUWS_fnc_vehSpecApply;
    _veh
};

// Retrieve: spawn the stored vehicle on the pad (inside the base-keep ring) for the caller's R3F carry.
fnc_garage_retrieve = {
    if (!isServer) exitWith {};
    params ["_caller", "_index", "_padNet"];
    private _stored = missionNamespace getVariable ["DUWS_garage_stored", []];
    if (_index < 0 || _index >= count _stored) exitWith { [localize "STR_DUWS_T_GARAGE_NONE_SELECTED"] remoteExec ["hint", _caller]; };

    private _pad = objectFromNetId _padNet;
    private _spawnPos = if (isNull _pad) then { PosOfBLUHQ } else { getPosATL _pad };
    private _veh = [_stored select _index, _spawnPos] call fnc_depot_carry_spawn;

    DUWS_garage_stored deleteAt _index;
    publicVariable "DUWS_garage_stored";

    [netId _veh] remoteExec ["fnc_depot_place_r3f", _caller];
};

// Finalize: reclaim for the server (the carry made the caller owner), thaw, disable R3F.
// Every R3F action gates on !R3F_LOG_disabled, so the one flag retires all of them.
fnc_depot_place_finish = {
    if (!isServer) exitWith {};
    params ["_vehNet"];
    private _veh = objectFromNetId _vehNet;
    if (isNull _veh) exitWith {};

    _veh setOwner 2;
    // R3F's carry-end handler has already restored damage on every machine, so the guard over the thaw's
    // settle is set again here.
    _veh allowDamage false;
    _veh enableSimulationGlobal true;
    _veh lock false;
    _veh setVariable ["R3F_LOG_disabled", true, true];
    [_veh] spawn {
        params ["_veh"];
        sleep 2;
        if (!isNull _veh) then { _veh allowDamage true };
    };
};
