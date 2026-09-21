// Locality: server -- pools are server-local (see fnc_faction_pools) and every spawn path that
// draws from one runs on the server, so this rebuilds them where they are used and never has to
// broadcast an array.
//
// Runs at the preview, so the confirmation screen shows the pool a spawn will draw from. At the commit
// it runs again only when no table was locked (the debug quickstart): a locked table already carries
// every row's whole pool, and a second pass would rebuild each from its representative, undoing the
// player's list edits.
//
// A hand-written faction file assigns one classname per role, so every zone it fills would field the
// identical man and vehicle. Each role's representative is expanded into the rung of the role's ladder
// that holds it (fnc_faction_pool_for_role) and kept first, so the class resolution chose stays the
// role's main. An AutoDetect side comes out as it resolved, since its ladder is the same table.
//
// A pasted CUSTOM faction is left alone: it never built a pool to collapse, and its per-role list is
// the paster's own, not a curator's single pick asking to be widened.

if (!isServer) exitWith {};

private _parseCache = createHashMap;

{
    private _side = _x;
    private _token = missionNamespace getVariable [format ["%1_FactionFile_X", toUpper _side], ""];
    if (_token != "CUSTOM") then {
        private _keys = ([_side] call fnc_faction_schema) apply { _x select 0 };
        {
            private _key = _x;
            private _cur = missionNamespace getVariable [_key, ""];
            // apply_locked collapses every global to its representative; take the front defensively
            // in case one still arrives as an array from another path.
            private _class = if (_cur isEqualType []) then { _cur param [0, ""] } else { _cur };
            if (_class != "") then {
                private _faction = getText (configFile >> "CfgVehicles" >> _class >> "faction");
                private _parsed = _parseCache get _faction;
                if (isNil "_parsed") then {
                    _parsed = [_faction] call fnc_parseFaction;
                    _parseCache set [_faction, _parsed];
                };
                private _pool = [_key, _class, _parsed] call fnc_faction_pool_for_role;
                // Only when detection found siblings: a one-entry pool is what fnc_faction_pick
                // already makes of a plain string, so writing the array back would just churn.
                if (count _pool > 1) then { missionNamespace setVariable [_key, _pool]; };
            };
        } forEach _keys;

        // Rebuilds DUWS_factionPool_<key> from the arrays just written and re-collapses each global
        // to its representative, exactly as the resolve path does.
        [_keys] call fnc_faction_pools_publish;
    };
} forEach ["blufor", "opfor"];

["INFO", "FACTION", "Faction pools augmented from detection buckets."] call fnc_log;
