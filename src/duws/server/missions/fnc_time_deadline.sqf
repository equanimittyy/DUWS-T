// Rolls an in-game duration in 10-minute steps and returns it as an absolute engine-time (`time`)
// target, so the existing `time > deadline` checks fire after that much IN-GAME time whatever the
// day/night multiplier is. Real seconds to wait = in-game seconds / time_Multiplier.
//
// The multiplier is baked in here, at target creation. It is set once at setup (server_var_init
// defaults it to 1, the enviro menu picks it before the game starts) and nothing re-applies it mid
// run, so a target set now cannot drift; a live multiplier change would need daytime-based targets.
params ["_minSteps", ["_maxSteps", -1]];
private _mult = missionNamespace getVariable ["time_Multiplier", 1];
if (_mult <= 0) then { _mult = 1 };
time + (([_minSteps, _maxSteps] call fnc_time_roll) / _mult)
