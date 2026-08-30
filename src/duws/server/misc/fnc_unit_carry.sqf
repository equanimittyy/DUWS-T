// Carry a live NPC by attaching it to a player: reposition by hand, no AI pathfinding. Reusable.
// State rides the unit as DUWS_carriedBy (broadcast): objNull free, the carrier otherwise.

// PATH is left alone, so a unit the caller pinned in place stays pinned once set down.
DUWS_carrySuspendFeatures = ["MOVE", "FSM", "AUTOTARGET", "TARGET", "AUTOCOMBAT"];

DUWS_fnc_unitCarry = {
    if (!isServer) exitWith { _this remoteExec ["DUWS_fnc_unitCarry", 2] };
    params ["_unit", "_carrier"];
    if (isNull _unit || { !alive _unit } || { !isNull (_unit getVariable ["DUWS_carriedBy", objNull]) }) exitWith {};
    { _unit disableAI _x } forEach DUWS_carrySuspendFeatures;
    _unit setBehaviour "CARELESS";
    _unit setUnitPos "UP";
    [_unit, "AmovPercMstpSnonWnonDnon_G0"] remoteExec ["switchMove", 0];   // local effect, so broadcast
    _unit attachTo [_carrier, [0, 1, 0]];
    _unit setDir 0;
    _unit setVariable ["DUWS_carriedBy", _carrier, true];
};

// Set down in front of _carrier, or in place if none given (forced drop). Combat mode/PATH stay the caller's.
DUWS_fnc_unitDrop = {
    if (!isServer) exitWith { _this remoteExec ["DUWS_fnc_unitDrop", 2] };
    params ["_unit", ["_carrier", objNull]];
    if (isNull (_unit getVariable ["DUWS_carriedBy", objNull])) exitWith {};
    detach _unit;
    if (!isNull _carrier) then {
        _unit setPosATL (_carrier getPos [1.2, getDir _carrier]);
        _unit setDir (getDir _carrier);
    };
    { _unit enableAI _x } forEach DUWS_carrySuspendFeatures;
    [_unit, ""] remoteExec ["switchMove", 0];
    _unit setVariable ["DUWS_carriedBy", objNull, true];
};

DUWS_fnc_unitCarryToggle = {
    if (!isServer) exitWith { _this remoteExec ["DUWS_fnc_unitCarryToggle", 2] };
    params ["_unit", "_carrier"];
    if (isNull _unit || { !alive _unit }) exitWith {};
    if (isNull (_unit getVariable ["DUWS_carriedBy", objNull])) then {
        [_unit, _carrier] call DUWS_fnc_unitCarry;
    } else {
        [_unit, _carrier] call DUWS_fnc_unitDrop;
    };
};
