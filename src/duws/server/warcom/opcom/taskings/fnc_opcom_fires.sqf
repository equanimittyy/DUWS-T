// Locality: server, [] call'd at load. Fire missions from the standing mortar pits and artillery batteries.
// doArtilleryFire must issue where the gun is local, and every OPFOR gun is server-spawned. A standing battery holds
// no ammunition: its guns are emptied at register and loaded only for the mission they are given, so a crew never
// shells anything on its own. This is the dumb half of the Arty action -- it fires the mission it is handed; what is
// worth shelling, the shape and its size, the cooldown and the HQ exclusion are the scored action's
// (docs/plans/opcom/opcom_plan.md).
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

// A creep's [rows, rounds a gun lays per row]: one round per OPCOM_ARTY_CREEP_STEP of its length and of each gun's
// lane, so its density holds whatever its size or the guns that bear.
DUWS_fnc_opcom_creepGrid = {
    params ["_shape", "_guns"];
    _shape params ["", "_width", "_length"];
    [ceil ((_length max OPCOM_ARTY_MIN_SPREAD) / OPCOM_ARTY_CREEP_STEP),
        ceil ((_width max OPCOM_ARTY_MIN_SPREAD) / _guns / OPCOM_ARTY_CREEP_STEP)]
};

// A creep gives each gun its own lane and each row its own band, so the line walks forward together. _drift is the
// pattern's wander, one [x, y] per creep row or saturate round; a creep takes only its lateral part, off its bearing.
// _scatter is a radius about each aim point that the round lands anywhere within, on top of the pattern.
DUWS_fnc_opcom_fireAim = {
    params ["_pt", "_shape", "_g", "_guns", "_k", ["_drift", []], ["_scatter", 0]];
    private _off = switch (_shape select 0) do {
        case "creep": {
            _shape params ["", "_width", "_length", "_dir"];
            ([_shape, _guns] call DUWS_fnc_opcom_creepGrid) params ["_rows", "_perRow"];
            private _row = floor (_k / _perRow);
            (_drift param [_row, [0, 0]]) params ["_dx"];
            [(_width max OPCOM_ARTY_MIN_SPREAD) * ((_g + ((_k mod _perRow) + random 1) / _perRow) / _guns - 0.5) + _dx,
                (_length max OPCOM_ARTY_MIN_SPREAD) * (_row + random 1) / _rows, _dir] call fnc_hardpoint_rotate
        };
        default {
            _shape params ["", "_radius"];
            (_drift param [_k, [0, 0]]) params ["_dx", "_dy"];
            // sqrt: uniform over the disc's area, not bunched at its centre.
            private _r = (_radius max OPCOM_ARTY_MIN_SPREAD) * sqrt random 1;
            private _t = random 360;
            [_r * sin _t + _dx, _r * cos _t + _dy]
        };
    };
    if (_scatter > 0) then {
        private _r = _scatter * sqrt random 1;
        private _t = random 360;
        _off = [(_off select 0) + _r * sin _t, (_off select 1) + _r * cos _t];
    };
    [(_pt select 0) + (_off select 0), (_pt select 1) + (_off select 1), 0]
};

// doArtilleryFire puts every round of one order on one point, so each aim point is its own one-round order.
// A round not away inside OPCOM_ARTY_ROUND_SECS is written off, so a dead crew never leaves the gun loaded.
DUWS_fnc_opcom_gunFire = {
    params ["_gun", "_mag", "_pts", "_delay", "_jitter"];
    private _old = _gun getVariable ["DUWS_opcomFireEH", -1];
    if (_old >= 0) then { _gun removeEventHandler ["Fired", _old] };
    _gun setVariable ["DUWS_opcomFired", 0];
    _gun setVariable ["DUWS_opcomFireEH", _gun addEventHandler ["Fired", {
        params ["_g"];
        _g setVariable ["DUWS_opcomFired", (_g getVariable ["DUWS_opcomFired", 0]) + 1];
        _g setVehicleAmmo 1;
    }]];
    [_gun, _mag, _pts, _delay, _jitter] spawn {
        params ["_gun", "_mag", "_pts", "_delay", "_jitter"];
        sleep _delay;
        {
            if (!alive _gun || {!alive (gunner _gun)}) exitWith {};
            // Spread can carry a point past the gun's reach even when the aim point bears; skip it, don't wait it out.
            if !(_x inRangeOfArtillery [[_gun], _mag]) then { continue };
            sleep random _jitter;
            private _before = _gun getVariable ["DUWS_opcomFired", 0];
            private _deadline = time + OPCOM_ARTY_ROUND_SECS;
            _gun doArtilleryFire [_x, _mag, 1];
            waitUntil { sleep 0.5; !alive _gun || {(_gun getVariable ["DUWS_opcomFired", 0]) > _before} || {time > _deadline} };
        } forEach _pts;
        if (!alive _gun) exitWith {};
        private _fired = _gun getVariable ["DUWS_opcomFired", 0];
        _gun removeEventHandler ["Fired", _gun getVariable ["DUWS_opcomFireEH", -1]];
        _gun setVariable ["DUWS_opcomFireEH", -1];
        _gun setVehicleAmmo 0;
        [["INFO", "WARN"] select (_fired < count _pts), "OPCOM", format ["arty: %1 put %2/%3 rounds down, empty again",
            typeOf _gun, _fired, count _pts]] call fnc_log;
    };
};

// Seconds until the first round lands, off the first gun that bears -- what the telegraph is timed against. The gun
// is emptied again: the mission's own load decides what actually fires.
DUWS_fnc_opcom_fireETA = {
    params ["_key", "_pt"];
    private _eta = 0;
    {
        private _gun = _x;
        _gun setVehicleAmmo 1;
        private _m = (getArtilleryAmmo [_gun]) param [0, ""];
        private _bears = _m isNotEqualTo "" && {!isNull (gunner _gun)} && {_pt inRangeOfArtillery [[_gun], _m]};
        if (_bears) then { _eta = _gun getArtilleryETA [_pt, _m] };
        _gun setVehicleAmmo 0;
        if (_bears) exitWith {};
    } forEach ([_key] call DUWS_fnc_opcom_batteryPieces);
    _eta
};

// _shape is ["saturate", radius] about _target or ["creep", width, length, bearing] walking forward from it. _rounds is
// a gun's for a saturate; a creep sizes its own (DUWS_fnc_opcom_creepGrid). -> rounds ordered, 0 if no gun bears.
DUWS_fnc_opcom_fireMission = {
    params ["_key", "_target", ["_rounds", 4], ["_shape", ["saturate", 0]]];
    private _pt = [_target select 0, _target select 1, 0];
    private _guns = [];
    {
        private _gun = _x;
        // Loaded before the range test: an empty gun reports no artillery magazine to fire or to measure with.
        _gun setVehicleAmmo 1;
        private _m = (getArtilleryAmmo [_gun]) param [0, ""];
        // Target left, guns in the array -- the mirror of doArtilleryFire; transposed it throws and kills the loop.
        if (_m isEqualTo "" || {isNull (gunner _gun)} || {!(_pt inRangeOfArtillery [[_gun], _m])}) then {
            _gun setVehicleAmmo 0;
        } else {
            _guns pushBack [_gun, _m, getText (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _m >> "ammo") >> "simulation")];
        };
    } forEach ([_key] call DUWS_fnc_opcom_batteryPieces);
    if (_guns isEqualTo []) exitWith {
        ["INFO", "OPCOM", format ["arty: %1 has no gun bearing on %2", _key, _pt apply { round _x }]] call fnc_log;
        0
    };
    private _steps = _rounds;
    if ((_shape select 0) isEqualTo "creep") then {
        ([_shape, count _guns] call DUWS_fnc_opcom_creepGrid) params ["_rows", "_perRow"];
        _steps = _rows;
        _rounds = _rows * _perRow;
    };
    // One walk for the whole battery, so the pattern wanders as one rather than each gun scattering alone.
    private _drift = [];
    private _dx = 0;
    private _dy = 0;
    for "_i" from 1 to _steps do {
        _dx = _dx + OPCOM_ARTY_WANDER * (random 2 - 1);
        _dy = _dy + OPCOM_ARTY_WANDER * (random 2 - 1);
        _drift pushBack [_dx, _dy];
    };
    {
        _x params ["_gun", "_m", "_sim"];
        // Not-a-shell rather than is-a-rocket: a launcher's round may be a rocket or a submunition carrier by mod.
        private _rocket = _sim != "shotShell";
        private _g = _forEachIndex;
        private _pts = [];
        for "_k" from 0 to _rounds - 1 do {
            _pts pushBack ([_pt, _shape, _g, count _guns, _k, _drift, [0, OPCOM_ARTY_ROCKET_SCATTER] select _rocket] call DUWS_fnc_opcom_fireAim);
        };
        [_gun, _m, _pts, OPCOM_ARTY_STAGGER * _g, [OPCOM_ARTY_JITTER, OPCOM_ARTY_ROCKET_JITTER] select _rocket] call DUWS_fnc_opcom_gunFire;
    } forEach _guns;
    ["INFO", "OPCOM", format ["arty: %1 fires %2 gun(s) x %3 rounds of %4 (%5), %6 at %7", _key, count _guns, _rounds,
        (_guns select 0) select 1, (_guns select 0) select 2, _shape, _pt apply { round _x }]] call fnc_log;
    _rounds * count _guns
};
