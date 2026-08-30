// Locality: server -- called by mission threads only.
/*
    Raises a mission's defenders and claims each group under the running mission the instant it spawns
    (via raiseGarrison's _onRaise), so a win mid-stagger still tears everything already up down by
    ownership. The token is captured up front, before the stagger's sleeps: a claim firing deep in the
    stagger must stamp this mission's token, not one it drifted to. A group spawning after the mission
    ends keeps the now-dead token; the continuous sweep (fnc_repetitive_cleanup) collects that.

    Returns the groups raised. Runs the stagger inline -- a caller that must not block wraps it in spawn.
    Params are DUWS_fnc_raiseGarrison's: _tokens, _pos, _radius.
*/

if (!isServer) exitWith {[]};
params ["_tokens", "_pos", "_radius"];

private _token = missionNamespace getVariable ["DUWS_mission_token", 0];
[_tokens, _pos, _radius, { [_this select 0, _token] call fnc_mission_claim }] call DUWS_fnc_raiseGarrison
