// Locality: server -- mission threads call it during generation, all server-side.
//
// One generation-progress hint on the requesting machine only: the player who clicked the offer, so a
// co-op teammate's click never flashes a survey/generating line on everyone else. _requester is the
// thread's remoteExecutedOwner, sampled in the thread's opening scope; 0 means the mission was forced
// locally (the debug tool), so the host is the only machine to reach.
params ["_requester", "_key"];
private _target = if (_requester > 0) then { _requester } else { [0, -2] select isDedicated };
[_key, {hint localize _this}] remoteExec ["BIS_fnc_Spawn", _target];
