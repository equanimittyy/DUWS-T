// Locality: server. Drops belief stamps older than OPCOM_BELIEF_EXPIRE ticks. Runs once per strategic
// phase, after DUWS_opcom_tick is bumped. The linear weight falloff between FRESH and EXPIRE is the grid
// rebuild's job, so decay only expires -- it never reweights.
if (!isServer) exitWith {};

// High-to-low: a forward deleteAt would shift the unvisited rows down and skip one.
for "_i" from (count DUWS_opcom_belief_key - 1) to 0 step -1 do {
    if ((DUWS_opcom_tick - (DUWS_opcom_belief_time select _i)) > OPCOM_BELIEF_EXPIRE) then {
        DUWS_opcom_belief_key  deleteAt _i;
        DUWS_opcom_belief_pos  deleteAt _i;
        DUWS_opcom_belief_time deleteAt _i;
        DUWS_opcom_belief_str  deleteAt _i;
    };
};
