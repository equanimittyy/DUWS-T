// Locality: server only (remoteExec target 2). Callers: client/supports/fnc_helolift.sqf.
// The helo MUST be created here, not on the calling client. addWaypoint, deleteWaypoint and
// flyInHeight only take effect on the machine the group is local to, and every one of those
// is issued from the server for this lift; a client-spawned group silently ignores them.
// The caller blocks on the _heloReady flag, so publish helo and group before setting it.
params ["_caller", "_target"];
if (!isServer) exitWith {};

private _varPrefix = format ["LiftTask_%1", getPlayerUID _caller];

private _vec = [random [-1,0,1], random [-1,0,1], 0];
private _spawnPos = ((vectorNormalized _vec) vectorMultiply 1200) vectorAdd (getPos _caller);
_spawnPos set [2, 200];

private _veh = [_spawnPos, 0, "C_IDAP_Heli_Transport_02_F", WEST] call BIS_fnc_spawnvehicle;
private _helo = _veh select 0;
_helo setPos _spawnPos;
_helo flyInHeight 30;
private _heloGroup = _veh select 2;
_heloGroup deleteGroupWhenEmpty true;

private _pilot = currentPilot _helo;
_pilot setCaptive false;
_pilot allowFleeing 0;
_pilot disableAI "TARGET";
// Cosmetic lift: hold fire and don't acquire, so the crew flies the sling run instead of engaging.
_pilot disableAI "AUTOTARGET";
_heloGroup setCombatMode "BLUE";
_pilot allowDamage true;
{ _x setVariable ["Vcm_Disable", true, true]; } forEach units _heloGroup;

missionNamespace setVariable [_varPrefix + "_helo", _helo, true];
missionNamespace setVariable [_varPrefix + "_heloGroup", _heloGroup, true];
missionNamespace setVariable [_varPrefix + "_heloReady", true, true];
