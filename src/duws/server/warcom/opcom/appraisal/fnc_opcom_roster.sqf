// Locality: server, [] call'd at load. The roster: the free units a commit order may draw on (opcom_plan.md
// §Orchestration). Only OPCOM's own recruits stand in it, never a zone's base garrison, so a draw thins a zone and never
// empties it.
if (!isServer) exitWith {};

DUWS_fnc_opcom_freeSweep = {
    DUWS_opcom_taskings select {
        DUWS_opcom_tick >= (_x get "hold")
            && {(_x get "status") isNotEqualTo "dead"}
            && {(_x getOrDefault ["ridingOn", -1]) < 0}
            && {(_x get "effForce") > 0}
            && {[_x] call DUWS_fnc_opcom_drawable}
    }
};

DUWS_fnc_opcom_free = { ["free", DUWS_fnc_opcom_freeSweep] call DUWS_fnc_opcom_tickCached };

// Recon stays out, kept for Patrol. Air stays out of an Attack, which must stand in the zone to take it.
DUWS_fnc_opcom_freeCombatants = {
    params [["_air", true]];
    (call DUWS_fnc_opcom_free) select {
        private _f = _x get "flags";
        !("noncombat" in _f) && {!("recon" in _f)} && {_air || {(_x get "moveType") in ["inf", "wheeled", "tracked"]}}
    }
};
