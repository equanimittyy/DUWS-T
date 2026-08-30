// Locality: server -- called by mission threads only.
/*
    Raises a mission's defenders from a token list and files each group under the running mission the
    instant it appears, not after the whole composition is up. raiseGarrison sleeps between groups, so a
    mission won mid-stagger would leave a batch claim at the end unrun; claiming each group as it spawns
    means a quick finish still tears down everything already raised, by ownership.

    The token is captured here, before the stagger's sleeps, so a claim firing deep in the stagger stamps
    this mission's token and not whatever it may have advanced to by then. A group that spawns after the
    mission has already ended is still stamped with the now-dead token, which the continuous sweep
    (fnc_repetitive_cleanup) collects on its own -- cleanup's single pass is long past by then.

    Returns the groups raised (nulls already dropped by raiseGarrison), for a caller that keeps them.
    Runs the stagger inline: a caller that must not block wraps the call in spawn.

    _tokens  zone-style composition tokens (e.g. "widepatrol:team"), as DUWS_fnc_raiseGarrison takes.
    _pos     centre the composition is raised around.
    _radius  band radius passed through to the spawner.
*/

if (!isServer) exitWith {[]};
params ["_tokens", "_pos", "_radius"];

private _token = missionNamespace getVariable ["DUWS_mission_token", 0];
[_tokens, _pos, _radius, { [_this select 0, _token] call fnc_mission_claim }] call DUWS_fnc_raiseGarrison
