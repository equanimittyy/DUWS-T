// Locality: server -- pools are server-local (see fnc_faction_pools) and every spawn path that
// draws from one runs on the server, so this rebuilds them where they are used and never has to
// broadcast an array.
//
// Runs twice: at the preview, so the confirmation screen shows the pool a spawn will draw from, and
// again at the commit, after fnc_faction_apply_locked lays the player's confirmed table over the role
// globals so the edits are widened too. Idempotent, so the double run costs only the second parse.
// One pass closes two versions of the same shortfall -- a role holding one class where its faction
// fields several:
//
//   A hand-written faction file assigns one classname per role, so every zone it fills fields the
//   identical man and vehicle. It never had the per-spawn variety AutoDetect gives.
//
//   AutoDetect does build a pool per role, but the confirmation screen runs on a client, which only
//   ever receives the single representative fnc_faction_pools_publish broadcasts, not the
//   server-local pool. So the table the player confirms carries one class for every role they did
//   not open by hand, and fnc_faction_apply_locked republishes each as a pool of one.
//
// Both are fixed by expanding each role's final representative back into its faction's role bucket.
// Driven off the representative rather than by re-running resolution: an edited key expands the
// player's pick, an un-edited one expands what resolution chose, and either way the representative
// stays the pool's first entry, so nothing the player confirmed is overridden. fnc_faction_pool_for_class
// is the same classifier a key edit uses, so an edited role and an augmented one build their pool the
// one way -- for an edited key the expansion is idempotent.
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
                private _pool = [_class, _parsed] call fnc_faction_pool_for_class;
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
