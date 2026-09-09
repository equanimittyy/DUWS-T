// Locality: client -- drives the R3F carry to place the retrieved vehicle, then hands it to the server.
//
// allowDamage is machine-local and does not follow R3F's ownership grab, so invulnerability is
// re-asserted here; fnc_depot_place_finish restores damage after the server reclaims the vehicle.
// Release only takes inside the base-keep ring -- a drop outside it is eaten by the cleanup sweep.
if (!hasInterface) exitWith {};
params ["_vehNet"];
private _veh = objectFromNetId _vehNet;
if (isNull _veh) exitWith {};

_veh allowDamage false;

// A death mid-carry still finalizes below, so the vehicle is never left invulnerable on a dead client.
private _placed = false;
while { !_placed && alive player } do {
    [_veh] call R3F_LOG_FNCT_objet_deplacer;
    if ([getPosATL _veh] call fnc_in_base_keep) then {
        _placed = true;
    } else {
        hint localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE";
        waitUntil { !R3F_LOG_mutex_local_verrou };
    };
};

_veh allowDamage true;
[_vehNet] remoteExec ["fnc_depot_place_finish", 2];

hint format [localize "STR_DUWS_T_GARAGE_RETRIEVED", getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")];
