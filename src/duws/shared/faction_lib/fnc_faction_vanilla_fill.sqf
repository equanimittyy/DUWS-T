// Locality: server -- called from server/server_init.sqf after fnc_faction_backfill, and it writes
// the role globals every spawner reads.
//
// The vanilla NATO/CSAT catch-all for a key a faction left empty -- or pointing at a class this
// install lacks -- on any path that does not ladder through fnc_faction_resolve: a hand-written
// preset faction file or a pasted CUSTOM one. Those assign only the keys they name, so a role the
// file omits stays "" (fnc_BLUFOR_faction_init clears every key first) and a role pointed at an
// absent mod class holds a name no createUnit/createVehicle can raise -- both reach a spawner as the
// engine's MISSING placeholder. AutoDetect never needs this: its resolver already fell each key back
// to the same schema stand-in this pass uses.
//
// Ordered after backfill on purpose, so a same-side borrow (tier 1, yellow) wins over the vanilla
// stand-in (tier 2, red) for the shared-roster keys backfill covers; this only fills what is still
// empty. A stand-in the install itself lacks is left empty and logged -- exactly as fnc_faction_resolve
// leaves a role nothing survives for, since a class that cannot spawn is no better than "".

fnc_faction_vanilla_fill = {
    params ["_side"];
    {
        _x params ["_key", "_grp", "_kind", "_req", "_default"];
        private _cur = missionNamespace getVariable [_key, ""];
        private _have = [if (_cur isEqualType []) then {_cur} else {[_cur]}, _kind] call fnc_faction_keep;
        if (_have isEqualTo [] && {_default != ""}) then {
            private _kept = [[_default], _kind] call fnc_faction_keep;
            if (_kept isEqualTo []) then {
                ["WARN", "FACTION", format ["%1 empty and its vanilla default %2 is absent -- role left unfilled", _key, _default]] call fnc_log;
            } else {
                missionNamespace setVariable [_key, _kept, true];
                // Same red the confirmation screen paints a resolved stand-in, so a preset's gap is
                // visible rather than passed off as the faction's own choice.
                missionNamespace setVariable [format ["DUWS_factionTier_%1", _key], 2];
                ["INFO", "FACTION", format ["%1 empty -- filled with vanilla stand-in %2", _key, _default]] call fnc_log;
            };
        };
    } forEach ([_side] call fnc_faction_schema);
};
