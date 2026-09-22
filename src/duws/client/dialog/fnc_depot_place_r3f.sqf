// Locality: client -- drives the R3F carry to place a retrieved, requested or bought vehicle, then hands
// it to the server.
//
// allowDamage is machine-local and does not follow R3F's ownership grab, so invulnerability is
// re-asserted here; fnc_depot_place_finish restores damage after the server reclaims the vehicle.
// With _baseBound, release only takes inside the base-keep ring -- a drop outside it is eaten by the
// cleanup sweep. A vendor sale clears it: the buyer stands in a town, not at a base.
if (!hasInterface) exitWith {};
params ["_vehNet", "_baseBound", "_doneKey"];
private _veh = objectFromNetId _vehNet;
if (isNull _veh) exitWith {};

// A vendor sale hands over the carry with the catalogue still open, and a dialog holds the controls.
closeDialog 0;

_veh allowDamage false;
_veh setVariable ["DUWS_depot_placing", true];

// R3F's carry returns only after a 5s settle; announce each drop once so the wait doesn't read as a failed retrieve.
[_veh] spawn {
    params ["_veh"];
    private _wasCarried = false;
    while { alive player && !isNull _veh && (_veh getVariable ["DUWS_depot_placing", false]) } do {
        private _carried = !isNull R3F_LOG_joueur_deplace_objet;
        if (_wasCarried && !_carried) then { hint localize "STR_DUWS_T_DEPOT_PLACING"; };
        _wasCarried = _carried;
        sleep 0.25;
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
        if (!_baseBound || {[getPosATL _veh] call fnc_in_base_keep}) then {
            _placed = true;
        } else {
            hint localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE";
        };
    };
};

_veh setVariable ["DUWS_depot_placing", false];
_veh allowDamage true;
[_vehNet] remoteExec ["fnc_depot_place_finish", 2];

hint format [localize _doneKey, getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")];
