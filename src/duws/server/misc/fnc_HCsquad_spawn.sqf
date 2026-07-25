// Locality: server only (remoteExec target 2). Callers: dialog/fnc_request_squad.sqf,
// dialog/fnc_request_squad_fob.sqf.
//
// High Command squads are campaign assets, so the group has to be server-local: a
// group created on the buying client is simulated by that machine and orphaned when
// the player disconnects. The one step that cannot run here is hcSetGroup, which
// needs the commanding machine's own `player` -- objNull on a dedicated server -- so
// it is handed back to the caller.
if (!isServer) exitWith {};
params ["_spawnPos", "_grouptype", "_HCsquadtype", "_caller"];
if (isNull _caller) exitWith {};

private _group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_group setFormation "STAG COLUMN";

// Counters are read with a default instead of an init file: they previously existed
// only in the client-side include, so every client minted its own "Inf 1" and the
// server had no copy at all. An unrecognised squad type is left unnamed, as before.
private _spec = switch (_HCsquadtype) do {
	case "Infantry": { ["DUWS_number_fireteam", "Inf", false] };
	case "Motor":    { ["DUWS_number_motor", "Motor", true] };
	case "Mech":     { ["DUWS_number_mech", "Mech", true] };
	case "Armor":    { ["DUWS_number_armor", "Armor", true] };
	default { [] };
};
if (count _spec > 0) then {
	_spec params ["_counterKey", "_label", "_isVehicle"];
	private _n = (missionNamespace getVariable [_counterKey, 0]) + 1;
	missionNamespace setVariable [_counterKey, _n];
	_group setGroupId [format ["%1 %2", _label, _n]];
	if (_isVehicle) then { _group addVehicle (vehicle leader _group); };
};

// Register for the disconnect handler, keyed by the buyer's unit variable name.
private _var = format ["%1HC", vehiclevarname _caller];
private _HCgroups = missionNamespace getVariable [_var, []];
_HCgroups pushBack _group;
missionNamespace setVariable [_var, _HCgroups, true];

[[_group], {
	params ["_group"];
	if (isNull _group) exitWith {};
	player hcSetGroup [_group, ""];
}] remoteExec ["call", _caller];

// Keep units from dying on spawn
{ _x allowDamage false; } forEach (units _group);
sleep 15;
{ _x allowDamage true; } forEach (units _group);

// Squads spawn away from the buyer, then muster in
private _muster = getPos _caller;
_muster = [(_muster select 0) + 100, _muster select 1];
_group setCombatMode "YELLOW";
private _wp = _group addWaypoint [_muster, 50];
_wp setWaypointType "MOVE";
_wp setWaypointFormation "COLUMN";
_wp setWaypointCompletionRadius 100;
