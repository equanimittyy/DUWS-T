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
    // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup). _stage names the
    // stage in the catch so the RPT says what broke; the tick's work is dropped and retried next pass.
    DUWS_opcom_tick = DUWS_opcom_tick + 1;
    private _stage = "";
    try {
        _stage = "sense";    call fnc_opcom_sense;
        _stage = "recon";    call fnc_opcom_recon_sense;
        // OP posts' recon screen, driven on OPCOM's tick beside the belief sensors (defined in fnc_hardpoint_stream).
        _stage = "opsense";  call DUWS_fnc_hardpointOPSense;
        _stage = "decay";    call fnc_opcom_decay;
        _stage = "prune";    call fnc_opcom_belief_prune;
        _stage = "grid";     call fnc_opcom_grid_rebuild;
        // Task step after the rebuild, so it reads the grid this tick just refreshed.
        _stage = "taskstep"; call fnc_opcom_task_step;

        // friCells/eneCells: cells holding force; belief: live sighting stamps; fresh: groups sensed this
        // tick (0 while belief>0 means everything held on last-seen).
        _stage = "debuglog";
        ["DEBUG", "OPCOM", format ["grid tick=%1 w=%2 friCells=%3 eneCells=%4 maxFri=%5 maxEne=%6 belief=%7 fresh=%8",
            DUWS_opcom_tick, DUWS_opcom_grid_w,
            {_x > 0.05} count DUWS_opcom_grid_fri,
            {_x > 0.05} count DUWS_opcom_grid_ene,
            selectMax DUWS_opcom_grid_fri, selectMax DUWS_opcom_grid_ene,
            count DUWS_opcom_belief_pos, DUWS_opcom_dbg_fresh]] call fnc_log;
    } catch {
        ["ERROR", "OPCOM", format ["tick %1 threw in %2, thread held alive: %3", DUWS_opcom_tick, _stage, _exception]] call fnc_log;
    };

    sleep OPCOM_TICK_PERIOD;
};
