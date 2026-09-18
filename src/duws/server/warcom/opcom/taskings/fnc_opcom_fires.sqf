// Locality: server, [] call'd at load. Fire missions from the standing mortar pits and artillery batteries.
// doArtilleryFire must issue where the gun is local, and every OPFOR gun is server-spawned. A standing battery holds
// no ammunition: its guns are emptied at register and loaded only for the mission they are given, so a crew never
// shells anything on its own. This is the dumb half of the Arty action -- it fires the mission it is handed; what is
// worth shelling, the cooldown, the scatter and the HQ exclusion are the scored action's (docs/plans/opcom/opcom_plan.md).
if (!isServer) exitWith {};

// The OPFOR mortar pits and batteries standing, nearest _from first: [[key, pos, type], ...].
DUWS_fnc_opcom_batteries = {
    params [["_from", []]];
    private _out = (DUWS_hardpoints select { ((_x select 2) in ["MORTAR", "ARTY"]) && {(_x select 3) isEqualTo "opfor"} })
        apply { [_x select 0, _x select 1, _x select 2] };
    if (_from isEqualTo []) exitWith { _out };
    [_out, [], { _from distance2D (_x select 1) }, "ASCEND"] call BIS_fnc_sortBy
};

// The emplacement's guns. The config flag, not the ammunition: an empty gun is the resting state here, so what it
// carries cannot answer whether it is a gun.
DUWS_fnc_opcom_batteryPieces = {
    params ["_key"];
    (DUWS_compositions getOrDefault [_key, []]) select {
        !isNull _x && {alive _x} && {getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "artilleryScanner") isEqualTo 1}
    }
};

DUWS_fnc_opcom_batteryUnload = {
    params ["_key"];
    { _x setVehicleAmmo 0 } forEach ([_key] call DUWS_fnc_opcom_batteryPieces);
};

// The mission's ammunition: the gun is topped up as it fires, and emptied once the rounds are away. The deadline
// empties a gun whose crew died mid-mission, or one that never fires at all -- neither must be left loaded.
DUWS_fnc_opcom_batteryFireWatch = {
    params ["_gun", "_rounds"];
    private _old = _gun getVariable ["DUWS_opcomFireEH", -1];
    if (_old >= 0) then { _gun removeEventHandler ["Fired", _old] };
    _gun setVariable ["DUWS_opcomFired", 0];
    _gun setVariable ["DUWS_opcomFireEH", _gun addEventHandler ["Fired", {
        params ["_g"];
        _g setVariable ["DUWS_opcomFired", (_g getVariable ["DUWS_opcomFired", 0]) + 1];
        _g setVehicleAmmo 1;
    }]];
    [_gun, _rounds] spawn {
        params ["_gun", "_rounds"];
        private _deadline = time + OPCOM_ARTY_ROUND_SECS * (_rounds + 2);
        waitUntil {
            sleep 1;
            !alive _gun || {(_gun getVariable ["DUWS_opcomFired", 0]) >= _rounds} || {time > _deadline}
        };
        private _fired = _gun getVariable ["DUWS_opcomFired", 0];
        if (!alive _gun) exitWith {};
        _gun removeEventHandler ["Fired", _gun getVariable ["DUWS_opcomFireEH", -1]];
        _gun setVariable ["DUWS_opcomFireEH", -1];
        _gun setVehicleAmmo 0;
        [["INFO", "WARN"] select (_fired < _rounds), "OPCOM", format ["arty: %1 put %2/%3 rounds down, empty again",
            typeOf _gun, _fired, _rounds]] call fnc_log;
    };
};

// Every gun of _key that bears puts _rounds on _target. -> rounds ordered, 0 if the emplacement cannot fire it.
DUWS_fnc_opcom_fireMission = {
    params ["_key", "_target", ["_rounds", 4]];
    private _pt = [_target select 0, _target select 1, 0];
    private _firing = 0;
    private _mag = "";
    {
        private _gun = _x;
        // Loaded before the range test: an empty gun reports no artillery magazine to fire or to measure with.
        _gun setVehicleAmmo 1;
        private _m = (getArtilleryAmmo [_gun]) param [0, ""];
        // Target left, guns in the array -- the mirror of doArtilleryFire; transposed it throws and kills the loop.
        if (_m isEqualTo "" || {isNull (gunner _gun)} || {!(_pt inRangeOfArtillery [[_gun], _m])}) then {
            _gun setVehicleAmmo 0;
        } else {
            _mag = _m;
            [_gun, _rounds] call DUWS_fnc_opcom_batteryFireWatch;
            _gun doArtilleryFire [_pt, _m, _rounds];
            _firing = _firing + 1;
        };
    } forEach ([_key] call DUWS_fnc_opcom_batteryPieces);
    if (_firing == 0) exitWith {
        ["INFO", "OPCOM", format ["arty: %1 has no gun bearing on %2", _key, _pt apply { round _x }]] call fnc_log;
        0
    };
    ["INFO", "OPCOM", format ["arty: %1 fires %2 gun(s) x %3 rounds of %4 at %5", _key, _firing, _rounds, _mag,
        _pt apply { round _x }]] call fnc_log;
    _rounds * _firing
};
