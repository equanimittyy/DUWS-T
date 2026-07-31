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

// Released here rather than after a delay. The wait between side missions is the per-type cooldown
// fnc_mission_begin stamps, so the only thing this flag still says is "a mission is running right
// now" -- which stops being true the moment one ends.
Mission_available = true;
publicVariable "Mission_available";
["INFO", "MISSION", "mission slot released, a new side mission can generate"] call fnc_log;

[_targetpos, _radius, _compKey, _sweepFriendly] spawn fnc_mission_cleanup;
