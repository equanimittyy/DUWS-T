// Locality: server. The absence write: each tick, before the rebuild, drop the belief row of any group
// gone as a threat so a destroyed or drained force stops depositing a phantom into the enemy grid. Runs
// before the rebuild, so a cleared row is never deposited that tick.
//
// Poll, not a Killed handler: BLUFOR are player groups, local to their clients in co-op, where a
// server-added Killed handler is unreliable (docs/info/architecture/arma_engine_gotchas.md); groupFromNetId
// is a server-authoritative read for a group local to any machine.
//
// Test alive-count, not units-empty: dead bodies linger in `units` until the engine clears them
// (fnc_garrison_reserve.sqf:205 filters `alive` for the same reason), so units-empty alone would miss a
// fresh wipe. Zero-alive also covers a merge-drain and a deleted group -- one test, three cases.
if (!isServer) exitWith {};

// High-to-low: a forward deleteAt shifts the unvisited rows down and skips one.
for "_i" from (count DUWS_opcom_belief_key - 1) to 0 step -1 do {
    private _key = DUWS_opcom_belief_key select _i;
    // Only group-netId rows may resolve as groups: later sensors key rows by zone/FOB index or "HQ", which
    // groupFromNetId would drop as bogus orphans. A group netId is an "ent:id" string -- the colon
    // discriminates it from those.
    if (_key isEqualType "" && {(_key find ":") >= 1}) then {
        private _g = groupFromNetId _key;
        if (isNull _g || {({alive _x} count units _g) == 0}) then {
            [_i] call fnc_opcom_belief_deleteAt;
        };
    };
};
