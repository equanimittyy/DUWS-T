// Locality: server. The OPCOM loop thread, spawned once by WARCOM init after zones and civ state exist.
// Phase 1 is perception-only: each tick it perceives, ages and prunes belief, and rebuilds the influence grid from
// current holdings and belief -- no decisions. One cadence, not a fast/strategic split: the decision loop
// adds its scoring and single action commit on this same tick, and the tasking phase steps movement here
// (a finer step as OPCOM_TICK_PERIOD shrinks), so both drop in without restructuring.
if (!isServer) exitWith {};

call fnc_opcom_belief_init;
call fnc_opcom_grid_init;
call fnc_opcom_tasking_init;

while {true} do {
    DUWS_opcom_tick = DUWS_opcom_tick + 1;
    call fnc_opcom_sense;
    call fnc_opcom_recon_sense;
    // OP posts' recon screen, driven on OPCOM's tick beside the belief sensors (defined in fnc_hardpoint_stream).
    call DUWS_fnc_hardpointOPSense;
    call fnc_opcom_decay;
    call fnc_opcom_belief_prune;
    call fnc_opcom_grid_rebuild;

    // Step the taskings after the grid it reads is fresh. Fault-contained so a Phase 3 bug logs and the
    // perception thread lives -- the grid/belief half must keep running even if the tasking half throws.
    try { call fnc_opcom_task_step } catch { ["ERROR", "OPCOM", format ["task step threw: %1", _exception]] call fnc_log };

    // A missing line means the tick threw before here and the loop is dead; friCells/eneCells 0
    // means the grid holds no force this tick; belief is the count of live sighting stamps; fresh is the
    // groups an observer sensed this tick (0 while belief>0 means everything is being held on last-seen).
    ["DEBUG", "OPCOM", format ["grid tick=%1 w=%2 friCells=%3 eneCells=%4 maxFri=%5 maxEne=%6 belief=%7 fresh=%8",
        DUWS_opcom_tick, DUWS_opcom_grid_w,
        {_x > 0.05} count DUWS_opcom_grid_fri,
        {_x > 0.05} count DUWS_opcom_grid_ene,
        selectMax DUWS_opcom_grid_fri, selectMax DUWS_opcom_grid_ene,
        count DUWS_opcom_belief_pos, DUWS_opcom_dbg_fresh]] call fnc_log;

    sleep OPCOM_TICK_PERIOD;
};
