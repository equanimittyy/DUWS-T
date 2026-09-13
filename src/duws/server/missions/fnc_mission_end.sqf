// Locality: server -- mission threads call it, and all of them run server-side.
//
// The tail every finished side mission owes, success or failure: free the mission slot, tear the
// objective down, and drop the target position.
//
// Reward and task status deliberately stay at the call site. They are the two things a success and
// a failure genuinely differ on, and each is already a single call to a function of its own --
// folding them in would mean passing a success flag and three reward arguments that half the
// callers have no use for.
params ["_targetpos", "_radius", ["_compKey", ""], ["_sweepFriendly", false]];

// This mission's instance id, captured before the slot reopens below so cleanup flags this
// mission's units and never a successor's.
private _token = missionNamespace getVariable ["DUWS_mission_token", 0];

// Released here rather than after a delay. The wait between side missions is the per-type cooldown
// fnc_mission_begin stamps, so the only thing this flag still says is "a mission is running right
// now" -- which stops being true the moment one ends.
Mission_available = true;
publicVariable "Mission_available";
["INFO", "MISSION", "mission slot released, a new side mission can generate"] call fnc_log;

// Called inline; cleanup doesn't sleep -- it only releases the composition and flags the
// mission's units for the map sweep, which does the timed deletion on its own clock.
[_targetpos, _radius, _compKey, _sweepFriendly, _token] call fnc_mission_cleanup;
