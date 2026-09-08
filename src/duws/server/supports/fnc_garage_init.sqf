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

// Recreates a stored vehicle on the pad from its spec and drops the entry. The spawn position is
// derived from the trigger here, never taken from the client. The vehicle is placed dead centre of the
// pad (placement 0, CAN_COLLIDE so the engine does not nudge it off centre), so the pad must be clear
// first -- refuse when any vehicle still stands in the trigger area rather than scatter it to a gap.
fnc_garage_retrieve = {
    if (!isServer) exitWith {};
    params ["_caller", "_index", "_trgNetId"];
    private _trg = objectFromNetId _trgNetId;
    if (isNull _trg) exitWith {};
    private _stored = missionNamespace getVariable ["DUWS_garage_stored", []];
    if (_index < 0 || _index >= count _stored) exitWith { [localize "STR_DUWS_T_GARAGE_NONE_SELECTED"] remoteExec ["hint", _caller]; };
    if (count (vehicles inAreaArray _trg) > 0) exitWith { [localize "STR_DUWS_T_GARAGE_PAD_OCCUPIED"] remoteExec ["hint", _caller]; };

    private _spec = _stored select _index;
    private _veh = createVehicle [_spec select 0, getPosATL _trg, [], 0, "CAN_COLLIDE"];
    [_veh, _spec] call DUWS_fnc_vehSpecApply;

    DUWS_garage_stored deleteAt _index;
    publicVariable "DUWS_garage_stored";

    [format [localize "STR_DUWS_T_GARAGE_RETRIEVED", getText (configFile >> "CfgVehicles" >> (_spec select 0) >> "displayName")]] remoteExec ["hint", _caller];
    [] remoteExec ["fnc_depot_menu_fill", _caller];
};
