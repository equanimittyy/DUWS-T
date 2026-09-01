// Locality: server -- the IDAP delivery missions call it to raise the receiving crew, all server-side.
//
// Three civilian aid workers at a safe spot near _townPos, one of them marshalling the truck in. The
// marshal pose is a switchMove gesture, and the engine cancels a gesture whenever the civilian reacts to
// the approaching truck (fear, or a vehicle nudging them). allowFleeing 0 and the disabled reaction FSM
// cut most of that; a background loop re-asserts the pose against whatever still slips through, so the
// marshaller keeps waving the truck in instead of dropping the anim the moment the player drives up.
//
// Release the pose by clearing DUWS_holdAnim on the marshaller: the loop then drops it and stops. The
// caller's hand-over does this. Returns [_group, _marshaller, _crewPos] -- _crewPos is the resolved spot
// the caller pins its delivery marker on and measures the drop distance against, so both sit on the crew.
params ["_townPos", ["_radius", 80]];
if (!isServer) exitWith { [grpNull, objNull, _townPos] };

private _crewPos = [_townPos, 0, _radius, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
if (_crewPos isEqualTo [] || { (_crewPos select 0) == 0 && { (_crewPos select 1) == 0 } }) then { _crewPos = _townPos };

private _crewClasses = [
    "C_IDAP_Man_Aidworker_01_F", "C_IDAP_Man_Aidworker_02_F", "C_IDAP_Man_Aidworker_03_F",
    "C_IDAP_Man_Aidworker_04_F", "C_IDAP_Man_Aidworker_05_F", "C_IDAP_Man_Aidworker_06_F"
];
private _crewUnits = [];
for "_i" from 1 to 3 do { _crewUnits pushBack (selectRandom _crewClasses) };
private _group = [_crewPos, civilian, _crewUnits, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;

private _marshaller = objNull;
{
    _x setPos (_crewPos getPos [5 + random 3, random 360]);
    _x disableAI "MOVE";
    _x disableAI "PATH";
    _x setBehaviour "CARELESS";
    if (_forEachIndex == 0) then {
        _marshaller = _x;
        _x allowFleeing 0;
        _x disableAI "FSM";
        _x disableAI "AUTOTARGET";
        _x setVariable ["DUWS_holdAnim", true];
        _x switchMove "Acts_JetsShooterNavigate_loop_m";
    };
} forEach units _group;

// animationState reports lowercase; switchMove takes the anim either way.
[_marshaller] spawn {
    params ["_m"];
    while { !isNull _m && { alive _m } && { _m getVariable ["DUWS_holdAnim", false] } } do {
        if (animationState _m != "acts_jetsshooternavigate_loop_m") then { _m switchMove "Acts_JetsShooterNavigate_loop_m" };
        sleep 2;
    };
    if (!isNull _m && { alive _m }) then { _m switchMove "" };
};

[_group, _marshaller, _crewPos]
