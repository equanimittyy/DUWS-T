// Locality: server. Drop row _i from all four parallel belief arrays at once, keeping them index-aligned.
// Callers walking the store to prune rows must iterate high-to-low, since this shifts every later row down.

params ["_i"];

DUWS_opcom_belief_key  deleteAt _i;
DUWS_opcom_belief_pos  deleteAt _i;
DUWS_opcom_belief_time deleteAt _i;
DUWS_opcom_belief_str  deleteAt _i;
