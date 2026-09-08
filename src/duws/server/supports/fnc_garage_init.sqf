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

// Recreates a stored vehicle dead centre of the pad from its spec and drops the entry; position comes
// off the trigger, never the client, and the pad is refused if a vehicle or a man stands on it.
//
// Frozen on spawn and thawed a beat later so it settles from rest rather than being blown off the pad
// (docs/info/architecture/arma_engine_gotchas.md). allowDamage is dropped across the settle only, and
// set AFTER the spec because allowDamage false suppresses the setDamage that restores stored damage.
fnc_garage_retrieve = {
    if (!isServer) exitWith {};
    params ["_caller", "_index", "_trgNetId"];
    private _trg = objectFromNetId _trgNetId;
    if (isNull _trg) exitWith {};
    private _stored = missionNamespace getVariable ["DUWS_garage_stored", []];
    if (_index < 0 || _index >= count _stored) exitWith { [localize "STR_DUWS_T_GARAGE_NONE_SELECTED"] remoteExec ["hint", _caller]; };
    if (count ((allUnits + vehicles) inAreaArray _trg) > 0) exitWith { [localize "STR_DUWS_T_GARAGE_PAD_OCCUPIED"] remoteExec ["hint", _caller]; };

    private _spec = _stored select _index;
    private _pos = getPosATL _trg;
    private _veh = createVehicle [_spec select 0, _pos, [], 0, "CAN_COLLIDE"];
    _veh enableSimulationGlobal false;
    _veh setDir (getDir _trg);
    // Re-seated after setDir, which displaces the object (as fnc_fortifyFOB does for its ring).
    _veh setPosATL _pos;
    _veh setVelocity [0, 0, 0];
    [_veh, _spec] call DUWS_fnc_vehSpecApply;
    _veh allowDamage false;
    [_veh] spawn {
        params ["_v"];
        sleep 0.5;
        if (isNull _v) exitWith {};
        _v enableSimulationGlobal true;
        sleep 2;
        if (!isNull _v) then { _v allowDamage true; };
    };

    DUWS_garage_stored deleteAt _index;
    publicVariable "DUWS_garage_stored";

    [format [localize "STR_DUWS_T_GARAGE_RETRIEVED", getText (configFile >> "CfgVehicles" >> (_spec select 0) >> "displayName")]] remoteExec ["hint", _caller];
    [] remoteExec ["fnc_depot_menu_fill", _caller];
};

// Map-placement retrieve: the position is a player's map click, so it is re-bounded here against the HQ
// ring (fnc_in_base_keep) rather than trusted -- beyond it the cleanup sweep collects vehicles. No
// pad-clear check: the player picks open ground, and placement radius 5 drops the vehicle on the
// nearest gap so a click over another vehicle does not stack. No refill: the dialog is closed for the pick.
fnc_garage_retrieve_map = {
    if (!isServer) exitWith {};
    params ["_caller", "_index", "_pos"];
    private _stored = missionNamespace getVariable ["DUWS_garage_stored", []];
    if (_index < 0 || _index >= count _stored) exitWith { [localize "STR_DUWS_T_GARAGE_NONE_SELECTED"] remoteExec ["hint", _caller]; };
    if (!([_pos] call fnc_in_base_keep)) exitWith { [localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE"] remoteExec ["hint", _caller]; };

    private _spec = _stored select _index;
    private _veh = createVehicle [_spec select 0, _pos, [], 5, "NONE"];
    [_veh, _spec] call DUWS_fnc_vehSpecApply;

    DUWS_garage_stored deleteAt _index;
    publicVariable "DUWS_garage_stored";

    [format [localize "STR_DUWS_T_GARAGE_RETRIEVED", getText (configFile >> "CfgVehicles" >> (_spec select 0) >> "displayName")]] remoteExec ["hint", _caller];
};
