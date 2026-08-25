// Locality: server -- faction generation is server-only (init_hq/fnc_BLUFOR_faction_init.sqf:1) and
// every path that draws a class from a pool raises units, which only the server does.
//
// Faction detection finds several classnames for most roles: every APC a faction defines, every
// rifleman. The role globals hold *one* classname, because every spawner hands them straight to
// BIS_fnc_spawnGroup or createVehicle. Something has to collapse many to one.
//
// This publishes both halves: the pool under DUWS_factionPool_<role>, and a stable representative in
// the global itself so the two hundred-odd sites that read opfor_SOLDIER_X directly keep working.
// Variety then comes from picking out of the pool at the moment something spawns.
//
// What this replaces: a permanent thread per role (38 OPFOR, 34 BLUFOR) waking every 300 s to re-pick
// and publicVariable its answer for the rest of the campaign -- wrong three ways beyond the cost. The
// global holds one value at a time, so zones raised in the same five-minute window fielded the
// *identical* APC while zones six minutes apart differed: variety across time, not the per-moment
// variety a player actually sees. It let a faction's identity drift, the one thing auto-detection
// exists to establish. And it cost seventy permanent scripts and seventy network writes every five
// minutes, for values only ever read at the instant something spawns.

// The front half of the same job lives here too: fnc_faction_resolve turns a detection bucket into
// the key's value, fnc_faction_pools_publish turns that value into a pool plus a representative.

// A role key holds classes a spawner hands straight to createUnit or createVehicle, so what
// reaches it must exist and be the right sort of thing. Kind comes from fnc_faction_schema -- the
// one place recording which CfgVehicles branch a key may hold -- rather than from the bucket the
// class arrived in, which is what misplaces classes when a mod names its editor subcategories its
// own way and detection falls back to guessing by parent class.
fnc_faction_keep = {
    params ["_classes", "_kind"];
    _classes select {
        // scope must read 2 (public): a curator-import variant carries scopeCurator 2 but scope < 2,
        // so it clears detection's Zeus gate yet createVehicle/createUnit refuses it as an abstract
        // type. Gated here, the one funnel every source passes through, so no pool can field one.
        _x isEqualType "" && {_x != ""} && {isClass (configFile >> "CfgVehicles" >> _x)}
            && {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2} && {
            switch (_kind) do {
                case "man":     { _x isKindOf "CAManBase" };
                case "static":  { _x isKindOf "StaticWeapon" };
                case "vehicle": { !(_x isKindOf "CAManBase") };
                default         { true };   // kind unknown: existence is all this can check
            }
        }
    }
};

// Resolve one role key: the first ladder rung with anything left after the kind gate wins, and the
// fallback -- the vanilla stand-in the role degrades to -- carries a faction that fields nothing for
// the role at all. A call omitting the fallback takes the key's vanillaDefault from the schema, the
// one place that class is written, so the AutoDetect tables never spell a stand-in a second time.
//
// The ladder is graded -- one bucket per rung -- rather than the summed pairs the faction files
// passed before ([_hat, _lat + _aa, _infantry]). Summing rated anti-air men equal to light AT for
// an anti-tank slot, so which one a faction fielded came down to config order. Separate rungs say
// what the role degrades through, in order.
//
// [] is a legitimate answer: publish below leaves the key empty, fnc_faction_pick returns "" and
// fnc_factionRoles drops it. Inventing a class here would hide a missing role behind a unit that
// spawns, which is worse than a role the faction visibly never fields.
fnc_faction_resolve = {
    params ["_key", "_ladder", ["_fallback", []]];

    private _side = if (_key select [0, 6] isEqualTo "opfor_") then {"opfor"} else {"blufor"};
    private _row = ([_side] call fnc_faction_schema) select { (_x select 0) isEqualTo _key };
    // A key with no schema row is misspelled. Resolve it ungated rather than empty it silently,
    // and say so: nothing else in the boot compares these names against the schema.
    private _kind = "";
    if (_row isEqualTo []) then {
        ["WARN", "FACTION", format ["%1 is not in the faction schema -- resolved without a kind check", _key]] call fnc_log;
    } else {
        _kind = (_row select 0) select 2;
        // Omitted fallback defaults to the schema's vanilla stand-in for the key. An explicit []
        // cannot tell "caller passed nothing" from "caller wants no stand-in", but nothing wants the
        // latter -- every ladder ends in the vanilla class, so the default is always what was meant.
        if (_fallback isEqualTo []) then { _fallback = (_row select 0) select 4; };
    };

    private _out = [];
    // How far the answer fell from the faction's own first choice, for the confirmation screen to
    // colour the row: 0 the primary bucket (white), 1 a lower rung the faction still fills (yellow),
    // 2 the vanilla stand-in or nothing left at all (red). The stand-in is kept -- the campaign still
    // needs a class -- but it is flagged as the worst case so a gap in the faction is not hidden.
    private _tier = 2;
    {
        private _kept = [if (_x isEqualType "") then {[_x]} else {_x}, _kind] call fnc_faction_keep;
        if !(_kept isEqualTo []) exitWith {
            _out = _kept;
            _tier = switch true do {
                case (_forEachIndex == 0):            {0};
                case (_forEachIndex < count _ladder): {1};
                default                               {2};   // the appended vanilla _fallback
            };
        };
    } forEach (_ladder + [_fallback]);

    missionNamespace setVariable [_key, _out];
    missionNamespace setVariable [format ["DUWS_factionTier_%1", _key], _tier];
    _out
};

// A pool is a random draw per spawn, restricted to vehicles: a faction's interchangeable vehicle
// variants are worth randomising, but infantry are deliberately held to a single representative so
// every zone fields the one confirmed rifleman rather than a spread of variants. A static role holds
// one canonical piece anyway, and randomising there risks an import/proxy variant that clears the
// detection scope gate yet cannot be createVehicle'd, standing the emplacement up gunless. Infantry,
// statics, and any key the schema does not carry therefore collapse to the representative with no
// pool, so fnc_faction_pick returns that one class. Kind comes from the schema, its one record.
fnc_faction_poolable_keys = {
    if (isNil "DUWS_faction_poolableKeys") then {
        DUWS_faction_poolableKeys = [];
        {
            { if ((_x select 2) isEqualTo "vehicle") then { DUWS_faction_poolableKeys pushBack (_x select 0); }; }
                forEach ([_x] call fnc_faction_schema);
        } forEach ["blufor", "opfor"];
    };
    DUWS_faction_poolableKeys
};

// The representative is the first entry rather than a random one: detection hands back classes in
// the mod's own declaration order, which puts a faction's mainstay ahead of its variants, and a
// stable answer is what makes the request menu and the readouts repeatable.
fnc_faction_pools_publish = {
    params ["_names"];
    private _poolable = call fnc_faction_poolable_keys;
    {
        private _role = _x;
        private _data = missionNamespace getVariable _role;
        if (!isNil "_data") then {
            private _pool = if (_data isEqualType []) then { _data } else { [_data] };
            _pool = _pool select { _x isEqualType "" && {_x != ""} };
            if !(_pool isEqualTo []) then {
                private _poolVar = format ["DUWS_factionPool_%1", _role];
                // Cleared, not skipped, for a non-poolable role: a Back-and-re-pick may have left a
                // static pool from a prior round, and a stale one would keep fnc_faction_pick
                // randomising a role this pass means to hold single.
                if (_role in _poolable) then {
                    missionNamespace setVariable [_poolVar, _pool];
                } else {
                    missionNamespace setVariable [_poolVar, nil];
                };
                missionNamespace setVariable [_role, _pool select 0, true];
            };
        };
    } forEach _names;
};

// One classname for a role, drawn at the moment of use. Called by the spawn funnels rather than by
// every reader: two zones raised in the same second field different vehicles -- the variety a player
// actually sees -- while infantry and every other single role hand back their representative.
//
// Falls back to the global for a role with no pool (every hand-written faction file's plain-string
// roles), and "" for one the faction never defined at all -- fnc_factionRoles drops the empty answer,
// same reasoning as fnc_faction_resolve above.
fnc_faction_pick = {
    params ["_name"];
    private _pool = missionNamespace getVariable [format ["DUWS_factionPool_%1", _name], []];
    if !(_pool isEqualTo []) exitWith { selectRandom _pool };
    private _v = missionNamespace getVariable [_name, ""];
    if !(_v isEqualType []) exitWith { _v };
    if (_v isEqualTo []) exitWith { "" };
    // No pool var yet an array global: a non-poolable role (a static) whose global a Back-and-re-pick
    // left un-collapsed. Variety is the pool var's job alone; the gate in fnc_faction_pools_publish
    // clears it for a static on purpose (see fnc_faction_poolable_keys above), so the representative
    // (first entry) is the answer here too, never a random draw.
    _v select 0
};
