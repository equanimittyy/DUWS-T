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
_veh setVariable ["DUWS_depot_placing", true];

// R3F's carry returns only after a 5s settle; show progress while a dropped-outside vehicle waits for the re-pickup.
[_veh] spawn {
    params ["_veh"];
    while { alive player && !isNull _veh && (_veh getVariable ["DUWS_depot_placing", false]) } do {
        if (isNull R3F_LOG_joueur_deplace_objet && !([getPosATL _veh] call fnc_in_base_keep)) then {
            hint localize "STR_DUWS_T_DEPOT_PLACING";
        };
        sleep 0.5;
    };
};

// A death mid-carry still finalizes below, so the vehicle is never left invulnerable on a dead client.
private _placed = false;
while { !_placed && alive player } do {
    // R3F's carry lock is global; picking up while it's held no-ops with a hint, so wait it out.
    waitUntil { !R3F_LOG_mutex_local_verrou || !alive player };
    if (alive player) then {
        // 4th arg = unload mode, re-anchoring in front; plain carry keeps the spawn offset, landing it beside.
        [_veh, objNull, objNull, true] call R3F_LOG_FNCT_objet_deplacer;
        if ([getPosATL _veh] call fnc_in_base_keep) then {
            _placed = true;
        } else {
            hint localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE";
        };
    };
};

_veh setVariable ["DUWS_depot_placing", false];
_veh allowDamage true;
[_vehNet] remoteExec ["fnc_depot_place_finish", 2];

hint format [localize "STR_DUWS_T_GARAGE_RETRIEVED", getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")];
