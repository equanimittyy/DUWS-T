// Locality: server -- fnc_static_place raises objects and every resolve feeds one, so both run
// where the faction globals are authoritative.
//
// A composition names a vanilla static because that is what an author drags into Eden; what a zone
// needs is the role that gun plays, filled by whichever faction is holding the ground. This turns
// the one into the other, and puts the gun down, in one file -- so the decision about which class a
// static is and the only sanctioned way to place one cannot drift apart.

// Role token per placeholder class. Every side's variant of each family, not only the classes the
// shipped compositions use, so a gun swapped in Eden still resolves. The autonomous (_A_F) sentries
// are deliberately absent: they are unmanned by design, and a role would have the zone crew them.
//
// High and crouch-height mounts share a role, so the mount an author placed is not the one that
// stands. Compositions therefore place the high variant, whose height their Z was measured against.
// A role per mount would not help: 252 of the 255 faction files name TURRET_HMG by hand and none
// would name the new key, so each falls back to the gun it already has.
// --DUWS-UNITCOMP BEGIN name="Static weapon roles" kind=team row="class, role" fields="class, role"--
DUWS_staticRoles = [
    ["B_HMG_01_F",         "HMG"],
    ["B_HMG_01_high_F",    "HMG"],
    ["O_HMG_01_F",         "HMG"],
    ["O_HMG_01_high_F",    "HMG"],
    ["I_HMG_01_F",         "HMG"],
    ["I_HMG_01_high_F",    "HMG"],
    ["I_HMG_02_F",         "HMG"],
    ["I_HMG_02_high_F",    "HMG"],
    ["B_G_HMG_02_F",       "HMG"],
    ["B_G_HMG_02_high_F",  "HMG"],
    ["O_G_HMG_02_F",       "HMG"],
    ["O_G_HMG_02_high_F",  "HMG"],
    ["I_G_HMG_02_F",       "HMG"],
    ["I_G_HMG_02_high_F",  "HMG"],

    ["B_GMG_01_F",         "GMG"],
    ["B_GMG_01_high_F",    "GMG"],
    ["O_GMG_01_F",         "GMG"],
    ["O_GMG_01_high_F",    "GMG"],
    ["I_GMG_01_F",         "GMG"],
    ["I_GMG_01_high_F",    "GMG"],
    ["B_G_GMG_01_F",       "GMG"],
    ["B_G_GMG_01_high_F",  "GMG"],
    ["O_G_GMG_01_F",       "GMG"],
    ["O_G_GMG_01_high_F",  "GMG"],
    ["I_G_GMG_01_F",       "GMG"],
    ["I_G_GMG_01_high_F",  "GMG"],

    ["B_static_AT_F",      "AT"],
    ["O_static_AT_F",      "AT"],
    ["I_static_AT_F",      "AT"],

    ["B_static_AA_F",      "AA"],
    ["O_static_AA_F",      "AA"],
    ["I_static_AA_F",      "AA"],

    ["B_Mortar_01_F",      "MORTAR"],
    ["O_Mortar_01_F",      "MORTAR"],
    ["I_Mortar_01_F",      "MORTAR"]
];
// --DUWS-UNITCOMP END--

// [_class, _side, _role] call fnc_static_resolve -- _side is "opfor" or "blufor", _role optional.
//
// A row that names its key skips the table and resolves that key; every other caller passes the
// class alone and the table decides. One entry point rather than two, so the fallback and the type
// test below are written once.
fnc_static_resolve = {
    params ["_class", "_side", ["_role", ""]];

    private _key = _role;
    if (_key isEqualTo "") then {
        private _hit = DUWS_staticRoles findIf { (_x select 0) isEqualTo _class };
        if (_hit >= 0) then {
            _key = format ["%1_TURRET_%2", _side, (DUWS_staticRoles select _hit) select 1];
        };
    };
    // A class the table does not carry stands as itself: every Land_* prop the placer is handed, and
    // any static nobody mapped. Passing the row through is what keeps a prefab working meanwhile.
    if (_key isEqualTo "") exitWith { _class };

    // Drawn per object rather than read off the global, so two MG nests in one zone can be different
    // guns -- as they already are for infantry and vehicles.
    private _pick = [_key] call fnc_faction_pick;
    // A role the faction never fields gets its MG nest instead, which is the habit 25 of the shipped
    // BLUFOR files already wrote by hand: an MG nest is the same tactical answer and it keeps the
    // ground inside the faction the file names. This is the hand-authored and pasted path -- the
    // AutoDetect ladders carry a vanilla tail, so a detected faction's key is never empty.
    if (_pick isEqualTo "") then { _pick = [format ["%1_TURRET_HMG", _side]] call fnc_faction_pick; };
    // No static MG either. server_init warns about that side once; the row stands as itself.
    if (_pick isEqualTo "") exitWith { _class };

    // Three systems key off this type test -- the zone manning hook, its crew-out counterpart and the
    // empty-vehicle cleanup's exemption. A mod "static" configured as a car would be placed, never
    // crewed, never crewed out, and swept away as abandoned. Fail closed and keep the placeholder.
    if !(_pick isKindOf "StaticWeapon") exitWith {
        // Once per key: a misconfigured mod static is one line, not one per gun per zone.
        private _warned = missionNamespace getVariable ["DUWS_staticRoleWarned", []];
        if !(_key in _warned) then {
            missionNamespace setVariable ["DUWS_staticRoleWarned", _warned + [_key]];
            ["WARN", "FACTION", format ["%1 holds %2, which is not a StaticWeapon -- %3 stands as itself", _key, _pick, _class]] call fnc_log;
        };
        _class
    };

    _pick
};

// [_row, _origin, _side, _key, _mode] call fnc_static_place -- returns the object.
//
// _row    [class, offsetX, offsetY, offsetZ, dir, role], role optional; the shape both fences use
// _origin [x, y, z]; z is read in "world" mode only
// _key    the site key the object is filed under for teardown
// _mode   "world" when the row states a height, "pos" when its Z means ground
//
// The mode is passed rather than inferred from the Z, because a row genuinely authored at absolute
// zero is indistinguishable from one that omitted the column, and the caller knows which it wrote.
fnc_static_place = {
    params ["_row", "_origin", "_side", "_key", ["_mode", "pos"]];
    // Index 5 is typed, not just defaulted: it is the role on the HQ and FOB fences but the zone
    // prefabs' isWeapon flag, and a boolean reaching _role would be read as a key name. A row that
    // carries the flag falls back to the table lookup, which is what those rows want anyway.
    _row params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0], ["_role", "", [""]]];

    private _world = _mode isEqualTo "world";
    private _pos = [
        (_origin select 0) + _ox,
        (_origin select 1) + _oy,
        if (_world) then { (_origin select 2) + _oz } else { _oz }
    ];

    private _obj = createVehicle [
        [_class, _side, _role] call fnc_static_resolve, _pos, [], 0, "CAN_COLLIDE"
    ];
    [_obj, _key] call fnc_duws_keep;
    // The freeze is what holds an elevated row where the row put it: an unsimulated object does not
    // fall. Global, or every client goes on simulating a gun the server has parked and renders it
    // dropping forever. The caller's crew step thaws it once a gunner is in.
    _obj enableSimulationGlobal false;

    // setDir displaces the object, so the position is written either side of the rotation.
    if (_world) then { _obj setPosWorld _pos } else { _obj setPos _pos };
    _obj setDir _dir;
    if (_world) then { _obj setPosWorld _pos } else { _obj setPos _pos };

    _obj
};
