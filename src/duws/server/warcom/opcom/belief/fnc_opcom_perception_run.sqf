// Locality: server. The OPCOM loop thread, spawned once by WARCOM init after zones and civ state exist.
// One cadence, not a fast/strategic split: perception, the tasking step and the pick share this tick, and a shorter
// OPCOM_TICK_PERIOD steps movement finer rather than breaking it.
if (!isServer) exitWith {};

call fnc_opcom_belief_init;
call fnc_opcom_grid_init;
call fnc_opcom_tasking_init;

while {true} do {
    // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup). _stage names the
    // stage in the catch so the RPT says what broke; the tick's work is dropped and retried next pass.
    DUWS_opcom_tick = DUWS_opcom_tick + 1;
    private _stage = "";
    // Per-stage wall time for the DEBUG line. Scheduled, so a figure includes any time the scheduler held the stage.
    private _dbg = duws_log_level >= 4;
    private _ms = [];
    private _lap = diag_tickTime;
    private _enter = {
        if (_dbg && {_stage != ""}) then { _ms pushBack format ["%1=%2", _stage, round ((diag_tickTime - _lap) * 1000)] };
        _stage = _this;
        _lap = diag_tickTime;
    };
    try {
        "sense" call _enter;     call fnc_opcom_sense;
        "recon" call _enter;     call fnc_opcom_recon_sense;
        // OP posts' recon screen, driven on OPCOM's tick beside the belief sensors (defined in fnc_hardpoint_stream).
        "opsense" call _enter;   call DUWS_fnc_hardpointOPSense;
        "decay" call _enter;     call fnc_opcom_decay;
        "prune" call _enter;     call fnc_opcom_belief_prune;
        "contested" call _enter; call DUWS_fnc_opcom_contestedUpdate;
        // Refresh live taskings' strength/position before the grid reads them: grid_rebuild runs ahead of
        // task_step (which needs the fresh grid), so a kill would otherwise reach the grid a tick late.
        // effForceLive counts only the living, so a wiped group weighs 0 and drops out the same tick.
        "bookkeep" call _enter;
        {
            private _grp = groupFromNetId (_x get "grp");
            // A ferry rider is strength-frozen from board order to full dismount: its live count is falling only
            // because it board-despawns man by man, so a live read here would bleed the snapshot toward zero.
            if (!isNull _grp && {!(_x getOrDefault ["ferryFrozen", false])}) then {
                _x set ["pos", getPosASL (leader _grp)];
                _x set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
            } else {
                // Embarked rider (no group of its own): track its point to the live hull it rides, so the grid
                // reads its frozen force at the hull's spot, not a tick behind the transport. effForce stays frozen.
                if ((_x getOrDefault ["ridingOn", -1]) >= 0) then {
                    private _tr = [_x get "ridingOn"] call DUWS_fnc_opcom_byId;
                    if (!isNil "_tr" && {_tr getOrDefault ["embarked", false]}) then {
                        private _tg = groupFromNetId (_tr get "grp");
                        if (!isNull _tg) then { _x set ["pos", getPosASL (leader _tg)] };
                    };
                };
            };
        } forEach DUWS_opcom_taskings;
        "grid" call _enter;      call fnc_opcom_grid_rebuild;
        // Task step after the rebuild, so it reads the grid this tick just refreshed.
        "taskstep" call _enter;  call fnc_opcom_task_step;
        // Pick after the step, so it sees this tick's arrivals and deaths.
        "pick" call _enter;      call fnc_opcom_pick;
        // BLUFOR task-force upkeep rides this tick rather than a timer of its own; last, so a fault costs OPCOM nothing.
        "taskforces" call _enter; call fnc_taskforce_tick;

        // friCells/eneCells: cells holding force; belief: live sighting stamps; fresh: groups sensed this
        // tick (0 while belief>0 means everything held on last-seen).
        "debuglog" call _enter;
        // format eats its args before fnc_log can drop the line, so these whole-grid count/selectMax scans
        // would run every tick even at the default level; gate them so they cost nothing unless DEBUG is on.
        if (_dbg) then {
            ["DEBUG", "OPCOM", format ["grid tick=%1 w=%2 friCells=%3 eneCells=%4 maxFri=%5 maxEne=%6 belief=%7 fresh=%8 ms[%9]",
                DUWS_opcom_tick, DUWS_opcom_grid_w,
                {_x > 0.05} count DUWS_opcom_grid_fri,
                {_x > 0.05} count DUWS_opcom_grid_ene,
                selectMax DUWS_opcom_grid_fri, selectMax DUWS_opcom_grid_ene,
                count DUWS_opcom_belief_pos, DUWS_opcom_dbg_fresh, _ms joinString " "]] call fnc_log;
        };
    } catch {
        ["ERROR", "OPCOM", format ["tick %1 threw in %2, thread held alive: %3", DUWS_opcom_tick, _stage, _exception]] call fnc_log;
    };

    sleep OPCOM_TICK_PERIOD;
};
