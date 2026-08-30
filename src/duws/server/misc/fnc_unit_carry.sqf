// Carry a live NPC by attaching it to a player: reposition by hand, no AI pathfinding. Reusable.
// State rides the unit as DUWS_carriedBy (broadcast): objNull free, the carrier otherwise.

// PATH is left alone, so a unit the caller pinned in place stays pinned once set down.
DUWS_carrySuspendFeatures = ["MOVE", "FSM", "AUTOTARGET", "TARGET", "AUTOCOMBAT"];

// The put-down action lives on the carrier, not the carried unit: once attached the unit sits on top of
// the player and cannot be cursor-targeted, so an action on it never shows. Added on the carrier's client
// (where addAction must run) and torn down from DUWS_fnc_unitDrop so a forced drop clears it too.
DUWS_fnc_unitCarryAddDropAction = {
    params ["_unit", "_carrier", "_label"];
    private _id = _carrier addAction [
        _label,
        { params ["", "_caller", "", "_args"]; [_args select 0, _caller] call DUWS_fnc_unitDrop },
        [_unit], 1.5, false, true, "", "true"
    ];
    _carrier setVariable ["DUWS_carryDropAction", _id];
};

DUWS_fnc_unitCarryRemoveDropAction = {
    params ["_carrier"];
    private _id = _carrier getVariable ["DUWS_carryDropAction", -1];
    if (_id >= 0) then { _carrier removeAction _id; _carrier setVariable ["DUWS_carryDropAction", -1] };
};

DUWS_fnc_unitCarry = {
    if (!isServer) exitWith { _this remoteExec ["DUWS_fnc_unitCarry", 2] };
    params ["_unit", "_carrier", ["_dropLabel", ""]];
    if (isNull _unit || { !alive _unit } || { !isNull (_unit getVariable ["DUWS_carriedBy", objNull]) }) exitWith {};
    { _unit disableAI _x } forEach DUWS_carrySuspendFeatures;
    _unit setBehaviour "CARELESS";
    _unit setUnitPos "UP";
    [_unit, "AmovPercMstpSnonWnonDnon_G0"] remoteExec ["switchMove", 0];   // local effect, so broadcast
    _unit attachTo [_carrier, [0, 1, 0]];
    _unit setDir 0;
    _unit setVariable ["DUWS_carriedBy", _carrier, true];
    if (_dropLabel != "") then { [_unit, _carrier, _dropLabel] remoteExec ["DUWS_fnc_unitCarryAddDropAction", _carrier] };
};

// Set down in front of _carrier, or in place if none given (forced drop). Combat mode/PATH stay the caller's.
DUWS_fnc_unitDrop = {
    if (!isServer) exitWith { _this remoteExec ["DUWS_fnc_unitDrop", 2] };
    params ["_unit", ["_carrier", objNull]];
    private _held = _unit getVariable ["DUWS_carriedBy", objNull];
    if (isNull _held) exitWith {};
    detach _unit;
    if (!isNull _carrier) then {
        _unit setPosATL (_carrier getPos [1.2, getDir _carrier]);
        _unit setDir (getDir _carrier);
    };
    { _unit enableAI _x } forEach DUWS_carrySuspendFeatures;
    [_unit, ""] remoteExec ["switchMove", 0];
    _unit setVariable ["DUWS_carriedBy", objNull, true];
    [_held] remoteExec ["DUWS_fnc_unitCarryRemoveDropAction", _held];
};

DUWS_fnc_unitCarryToggle = {
    if (!isServer) exitWith { _this remoteExec ["DUWS_fnc_unitCarryToggle", 2] };
    params ["_unit", "_carrier", ["_dropLabel", ""]];
    if (isNull _unit || { !alive _unit }) exitWith {};
    if (isNull (_unit getVariable ["DUWS_carriedBy", objNull])) then {
        [_unit, _carrier, _dropLabel] call DUWS_fnc_unitCarry;
    } else {
        [_unit, _carrier] call DUWS_fnc_unitDrop;
    };
};
