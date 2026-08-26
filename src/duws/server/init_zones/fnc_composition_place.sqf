// Locality: server -- createVehicle runs where the composition is built, always the server. Definition
// only; registered in server_fnc_init.sqf ahead of every caller (it needs fnc_duws_keep).
//
// The one place the composition-placement convention lives. Zones, hardpoints and the destroy-cache /
// destroy-radar side missions all stand the same shape: a table of props at fixed offsets from an anchor,
// filed under a key so the streaming layer (fnc_duws_stow / fnc_duws_deploy) and the cleanup sweep can
// treat the lot as one unit. Each used to re-implement the loop inline and drift: the two missions left
// their props simulated, upright and destructible where every zone prefab froze, tilted and hardened them.
//
// Non-weapon props only. Weapon rows (isWeapon true) carry a spawn/freeze/crew lifecycle a prop does not,
// so they stay a caller-side pass through fnc_static_place; this helper skips them and returns the props it
// placed, so the caller can run that pass and its own crew spawn against a known object list.
//
// Contract: [_rows, _origin, _key, _opts] -> [_props]
//   _rows    schema-A rows: [class, offX, offY, offZ, rowDir, isWeapon]. offZ is unused for props -- they
//            seat on the terrain at z 0, as the prefabs and missions already place them.
//   _origin  [x, y] (or [x, y, z]) world anchor the offsets are measured from
//   _key     composition key for fnc_duws_keep
//   _opts    [_heading, _tiltTypes, _invuln], defaults [0, [], []]:
//     _heading    degrees to rotate every offset by. A hardpoint stands on a heading; a prefab or a
//                 mission composition is axis-aligned, so 0 collapses the rotation to the bare offset.
//     _tiltTypes  classes laid flush to the ground via surfaceNormal -- barriers, fences, wire. Empty
//                 leaves everything upright, which is what the hardpoints want.
//     _invuln     "all" to harden every prop, a class list to harden only that fragile subset, or [] for
//                 none. The frozen-cover convention is "all"; some prefabs harden only their breakables.
//     _keepSim    classes left simulated instead of frozen -- a prop that must keep moving (a medevac heli,
//                 a working depot). Default [] freezes every prop, which is the usual case.
//
// Hardening never touches a class in DUWS_compDestructible (cargo towers and houses): those read as
// objectives or enterable structures a player expects to bring down, so they stay destructible even under
// an "all" pass. The radio mast is exempted separately, by its own hardpoint after placement.
DUWS_compDestructible = [
    "Land_Cargo_Tower_V1_F",
    "Land_Cargo_Patrol_V1_F",
    "Land_Cargo_Patrol_V3_F",
    "Land_Cargo_House_V1_F",
    "Land_Cargo_HQ_V1_F"
];

fnc_composition_place = {
    params ["_rows", "_origin", "_key", ["_opts", []]];
    _opts params [["_heading", 0], ["_tiltTypes", []], ["_invuln", []], ["_keepSim", []]];
    private _ox0 = _origin select 0;
    private _oy0 = _origin select 1;
    // "all" short-circuits the membership test below, so _invuln never reaches `_class in <string>`, which
    // would be a substring match rather than the array membership meant for the fragile-list case.
    private _invulnAll = _invuln isEqualType "" && {_invuln == "all"};

    private _props = [];
    {
        _x params ["_class", "_offX", "_offY", "", "_rowDir", ["_isWeapon", false]];
        if (_isWeapon) then { continue };

        // Same rotation as fnc_hardpoint_rotate, inline so this primitive owns no dependency on the
        // hardpoint module that is one of its callers. _heading 0 gives cos 1 / sin 0 -- the bare offset.
        private _rx = _offX * cos _heading + _offY * sin _heading;
        private _ry = _offY * cos _heading - _offX * sin _heading;
        private _wp = [_ox0 + _rx, _oy0 + _ry, 0];

        private _obj = createVehicle [_class, _wp, [], 0, "CAN_COLLIDE"];
        [_obj, _key] call fnc_duws_keep;
        _obj setPosATL _wp;
        if (_class in _tiltTypes) then { _obj setVectorUp (surfaceNormal [_wp select 0, _wp select 1]) };
        _obj setDir (_rowDir + _heading);
        if !(_class in _keepSim) then { _obj enableSimulationGlobal false };
        if (!(_class in DUWS_compDestructible) && {_invulnAll || {_class in _invuln}}) then { _obj allowDamage false };

        _props pushBack _obj;
    } forEach _rows;
    _props
};
