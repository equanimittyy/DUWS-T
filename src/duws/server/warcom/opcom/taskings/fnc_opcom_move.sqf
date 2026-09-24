// Locality: server, [] call'd at load. The move order: carry an errand to its target and spend the truck on it,
// or settle where it was sent. The march itself is fnc_opcom_movement_core.sqf.
if (!isServer) exitWith {};

// Settle an arrived move: re-garrison a returnZone or hold as guard. Mutates the record only; true if it garrisoned.
DUWS_fnc_opcom_settleMove = {
    params ["_t", "_pos"];
    private _rz = _t getOrDefault ["returnZone", ""];
    if (_rz isNotEqualTo "") exitWith { [_t, _rz] call DUWS_fnc_opcom_garrisonInto; true };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    false
};

DUWS_fnc_opcom_stepMove = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live", "", "_arrived"];
    // errand and returnZone are exclusive (set upstream), so a delivery cannot also settle.
    private _errand = _t getOrDefault ["errand", []];
    if (_errand isNotEqualTo []) exitWith {
        private _landed = (_pos distance2D (_t get "target")) < OPCOM_DELIVER_ARRIVE;
        if (_landed) then {
            [_t] call DUWS_fnc_opcom_deliver;
            if (_live) then { [_grp] call DUWS_fnc_opcom_despawn; _t set ["grp", ""] };
            _t set ["status", "done"];
        };
        _landed
    };
    if (!_arrived) exitWith { false };
    // A guard settle re-orders the group so map and group agree. A garrison settle despawns -- a combatant's token
    // now sits in the reserve pool, so a live copy would fight twice.
    if ([_t, _pos] call DUWS_fnc_opcom_settleMove) then {
        if (_live) then { [_t] call DUWS_fnc_opcom_reVirt };
    } else {
        if (_live) then { [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder };
    };
    true
};
