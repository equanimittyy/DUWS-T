// Locality: where the unit is local -- doMove is ignored on any other machine.
params ["_unit", "_car"];

// A horn inside the hold is ignored: a second resume thread would hand the unit back mid-step.
#define DODGE_TIME 5

private _fnc_free = {
    params ["_unit"];
    alive _unit
    && {isNull objectParent _unit}
    && {lifeState _unit != "INCAPACITATED"}
    // A script that holds a unit in place disables its pathing: HQ staff, hostages, a civilian asked a favour.
    && {_unit checkAIFeature "PATH"}
    && {_unit checkAIFeature "MOVE"}
    && {switch (side group _unit) do {
        case west: { true };
        // The panic sweep's refusals plus the conversation states, each of which owns the civilian's next move.
        case civilian: {
            (_unit getVariable ["civ_locIndex", -1]) > -1
            && {!(_unit getVariable ["civ_isZombie", false])}
            && {(_unit getVariable ["DUWS_vendor_type", ""]) == ""}
            && {(_unit getVariable ["DUWS_civMission_state", ""]) == ""}
            && {(["DUWS_civ_stopped", "DUWS_civ_panicked", "DUWS_civ_closed", "DUWS_civ_arrested", "isSurrendered", "isHostile"] findIf { _unit getVariable [_x, false] }) < 0}
        };
        default { false };
    }}
};

if (_unit getVariable ["DUWS_horn_dodging", false] || {!([_unit] call _fnc_free)}) exitWith {};
_unit setVariable ["DUWS_horn_dodging", true];

private _isCiv = side group _unit == civilian;
if (_isCiv) then {
    private _wps = waypoints group _unit;
    reverse _wps;
    { deleteWaypoint _x } forEach _wps;
    // Safe on the group: a civilian is a group of one, and the resume puts the circuit's LIMITED pace back.
    group _unit setSpeedMode "FULL";
};

// Toward the side the unit already stands on, so the step never crosses the car's path.
private _toRight = ((_car worldToModel (getPos _unit)) select 0) > 0;
private _bearing = (direction _car) + ([-60, 60] select _toRight);
_unit doMove (_unit getPos [4.5 + 0.3 * vectorMagnitude (velocity _car), _bearing]);

[_unit, _isCiv, _fnc_free] spawn {
    params ["_unit", "_isCiv", "_fnc_free"];
    sleep DODGE_TIME;
    _unit setVariable ["DUWS_horn_dodging", false];
    // Re-tested: a panic, a call-over or an order can take the unit during the step, and then owns its next move.
    if !([_unit] call _fnc_free) exitWith {};
    if (_isCiv) then { [_unit] call fnc_civ_resume } else { _unit doFollow (leader _unit) };
};
