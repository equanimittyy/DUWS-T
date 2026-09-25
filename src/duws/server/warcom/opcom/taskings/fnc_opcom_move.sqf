// Locality: server, [] call'd at load. The marching orders that end by stopping, one step each: `move` and `patrol`
// share theirs, and `probe` stops early on it. The march itself is fnc_opcom_movement_core.sqf.
if (!isServer) exitWith {};

// A guard settle re-orders the group so map and group agree.
DUWS_fnc_opcom_stepMove = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live", "", "_arrived"];
    if (!_arrived) exitWith { false };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    if (_live) then { [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder };
    true
};

// Closing is how a probe reads its target, so it stops where it stands once the block reads fresh.
DUWS_fnc_opcom_stepProbe = {
    params ["_t", "_ctx"];
    if (([_t get "target"] call DUWS_fnc_opcom_blockStaleness) <= OPCOM_PROBE_FRESH) then { _ctx set [4, true] };
    [_t, _ctx] call DUWS_fnc_opcom_stepMove
};

// A garrison settle despawns -- a combatant's token now sits in the reserve pool, so a live copy would fight twice.
DUWS_fnc_opcom_stepReturn = {
    params ["_t", "_ctx"];
    _ctx params ["", "", "_live", "", "_arrived"];
    if (!_arrived) exitWith { false };
    [_t, _t get "returnZone"] call DUWS_fnc_opcom_garrisonInto;
    if (_live) then { [_t] call DUWS_fnc_opcom_reVirt };
    true
};

DUWS_fnc_opcom_stepErrand = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live"];
    // Its own arrival read: a drop is aimed at a town centre, often deep in streets a truck never threads.
    if ((_pos distance2D (_t get "target")) >= OPCOM_DELIVER_ARRIVE) exitWith { false };
    [_t] call DUWS_fnc_opcom_deliver;
    if (_live) then { [_grp] call DUWS_fnc_opcom_despawn; _t set ["grp", ""] };
    _t set ["status", "done"];
    true
};
