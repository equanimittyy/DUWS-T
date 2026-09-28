// Locality: server. The OPCOM loop thread, spawned once by WARCOM init after zones and civ state exist.
// One cadence, not a fast/strategic split: perception, the tasking step and the pick share this tick, and a shorter
// OPCOM_TICK_PERIOD steps movement finer rather than breaking it.
if (!isServer) exitWith {};

call fnc_opcom_belief_init;
call fnc_opcom_grid_init;
call fnc_opcom_tasking_init;
if (DUWS_campaignLoaded) then {
    // Once the FOBs stand: the restore re-keys OPCOM's hold on each FOB to the one rebuilt in its place.
    while {!(["SAVE", "the restored FOBs", {!("bases" in DUWS_restorePending)}, 300] call fnc_waitLogged)} do {};
    call DUWS_fnc_restoreOpcom;
};

// The drip's fractions of an AP, to the wallet and to the tier, paid out whole because fnc_ap_adjust keeps both whole.
private _dripCarry = 0;
private _tierCarry = 0;
while {true} do {
    // Idle with nobody on: holds, cooldowns and staleness all count in ticks, so a frozen clock is a paused commander
    // rather than one that spends a night buying against a player who is asleep.
    waitUntil { sleep OPCOM_TICK_PERIOD; ([] call DUWS_fnc_humanCount) > 0 };
    // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup). _stage names the
    // stage in the catch so the RPT says what broke; the tick's work is dropped and retried next pass.
    DUWS_opcom_tick = DUWS_opcom_tick + 1;
    DUWS_opcom_dbg_route = [0, 0, 0, 0];
    private _stage = "";
    // Per-stage wall time for the DEBUG line. Scheduled, so a figure includes any time the scheduler held the stage.
    private _dbg = duws_log_level >= 4;
    private _ms = [];
    private _lap = diag_tickTime;
    private _frame = diag_frameNo;
    private _enter = {
        if (_dbg && {_stage != ""}) then {
            _ms pushBack format ["%1=%2/%3", _stage, round ((diag_tickTime - _lap) * 1000), diag_frameNo - _frame]
        };
        _stage = _this;
        _lap = diag_tickTime;
        _frame = diag_frameNo;
    };
    try {
        "sense" call _enter;     call fnc_opcom_sense;
        "patrol" call _enter;    call fnc_opcom_patrol_sense;
        // OP posts' recon screen, driven on OPCOM's tick beside the belief sensors (defined in fnc_hardpoint_stream).
        "opsense" call _enter;   call DUWS_fnc_hardpointOPSense;
        "decay" call _enter;     call fnc_opcom_decay;
        "prune" call _enter;     call fnc_opcom_belief_prune;
        "contested" call _enter; call DUWS_fnc_opcom_contestedUpdate;
        // Refresh live taskings before the grid reads them: grid_rebuild runs ahead of task_step (which needs the
        // fresh grid), so a kill would otherwise reach the grid a tick late.
        "bookkeep" call _enter;  call DUWS_fnc_opcom_bookkeep;
        "grid" call _enter;      call fnc_opcom_grid_rebuild;
        // Task step after the rebuild, so it reads the grid this tick just refreshed.
        "taskstep" call _enter;  call fnc_opcom_task_step;
        "ferries" call _enter;   call DUWS_fnc_opcom_ferryDispatch;
        "attacks" call _enter;   call DUWS_fnc_opcom_attackStep;
        "need" call _enter;      call DUWS_fnc_opcom_needRefresh;
        "drip" call _enter;
        _dripCarry = _dripCarry + ([count WARCOM_zones_controled_by_OPFOR, count WARCOM_createdZones] call DUWS_fnc_opcom_dripRate);
        if (_dripCarry >= 1) then {
            private _ap = floor _dripCarry;
            _dripCarry = _dripCarry - _ap;
            _tierCarry = _tierCarry + _ap * OPCOM_AP_DRIP_TIER * DUWS_econ_throttle;
            private _earned = floor _tierCarry;
            _tierCarry = _tierCarry - _earned;
            ["OPF", _ap, "opcom_drip", _earned, "DEBUG"] call fnc_ap_adjust;
        };
        // Pick after the step, so it sees this tick's arrivals and deaths.
        "pick" call _enter;
        DUWS_opcom_dbg_pick = [];
        DUWS_opcom_pickDebt = DUWS_opcom_pickDebt + DUWS_opcom_picksPerTick;
        private _picks = floor DUWS_opcom_pickDebt;
        DUWS_opcom_pickDebt = DUWS_opcom_pickDebt - _picks;
        if (_picks == 0 && {DUWS_opcom_pickOnce isNotEqualTo ""}) then { _picks = 1 };
        for "_k" from 1 to _picks do {
            // A second pick must see the truck, wallet and sites the first one spent.
            call DUWS_fnc_opcom_tickCacheReset;
            call fnc_opcom_pick;
        };
        // BLUFOR task-force upkeep rides this tick rather than a timer of its own; last, so a fault costs OPCOM nothing.
        "taskforces" call _enter; call fnc_taskforce_tick;
        // The Intelligence Center's faucet, for the same reason and after it: the contacts it plots are read off
        // this loop's own tasking store, so it rolls on the clock that moved them. Odds are the levels bought, and
        // a hit pays through the one intel payout point rather than a channel of its own. Silent on a dry pool --
        // a support standing for hours cannot report "nothing" each time it rolls, where a player who searched a
        // body asked the question and is owed the answer.
        "intel" call _enter;
        private _intelLevel = missionNamespace getVariable ["DUWS_intelLevel", 0];
        if (random 1 < (DUWS_intel_roll_by_level param [_intelLevel, 0])) then {
            [[], objNull, true] call fnc_intel_payout;
        };

        // friCells/eneCells: cells holding force; belief: live sighting stamps; fresh: groups sensed this
        // tick (0 while belief>0 means everything held on last-seen).
        "debuglog" call _enter;
        // format eats its args before fnc_log can drop the line, so these whole-grid count/selectMax scans
        // would run every tick even at the default level; gate them so they cost nothing unless DEBUG is on.
        if (_dbg) then {
            DUWS_opcom_dbg_route params ["_rn", "_rCells", "_rSec", "_rFrames"];
            ["DEBUG", "OPCOM", format ["grid tick=%1 w=%2 friCells=%3 eneCells=%4 maxFri=%5 maxEne=%6 belief=%7 fresh=%8 ms[%9] pick[%10] route[n=%11 cells=%12 ms=%13/%14]",
                DUWS_opcom_tick, DUWS_opcom_grid_w,
                {_x > 0.05} count DUWS_opcom_grid_fri,
                {_x > 0.05} count DUWS_opcom_grid_ene,
                selectMax DUWS_opcom_grid_fri, selectMax DUWS_opcom_grid_ene,
                count DUWS_opcom_belief_pos, DUWS_opcom_dbg_fresh, _ms joinString " ", DUWS_opcom_dbg_pick joinString " ",
                _rn, _rCells, round (_rSec * 1000), _rFrames]] call fnc_log;
        };
    } catch {
        ["ERROR", "OPCOM", format ["tick %1 threw in %2, thread held alive: %3", DUWS_opcom_tick, _stage, _exception]] call fnc_log;
    };
};
