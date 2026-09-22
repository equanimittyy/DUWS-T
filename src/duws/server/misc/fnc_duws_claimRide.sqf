// Locality: server -- a player's GetInMan handler (client/client_init.sqf) remoteExecs it here. Records
// _veh as _unit's last ride in DUWS_playerRides, which the map cleanup spares as in use.
// A player's own ride, not a lift: a parachute or a static would steal the claim from the vehicle the
// player left to use it, and an AI-driven transport (the helo and boat taxis) is not theirs to keep.
if (!isServer) exitWith {};
params ["_unit", "_veh"];
if (isNull _veh || {_veh isKindOf "ParachuteBase"} || {_veh isKindOf "StaticWeapon"}) exitWith {};
private _drv = driver _veh;
if (alive _drv && {(units group _drv) findIf {isPlayer _x} < 0}) exitWith {};
DUWS_playerRides set [getPlayerUID _unit, _veh];
