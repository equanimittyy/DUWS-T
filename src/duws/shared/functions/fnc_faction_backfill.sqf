// Locality: server -- called from server/server_init.sqf once both sides have resolved, and it
// writes the role globals every spawner reads.
//
// Fills a role key the faction left empty from a role the same side does field. A shared team
// roster names a role bare and either side supplies the man, so a row naming AA_SOLDIER_X has to
// mean something on BLUFOR too -- and no BLUFOR faction file has ever defined one. Editing a class
// into 122 hand-written files would be a guess per file that nothing checks; borrowing states the
// degradation once, in the open, and logs it every time it fires.
//
// This is what fnc_static_resolve already does by hand for a turret role a faction never fields,
// where the answer is that side's MG nest. Statics keep their own rung: it runs per object and
// carries a StaticWeapon type test that a load-time pass cannot do.

// Every rung names a role the faction file itself defines, never another row's target. That is what
// makes the pass order-independent: AA borrowing from AT while AT borrows from AA would resolve
// differently depending on which ran first, and to nothing at all on a side defining neither.
// --DUWS-UNITCOMP BEGIN name="Role fallbacks" kind=team row="role, borrows from" fields="role, borrows from" prefix=blufor_,opfor_--
DUWS_roleFallbacks = [
    ["AA_SOLDIER_X",     ["SPECOPS_AA_X", "LAT_SOLDIER_X", "SOLDIER_X"]],
    ["AT_SOLDIER_X",     ["SPECOPS_HAT_X", "LAT_SOLDIER_X", "SOLDIER_X"]],
    ["SNIPER_SOLDIER_X", ["SPECOPS_SNIPER_X", "MARK_SOLDIER_X", "SOLDIER_X"]],
    ["MEDIC_X",          ["SPECOPS_MEDIC_X", "SOLDIER_X"]]
];
// --DUWS-UNITCOMP END--

// The whole pool is carried across, not one class off the top of it: the source key on an
// AutoDetected faction holds every anti-air man the mod fields, and collapsing that to one here
// would make the borrowed role the one slot in the composition that never varies.
fnc_faction_backfill = {
    params ["_side"];
    {
        _x params ["_role", "_rungs"];
        private _key = format ["%1_%2", _side, _role];
        // "" covers both shapes of missing: a hand-written file has no line for the key at all, and
        // fnc_faction_resolve writes [] when no detection bucket held anything.
        if (([_key] call fnc_faction_pick) isEqualTo "") then {
            private _from = "";
            private _took = [];
            {
                private _src = format ["%1_%2", _side, _x];
                private _v = missionNamespace getVariable [_src, ""];
                private _pool = (if (_v isEqualType []) then { _v } else { [_v] })
                    select { _x isEqualType "" && {_x != ""} };
                if !(_pool isEqualTo []) exitWith { _from = _src; _took = _pool };
            } forEach _rungs;

            if (_took isEqualTo []) then {
                ["WARN", "FACTION", format ["%1 is empty and no rung under it resolved -- a roster naming it raises one man short", _key]] call fnc_log;
            } else {
                missionNamespace setVariable [_key, _took, true];
                ["INFO", "FACTION", format ["%1 borrowed from %2", _key, _from]] call fnc_log;
            };
        };
    } forEach DUWS_roleFallbacks;
};
