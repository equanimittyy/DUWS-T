// Locality: server, [] call'd at load. The roster: the free units a commit order may draw on (opcom_plan.md
// §Ownership). Only OPCOM's own recruits stand in it, never a zone's base garrison, so a draw thins a zone and never
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
DUWS_fnc_opcom_isCombatant = {
    params ["_flags", "_moveType", ["_air", true]];
    !("noncombat" in _flags) && {!("recon" in _flags)} && {_air || {_moveType in ["inf", "wheeled", "tracked"]}}
};

DUWS_fnc_opcom_freeCombatants = {
    params [["_air", true]];
    (call DUWS_fnc_opcom_free) select { [_x get "flags", _x get "moveType", _air] call DUWS_fnc_opcom_isCombatant }
};

// Combat air stays off Patrol: it crosses the ground it would sweep faster than a tick, and the recon helicopter is
// the faction's air scout.
DUWS_fnc_opcom_isPatroller = {
    params ["_flags", "_moveType"];
    "recon" in _flags || {[_flags, _moveType, false] call DUWS_fnc_opcom_isCombatant}
};
