// Locality: server -- the informant's Move/Hold action remoteExecs this from clients (he is server-local).
// Toggles him between leading (follows the caller) and held (planted where he stands). R3F carries
// objects, not people, so the crate reuses R3F while the informant gets this.
if (!isServer) exitWith {};
params ["_inf", "_caller", "_taskName"];
if (isNull _inf || { !alive _inf }) exitWith {};
private _leadVar = format ["%1_leading", _taskName];

if (missionNamespace getVariable [_leadVar, false]) exitWith {
    missionNamespace setVariable [_leadVar, false, true];
    _inf disableAI "PATH";
    _inf setPosATL (getPosATL _inf);
    _inf setBehaviour "CARELESS";
    _inf setCombatMode "BLUE";
};

missionNamespace setVariable [_leadVar, true, true];
_inf enableAI "PATH";
_inf setBehaviour "SAFE";
_inf setUnitPos "UP";
[_inf, _caller, _leadVar] spawn {
    params ["_inf", "_caller", "_leadVar"];
    while { (missionNamespace getVariable [_leadVar, false]) && { alive _inf } && { !isNull _caller } && { alive _caller } } do {
        _inf doMove (getPosATL _caller);
        sleep 2;
    };
};
