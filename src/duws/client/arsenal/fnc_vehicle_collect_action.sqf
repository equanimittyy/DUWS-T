// Locality: client. Added at client_init and re-added by onPlayerRespawn, because the action dies with
// the body. One action on the player aimed at the vehicle under the cursor, as the body search is, so no
// vehicle carries an action of its own.
if (!hasInterface) exitWith {};

private _cond = "!isNull ([_target] call fnc_vehicle_collect_pick)";

[
    player,
    localize "STR_DUWS_T_VEHICLE_COLLECT",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    _cond,
    // Ten seconds stood still and unhurt: loading 50 m of loot is a pause in the fight, not a free click.
    _cond + " && {speed _target < 1} && {damage _target <= (_target getVariable ['DUWS_vehicleCollectHp', 0])}",
    { params ["_target"]; _target setVariable ["DUWS_vehicleCollectHp", damage _target]; },
    {},
    { params ["_target"]; private _v = [_target] call fnc_vehicle_collect_pick; if (!isNull _v) then { [_v, _target] remoteExecCall ["fnc_vehicle_collect", 2]; }; },
    {},
    [],
    10,
    // Last in the menu, below the engine's own entries for the vehicle.
    -100,
    false,
    false
] call BIS_fnc_holdActionAdd;
