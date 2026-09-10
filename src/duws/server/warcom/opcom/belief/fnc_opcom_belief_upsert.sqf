// Locality: server. Single writer for the belief store's four parallel rows (key/pos/time/str): insert a
// new subject or refresh an existing one in place, stamped at the current tick. Keying by subject here is
// what keeps the four arrays index-aligned -- every sensor writes through this, so none can push one row
// and forget another.

params ["_key", "_pos", "_str"];

private _i = DUWS_opcom_belief_key findIf { _x isEqualTo _key };
if (_i < 0) then {
    DUWS_opcom_belief_key  pushBack _key;
    DUWS_opcom_belief_pos  pushBack _pos;
    DUWS_opcom_belief_time pushBack DUWS_opcom_tick;
    DUWS_opcom_belief_str  pushBack _str;
} else {
    DUWS_opcom_belief_pos  set [_i, _pos];
    DUWS_opcom_belief_time set [_i, DUWS_opcom_tick];
    DUWS_opcom_belief_str  set [_i, _str];
};
