// Locality: server. The OPCOM loop thread, spawned once by WARCOM init after zones and civ state exist.
// Phase 1 is perception-only: each tick it perceives, ages belief and rebuilds the influence grid from
// current holdings and belief -- no decisions. One cadence, not a fast/strategic split: Phase 2 adds its
// scoring and single action commit on this same tick, and Phase 4 steps movement here (a finer step as
// OPCOM_TICK_PERIOD shrinks), so both drop in without restructuring.
if (!isServer) exitWith {};

call fnc_opcom_belief_init;
call fnc_opcom_grid_init;

while {true} do {
    DUWS_opcom_tick = DUWS_opcom_tick + 1;
    call fnc_opcom_sense;
    call fnc_opcom_decay;
    call fnc_opcom_grid_rebuild;
    sleep OPCOM_TICK_PERIOD;
};
