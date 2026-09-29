// Locality: server -- spawned by the PlayerDisconnected handler in server/server_init.sqf.
params ["_group", "_sortie"];
_sortie params ["", "_paid", "_vehicle", "_offmap", "_egressH", "_claimType", "_cooldown"];

// A shot-down aircraft was lost to the fight, not to the disconnect.
if (alive _vehicle) then {
	_paid params [["_cp", 0], ["_ap", 0]];
	if (_cp > 0) then { [_cp, "hcair_recall"] call fnc_cp_adjust };
	if (_ap > 0) then { ["BLU", _ap, "hcair_recall"] call fnc_ap_adjust };
};

// The leaver's machine owned the group, and its waypoints and flight height take only where it is local.
if (!local _group) then { _group setGroupOwner 2 };
while {!(["SUPPORT", "a recalled HC aircraft to become server-local", { isNull _group || {local _group} }, 60] call fnc_waitLogged)} do {};
if (alive _vehicle) then { [_group, _vehicle, _offmap, _egressH] call fnc_hcair_egress };

if (alive _vehicle) then { [_vehicle, _group] call fnc_support_despawn }
else { { deleteVehicle _x } forEach units _group };
[_claimType, _cooldown] call fnc_hcair_endActive;
