if (!isServer) exitWith {};

params ["_caller", "_restSite"];

private _coolDownVar = "GM_Heal_LastUsedTime";
private _coolDownSeconds = 10;
private _currentTime = time;
private _lastUsedTime = missionNamespace getVariable [_coolDownVar, 0];

if (_currentTime - _lastUsedTime >= _coolDownSeconds) then {
    // The confirmation belongs to fnc_rest_heal, after its fade to black has finished. Sent from
    // here it reached the players' screens while they were still watching daylight, so the line
    // announcing the rest arrived before the rest visibly began.
    [_restSite] remoteExec ["fnc_rest_heal", 2];
    missionNamespace setVariable [_coolDownVar, _currentTime];
    publicVariable _coolDownVar;
} else {
    // Sent to the caller: a bare hint here draws on the server, which on a dedicated one is
    // nobody's screen and on a host is the wrong player's.
    (localize "STR_DUWS_T_restcooldownhint") remoteExec ["hint", _caller];
};
