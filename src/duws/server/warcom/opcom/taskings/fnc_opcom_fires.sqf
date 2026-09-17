// Locality: server, [] call'd at load. Fire missions from the standing mortar pits and artillery batteries.
// doArtilleryFire must issue where the gun is local, and every OPFOR gun is server-spawned. This is the dumb half
// of the Arty action: it fires the mission it is handed. What is worth shelling, the cooldown, the scatter and the
// HQ exclusion are the scored action's (docs/plans/opcom/opcom_plan.md).
if (!isServer) exitWith {};

// The OPFOR mortar pits and batteries standing, nearest _from first: [[key, pos, type], ...].
DUWS_fnc_opcom_batteries = {
    params [["_from", []]];
    private _out = (DUWS_hardpoints select { ((_x select 2) in ["MORTAR", "ARTY"]) && {(_x select 3) isEqualTo "opfor"} })
        apply { [_x select 0, _x select 1, _x select 2] };
    if (_from isEqualTo []) exitWith { _out };
    [_out, [], { _from distance2D (_x select 1) }, "ASCEND"] call BIS_fnc_sortBy
};

// The pieces of one emplacement that bear on _target: [[gun, magazine], ...]. Artillery ammo is the capability
// test -- a piece that has none is not a gun this can fire, whatever it is modelled as.
DUWS_fnc_opcom_batteryGuns = {
    params ["_key", "_target"];
    private _guns = [];
    {
        if (!isNull _x && {alive _x} && {!isNull (gunner _x)}) then {
            private _mag = (getArtilleryAmmo [_x]) param [0, ""];
            if (_mag isNotEqualTo "" && {_x inRangeOfArtillery [[_target], _mag]}) then { _guns pushBack [_x, _mag] };
        };
    } forEach (DUWS_compositions getOrDefault [_key, []]);
    _guns
};

// Every gun of _key that bears puts _rounds on _target. -> rounds ordered, 0 if the emplacement cannot fire it.
DUWS_fnc_opcom_fireMission = {
    params ["_key", "_target", ["_rounds", 4]];
    private _pt = [_target select 0, _target select 1, 0];
    private _guns = [_key, _pt] call DUWS_fnc_opcom_batteryGuns;
    if (_guns isEqualTo []) exitWith {
        ["INFO", "OPCOM", format ["arty: %1 has no gun bearing on %2", _key, _pt apply { round _x }]] call fnc_log;
        0
    };
    { (_x select 0) doArtilleryFire [_pt, _x select 1, _rounds] } forEach _guns;
    ["INFO", "OPCOM", format ["arty: %1 fires %2 gun(s) x %3 rounds of %4 at %5", _key, count _guns, _rounds,
        (_guns select 0) select 1, _pt apply { round _x }]] call fnc_log;
    _rounds * (count _guns)
};
