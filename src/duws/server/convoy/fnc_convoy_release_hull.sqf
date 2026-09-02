// Locality: server. Release ONE hull from fnc_convoy_drive's control back to native AI.
//
// The convoy driver imposes per-hull driving control -- a committed setDriveOnPath, a forced speed, a lifted
// speed cap, and the driver's FSM disabled -- and reverses it only at its OWN teardown, never when a hull leaves
// the group mid-run. A hull that peels off (the HVT car breaking for its zone) would otherwise keep the stale
// path and the forced convoy cruise and never race its own waypoint, so its caller calls this to hand it back
// explicitly. fnc_convoy_drive's own teardown routes through here too, so both undo the same set.
//
// Reverses DRIVING control only. Crew-retention (setUnloadInCombat / allowCrewInImmobile) is left as the convoy
// set it: a peeling run-away wants its crew kept aboard exactly as the column did, and a caller wanting
// otherwise changes it itself. Idempotent (safe on an already-released hull) and null-safe (safe when the crew
// is gone -- the enableAI forEach then iterates nothing).
params ["_veh"];

_veh setDriveOnPath [];
_veh forceSpeed -1;
// limitSpeed reset must be a large value, not -1: -1 does not reset the cap and forces a helicopter into
// reverse. 1e10 is past any ground vehicle's top speed, so it lifts the cap.
_veh limitSpeed 1e10;
_veh forceFollowRoad false;
// Only the driver's FSM was disabled, but enabling it across the whole crew is idempotent on the gunner and
// commander (never touched) and keeps this a single mirror of the disable.
{ _x enableAI "FSM" } forEach (crew _veh);
