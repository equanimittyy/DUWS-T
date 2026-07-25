if (!isServer) exitWith {};
params ["_group"];
if (isNull _group) exitWith {};
{
    if (alive _x) then { [_x] call fnc_add_intel_on_death; };
} forEach (units _group);