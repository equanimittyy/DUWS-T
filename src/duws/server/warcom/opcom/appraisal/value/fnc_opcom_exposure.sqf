// Locality: server, [] call'd at load. The two proximity ramps the Values scale by: exposure, how close a spot sits to
// BLUFOR-held ground, and defend, how close it sits to OPFOR's own fixed defenses (opcom_plan.md §Value).
// Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// The HQ counts only once revealed, so an unfound base pulls no defense toward itself.
DUWS_fnc_opcom_bluforGroundSweep = {
    private _out = +(missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []]);
    _out append (missionNamespace getVariable ["Array_of_FOBpos", []]);
    if (missionNamespace getVariable ["DUWS_opcom_hqKnown", false] && {!isNil "PosOfBLUHQ"} && {PosOfBLUHQ isNotEqualTo []}) then {
        _out pushBack PosOfBLUHQ;
    };
    _out
};

DUWS_fnc_opcom_bluforGround = { ["bluforGround", DUWS_fnc_opcom_bluforGroundSweep] call DUWS_fnc_opcom_tickCached };

DUWS_fnc_opcom_exposureAt = {
    params ["_dist"];
    if (_dist <= OPCOM_EXPOSE_NEAR) exitWith { 1 };
    if (_dist >= OPCOM_EXPOSE_FAR) exitWith { OPCOM_EXPOSE_FLOOR };
    1 - (1 - OPCOM_EXPOSE_FLOOR) * (_dist - OPCOM_EXPOSE_NEAR) / (OPCOM_EXPOSE_FAR - OPCOM_EXPOSE_NEAR)
};

DUWS_fnc_opcom_exposure = {
    params ["_pos"];
    private _ground = call DUWS_fnc_opcom_bluforGround;
    if (_ground isEqualTo []) exitWith { OPCOM_EXPOSE_FLOOR };
    private _near = OPCOM_EXPOSE_FAR;
    { _near = _near min (_pos distance2D _x) } forEach _ground;
    [_near] call DUWS_fnc_opcom_exposureAt
};

DUWS_fnc_opcom_defendAt = {
    params ["_dist"];
    if (_dist <= OPCOM_DEFEND_NEAR) exitWith { 1 };
    if (_dist >= OPCOM_DEFEND_FAR) exitWith { OPCOM_DEFEND_FLOOR };
    1 - (1 - OPCOM_DEFEND_FLOOR) * (_dist - OPCOM_DEFEND_NEAR) / (OPCOM_DEFEND_FAR - OPCOM_DEFEND_NEAR)
};

// Standing defenses only: a tasking drives away tomorrow.
DUWS_fnc_opcom_defend = {
    params ["_pos"];
    private _near = OPCOM_DEFEND_FAR;
    {
        _x params ["", "_zp", "_zs"];
        if !([[_zp] call fnc_zone_key] call fnc_zone_bluforHeld) then { _near = _near min (((_pos distance2D _zp) - _zs) max 0) };
    } forEach zone_meta_array;
    { if ((_x select 3) isEqualTo "opfor") then { _near = _near min (_pos distance2D (_x select 1)) } } forEach DUWS_hardpoints;
    [_near] call DUWS_fnc_opcom_defendAt
};
