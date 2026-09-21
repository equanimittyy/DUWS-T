// Locality: server -- reads the resolved role globals and their spawn pools, both server-set.
//
// The classes the DUWS role keys of one kind (fnc_faction_schema's man | vehicle | static) resolve to
// for a side: each key's published representative plus every class in its spawn pool. This is "the
// units in the list" -- distinct from the config-faction sweep in fnc_create_ammo_lists, which also
// reaches faction units no DUWS key names. Enumerating the keys directly is what catches a key a
// custom faction overrode to a unit of a different faction than the sweep's seed units detect.

params [["_side", "blufor"], ["_kind", "man"]];

private _out = [];
{
    if ((_x select 2) isEqualTo _kind) then {
        private _key = _x select 0;
        private _val = missionNamespace getVariable [_key, ""];
        // `+`, not append: a getVariable on an array key returns the stored array by reference, so
        // appending the pool to it would mutate the role global itself.
        private _classes = (if (_val isEqualType []) then { _val } else { [_val] })
            + (missionNamespace getVariable [format ["DUWS_factionPool_%1", _key], []]);
        {
            if (_x isEqualType "" && {_x != ""} && {isClass (configFile >> "CfgVehicles" >> _x)}) then {
                _out pushBackUnique _x;
            };
        } forEach _classes;
    };
} forEach ([_side] call fnc_faction_schema);
_out
