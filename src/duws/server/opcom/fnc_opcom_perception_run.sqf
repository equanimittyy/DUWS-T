// Locality: server. The OPCOM loop thread, spawned once by WARCOM init after zones and civ state exist.
// Phase 1 is perception-only: it maintains the belief store and the influence grid and takes no
// decisions. The two cadences are already split so Phase 2 slots its scoring pass into the strategic
// phase without restructuring. The fast base pass runs only the cheap sighting sweep; the strategic
// phase ages belief and rebuilds the grid from current holdings and belief.
if (!isServer) exitWith {};

call fnc_opcom_belief_init;
call fnc_opcom_grid_init;
call fnc_opcom_grid_rebuild;                  // one field up front, so it is not all-zero until the first phase

private _phaseEvery = 18;                      // fast passes per strategic phase (12-18; ~72 s here, tune)
private _pass = 0;
while {true} do {
    call fnc_opcom_sense;
    _pass = _pass + 1;
    if (_pass >= _phaseEvery) then {
        _pass = 0;
        DUWS_opcom_tick = DUWS_opcom_tick + 1;
        call fnc_opcom_decay;
        call fnc_opcom_grid_rebuild;
    };
    sleep 4;
};
