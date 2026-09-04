// Locality: server. The direct-sighting sweep -- one perception pass. Each player the enemy side knows
// about past the 1.5 observation gate (shared with the artillery gate; never add a second) stamps
// position, group size and the tick, keep-strongest. One knowsAbout per player is a side-wide query, no
// allUnits scan; netId keys the row, so a co-op stack is many rows the grid later merges per cell.
if (!isServer) exitWith {};

{
    private _p = _x;
    if (alive _p && {east knowsAbout _p > 1.5}) then {
        private _key = netId _p;
        private _pos = getPosATL _p;
        _pos set [2, 0];
        private _str = count units group _p;

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
} forEach allPlayers;
