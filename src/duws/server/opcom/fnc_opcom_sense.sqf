// Locality: server. The direct-sighting sweep -- one perception pass. Each BLUFOR group whose leader the
// enemy side knows about past the 1.5 observation gate (shared with the artillery gate; never add a
// second) stamps the leader's position, the group's threat and the tick, keep-strongest. Threat counts
// each AI in the group as one man and each human as OPCOM_PLAYER_WORTH -- a player weighs more. One
// knowsAbout per group (on the leader -- a member seen while the leader is hidden is missed, an accepted
// approximation for the common player-leads-squad case); netId keys the row, so the grid merges rows per
// cell. Zone-flip and AoI sensors write belief through their own hooks, not here.
if (!isServer) exitWith {};

{
    private _grp = _x;
    private _ldr = leader _grp;
    if (!isNull _ldr && {alive _ldr} && {east knowsAbout _ldr > 1.5}) then {
        private _key = netId _grp;
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
            private _stale = (DUWS_opcom_tick - (DUWS_opcom_belief_time select _i)) >= OPCOM_BELIEF_FRESH;
            if (_str >= (DUWS_opcom_belief_str select _i) || _stale) then {
                DUWS_opcom_belief_pos  set [_i, _pos];
                DUWS_opcom_belief_time set [_i, DUWS_opcom_tick];
                DUWS_opcom_belief_str  set [_i, _str];
            };
        };
    };
} forEach (allGroups select {side _x == west});
