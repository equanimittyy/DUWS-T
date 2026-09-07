// Locality: server. The direct-sighting sweep, one perception pass. A BLUFOR group's leader stamps its
// position, the group's threat (each AI one, each human OPCOM_PLAYER_WORTH) and the tick -- but only on an
// acquisition: knowsAbout past the 1.5 gate (shared with the artillery gate; never add a second) AND not
// falling since last tick. knowsAbout lags high through the decay tail after line-of-sight breaks, so a
// level-only gate would keep stamping the live position of an unwatched target and jump it to HQ on a fast
// travel; gating on the rising/steady edge writes only a genuine sighting, and a falling scalar freezes the
// stamp at last-seen for decay to carry down (docs/info/architecture/arma_engine_gotchas.md). One knowsAbout
// per group, on the leader -- a member seen while the leader is hidden is missed, accepted for the common
// player-leads-squad case. netId keys the row, so the grid merges rows per cell. Zone-flip and AoI sensors
// write belief through their own hooks, not here.
if (!isServer) exitWith {};

{
    private _grp = _x;
    private _ldr = leader _grp;
    if (!isNull _ldr && {alive _ldr}) then {
        private _key = netId _grp;
        private _ka = east knowsAbout _ldr;
        // Prior tick's knowsAbout, tracked for every group (even below the gate) so the edge survives a
        // spell out of contact. Transient map, rebuilt on loop start; stale keys are harmless.
        private _prev = DUWS_opcom_ka_prev getOrDefault [_key, 0];
        DUWS_opcom_ka_prev set [_key, _ka];

        if (_ka > 1.5 && {_ka >= _prev}) then {
            private _pos = getPosATL _ldr;
            _pos set [2, 0];
            private _players = {isPlayer _x} count units _grp;
            private _str = ((count units _grp) - _players) + OPCOM_PLAYER_WORTH * _players;

            private _i = DUWS_opcom_belief_key findIf {_x isEqualTo _key};
            if (_i < 0) then {
                DUWS_opcom_belief_key  pushBack _key;
                DUWS_opcom_belief_pos  pushBack _pos;
                DUWS_opcom_belief_time pushBack DUWS_opcom_tick;
                DUWS_opcom_belief_str  pushBack _str;
            } else {
                // Fresh acquisition supersedes -- overwrite outright, no keep-strongest.
                DUWS_opcom_belief_pos  set [_i, _pos];
                DUWS_opcom_belief_time set [_i, DUWS_opcom_tick];
                DUWS_opcom_belief_str  set [_i, _str];
            };
        };
    };
} forEach (allGroups select {side _x == west});
