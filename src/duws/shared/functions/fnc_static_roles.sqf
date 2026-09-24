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
    ["I_Mortar_01_F",      "MORTAR"],

    // The one role whose piece is a vehicle rather than a turret, so it resolves through a different
    // key and past the StaticWeapon gate below. Self-propelled guns and rocket artillery share it:
    // both answer a fire mission, and no composition cares which silhouette the faction fields.
    ["B_MBT_01_arty_F",    "ARTY"],
    ["O_MBT_02_arty_F",    "ARTY"],
    ["I_Truck_02_MRL_F",   "ARTY"],
    ["B_MBT_01_mlrs_F",    "ARTY"]
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
            private _token = (DUWS_staticRoles select _hit) select 1;
            _key = if (_token isEqualTo "ARTY") then { format ["%1_ARTY_X", _side] }
                   else { format ["%1_TURRET_%2", _side, _token] };
        };
    };
    // A class the table does not carry stands as itself: every Land_* prop the placer is handed, and
    // any static nobody mapped. Passing the row through is what keeps a prefab working meanwhile.
    if (_key isEqualTo "") exitWith { _class };

    // Tested against the key rather than the table, so a row naming its own key reaches this branch
    // too. Neither guard below fits a gun that is a vehicle: an MG substitute would stand a machine
    // gun where a battery belongs, and the StaticWeapon test refuses every artillery piece there is.
    private _arty = _key isEqualTo (format ["%1_ARTY_X", _side]);

    // Drawn per object rather than read off the global, so two MG nests in one zone can be different
    // guns -- as they already are for infantry and vehicles.
    private _pick = [_key] call fnc_faction_pick;
    // A role the faction never fields gets its MG nest instead, which is the habit 25 of the shipped
    // BLUFOR files already wrote by hand: an MG nest is the same tactical answer and it keeps the
    // ground inside the faction the file names. This is the hand-authored and pasted path -- the
    // AutoDetect ladders carry a vanilla tail, so a detected faction's key is never empty.
    if (_pick isEqualTo "" && {!_arty}) then { _pick = [format ["%1_TURRET_HMG", _side]] call fnc_faction_pick; };
    // No static MG either. server_init warns about that side once; the row stands as itself.
    if (_pick isEqualTo "") exitWith { _class };

    // Three systems key off this type test -- the zone manning hook, its crew-out counterpart and the
    // empty-vehicle cleanup's exemption. A mod "static" configured as a car would be placed, never
    // crewed, never crewed out, and swept away as abandoned. Fail closed and keep the placeholder.
    if (!_arty && {!(_pick isKindOf "StaticWeapon")}) exitWith {
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

// [_class] call fnc_static_baseZ -- how far the model's base sits below its origin (<= 0), read once
// per class off a throwaway probe and cached. boundingBoxReal needs a spawned object, so a class that
// never spawns is never probed and one placed many times is measured once.
fnc_static_baseZ = {
    params ["_class"];
    private _cache = missionNamespace getVariable ["DUWS_staticBaseZ", createHashMap];
    if (_class in _cache) exitWith { _cache get _class };
    private _probe = createVehicle [_class, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    private _z = (boundingBoxReal _probe select 0) select 2;
    deleteVehicle _probe;
    _cache set [_class, _z];
    missionNamespace setVariable ["DUWS_staticBaseZ", _cache];
    _z
};

// [_row, _origin, _side, _key, _mode, _resolved] call fnc_static_place -- returns the object.
//
// _row      [class, offsetX, offsetY, offsetZ, dir, role], role optional
// _origin   [x, y]; z unused -- in "world" mode a weapon's height comes from the terrain under the gun
// _key      the site key the object is filed under for teardown
// _mode     "world" when the row states a height, "pos" when its Z means ground
// _resolved a class the caller already drew, so several rows share one draw; "" draws here
//
// The mode is passed rather than inferred from the Z, because a row genuinely authored at absolute
// zero is indistinguishable from one that omitted the column, and the caller knows which it wrote.
fnc_static_place = {
    params ["_row", "_origin", "_side", "_key", ["_mode", "pos"], ["_resolved", ""]];
    // Index 5 is the isWeapon flag on a composition row, and "" on the HQ's own gun rows. Neither is a
    // role name -- every row resolves by class through the table below -- but the bool must not reach
    // _role, where it would be read as a key name. Coerced by hand rather than by a [""] params
    // template: that template rejects the bool the same way but logs the mismatch to the RPT before
    // falling back, once per gun per site, spamming an expected case. The _role override stays for a
    // caller that wants to force one.
    _row params ["_class", "_ox", "_oy", ["_oz", 0], ["_dir", 0], ["_role", ""]];
    if !(_role isEqualType "") then { _role = "" };

    private _world = _mode isEqualTo "world";
    private _px = (_origin select 0) + _ox;
    private _py = (_origin select 1) + _oy;
    // A weapon's Z is height above the ground under the gun, not above the site centre: the two drop
    // apart on a slope, so a gun measured from the centre floats off its perch. Per-gun terrain matches
    // how the ground pass snaps each prop to its own x,y. Clamped at 0 so a coastal gun measures from
    // the sea, not the seabed -- the same clamp the prefabs apply to the centre height.
    private _pos = [_px, _py, if (_world) then { ((getTerrainHeightASL [_px, _py]) max 0) + _oz } else { _oz }];

    if (_resolved isEqualTo "") then { _resolved = [_class, _side, _role] call fnc_static_resolve };
    private _obj = createVehicle [_resolved, _pos, [], 0, "CAN_COLLIDE"];
    [_obj, _key] call fnc_duws_keep;
    // The freeze is what holds an elevated row where the row put it: an unsimulated object does not
    // fall. Global, or every client goes on simulating a gun the server has parked and renders it
    // dropping forever. The caller's crew step thaws it once a gunner is in.
    _obj enableSimulationGlobal false;

    // setDir displaces the object, so the position is written either side of the rotation.
    if (_world) then { _obj setPosWorld _pos } else { _obj setPos _pos };
    _obj setDir _dir;
    if (_world) then { _obj setPosWorld _pos } else { _obj setPos _pos };

    // The row's Z seats the authored placeholder's model origin. A swap to a gun whose base sits lower
    // under that origin -- a ZU-23 for the static AA -- drives the new base underground (or floats a
    // shorter one). Shift the resolved gun so its base rests where the placeholder's would have: the
    // row's real elevation holds, so a ground gun stays grounded and a rampart/roof gun stays perched.
    if (_world && {!(_resolved isEqualTo _class)}) then {
        private _delta = ([_class] call fnc_static_baseZ) - ([_resolved] call fnc_static_baseZ);
        _obj setPosWorld ((getPosWorld _obj) vectorAdd [0, 0, _delta]);
    };

    _obj
};
