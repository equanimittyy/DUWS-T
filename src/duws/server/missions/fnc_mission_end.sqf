// Locality: server -- mission threads call it, and all of them run server-side.
//
// The tail every finished side mission owes, success or failure: release the mission slot on the
// usual timer, tear the objective down, and drop the target position.
//
// Reward and task status deliberately stay at the call site. They are the two things a success and
// a failure genuinely differ on, and each is already a single call to a function of its own --
// folding them in would mean passing a success flag and three reward arguments that half the
// callers have no use for.
params ["_targetpos", "_radius", ["_compKey", ""], ["_sweepFriendly", false]];

[] spawn fnc_missionTimer;
[_targetpos, _radius, _compKey, _sweepFriendly] spawn fnc_mission_cleanup;

// Cleared here so that no thread can leave it set. fnc_corpse_search_action reads this global when
// it arms a body, so a value outliving its own mission puts an intel marker on ground the player
// has finished with -- ten of the twenty-six exits this replaces never cleared it, and the ones
// that did were the reason the other ten looked correct.
missionNamespace setVariable ["current_mission_target_pos", nil];
