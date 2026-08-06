// Locality: server -- createVehicle and fnc_static_place run where the composition is built and the
// faction globals are authoritative. Definitions only; the callers are the dev spawner now, and the
// zone siting loop and OPCOM later.
//
// A hardpoint is a composition placed onto a heading. The prefabs place their rows at fixed offsets;
// a hardpoint rotates the whole layout about its centre, so a heading turns the cover with the core
// rather than turning the core inside a fixed ring. The prefab split is reused: props are
// ground-snapped, then weapon rows go through fnc_static_place, which resolves the vanilla placeholder
// to _side's own gun and writes the absolute height a weapon row carries.

// [_ox, _oy, _dir] call fnc_hardpoint_rotate -> [x, y] rotated onto heading _dir (clockwise like
// setDir; +Y is the layout's facing). Pure, so the rotation is unit-tested.
fnc_hardpoint_rotate = {
    params ["_ox", "_oy", "_dir"];
    [_ox * cos _dir + _oy * sin _dir, _oy * cos _dir - _ox * sin _dir]
};

// [_type, _pos, _dir, _side, _key] call fnc_hardpoint_build -> [objects]
//   _type  "MG" / "AT" / ... / "MINEFIELD"; the suffix of DUWS_hardpointComp_<type>
//   _pos   [x, y]; the layout centre
//   _dir   heading in degrees the layout faces
//   _side  "opfor" / "blufor"; which faction the guns resolve to
//   _key   composition key the objects are filed under for teardown
fnc_hardpoint_build = {
    params ["_type", "_pos", ["_dir", 0], ["_side", "opfor"], ["_key", "world"]];
    private _px = _pos select 0;
    private _py = _pos select 1;

    // The minefield is generated, not composed -- it has no fence to place.
    if (_type isEqualTo "MINEFIELD") exitWith {
        [[_px, _py], _dir, "AT", 6, 3, 4, 0.6, _key] call fnc_hardpoint_minefield
    };

    private _rows = missionNamespace getVariable ["DUWS_hardpointComp_" + _type, []];
    if (_rows isEqualTo []) exitWith {
        ["WARN", "HARDPOINT", format ["no composition for type %1", _type]] call fnc_log;
        []
    };

    private _placed = [];
    // Props first: a weapon row's Z is an absolute height fnc_static_place writes, and the ground pass
    // here would stamp it to terrain like a prop. Props are frozen invulnerable cover, as the prefabs
    // place them; the gun is what the player destroys.
    {
        _x params ["_class", "_ox", "_oy", "_oz", "_rowDir", ["_isWeapon", false]];
        if (_isWeapon) then { continue };
        private _off = [_ox, _oy, _dir] call fnc_hardpoint_rotate;
        private _wp = [_px + (_off select 0), _py + (_off select 1), 0];
        private _obj = createVehicle [_class, _wp, [], 0, "CAN_COLLIDE"];
        [_obj, _key] call fnc_duws_keep;
        _obj setPosATL _wp;
        _obj setDir (_rowDir + _dir);
        _obj enableSimulationGlobal false;
        _obj allowDamage false;
        _placed pushBack _obj;
    } forEach _rows;

    // Weapons second. fnc_static_place adds the row's own offset to the origin it is handed, so the
    // rotated offset is folded into the origin and the row passed with a zeroed X/Y.
    {
        if !(_x param [5, false]) then { continue };
        _x params ["_wc", "_wox", "_woy", "_woz", "_wdir"];
        private _off = [_wox, _woy, _dir] call fnc_hardpoint_rotate;
        private _wrow = [_wc, 0, 0, _woz, _wdir + _dir, true];
        _placed pushBack ([_wrow, [_px + (_off select 0), _py + (_off select 1)], _side, _key, "world"] call fnc_static_place);
    } forEach _rows;

    _placed
};

// [_objs, _pos, _side, _key, _garrison] call fnc_hardpoint_garrison -> [men]
//
// _garrison is a list of soldier classes -- the loose defenders -- and may be empty, which places
// none. The array shape is deliberate: an empty garrison needs no special case at the call site, and
// it is the same shape a zone raises from. The emplacement is manned regardless of it: a gun without
// a gunner is scenery, not a defence, so every gun takes a crewman whether or not any loose defender
// does. Side-generic via BIS_fnc_spawnGroup and the <side>_SOLDIER_X global, so the dev tool's OPFOR
// and BLUFOR spawns each field their own men.
//
// Two kinds of gun, crewed two ways. A static weapon goes through DUWS_fnc_manStatics, the path a
// zone mans its emplacements with -- it thaws the frozen gun, drops it to settle on the ground and
// seats a gunner, because a static is placed frozen and sometimes on a bunker roof. Artillery is a
// vehicle, already sitting on its tracks, so it skips the drop: its gunner is moved straight in and
// the piece is thawed so OPCOM can task it. artilleryScanner is the config flag the faction
// auto-detect reads to call a vehicle artillery, so a modded battery is caught the same way.
fnc_hardpoint_garrison = {
    params ["_objs", "_pos", ["_side", "opfor"], ["_key", "world"], ["_garrison", []]];
    private _sideObj = [EAST, WEST] select (_side isEqualTo "blufor");
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _men = [];

    // Static guns first, always crewed: one man per gun, dropped and settled.
    private _guns = _objs select { !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"} };
    if (count _guns > 0) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_guns apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        [_guns, _crew, _key] call DUWS_fnc_manStatics;
        _men append (units _crew);
    };

    // Artillery vehicles: a gunner straight in, no drop, and thawed so the battery can fire.
    private _arty = _objs select { !isNull _x && {alive _x} && {!(_x isKindOf "StaticWeapon")}
        && {getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "artilleryScanner") isEqualTo 1} };
    if (count _arty > 0) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_arty apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        {
            _x enableSimulationGlobal true;
            ((units _crew) param [_forEachIndex, objNull]) moveInGunner _x;
        } forEach _arty;
        _men append (units _crew);
    };

    // Then the loose defenders. An empty list places no one.
    if (count _garrison > 0) then {
        private _sp = _pos findEmptyPosition [0, 30, _garrison select 0];
        if (count _sp == 0) then { _sp = _pos };
        private _grp = [_sp, _sideObj, _garrison, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _grp deleteGroupWhenEmpty true;
        [_grp, _pos] call BIS_fnc_taskDefend;
        _men append (units _grp);
    };

    _men
};

// [_type, _pos, _dir, _side, _key, _garrison] call fnc_hardpoint_spawn -> [objects, men]
//
// Build plus man: the composition, then the loose defenders and a gunner on every static gun. Sleeps
// (the drop-and-settle in DUWS_fnc_manStatics), so it must run scheduled -- the dev spawner spawns it,
// and the zone loop and OPCOM will too.
fnc_hardpoint_spawn = {
    params ["_type", "_pos", ["_dir", 0], ["_side", "opfor"], ["_key", "world"], ["_garrison", []]];
    private _objs = [_type, _pos, _dir, _side, _key] call fnc_hardpoint_build;
    private _men = [_objs, _pos, _side, _key, _garrison] call fnc_hardpoint_garrison;
    [_objs, _men]
};
