// Locality: any -- broadcast. The server gates on it, the HQ readout and the strategic map both
// display it, and all three must agree on what "ready" means.
//
// Seconds left on a side-mission type; 0 when it is ready.
//
// The clock is `time`, mission seconds. Nothing that moves the campaign date moves this: resting
// at HQ skips three in-game hours and a Zeus can drag the clock to midnight, and neither shortens
// the wait -- which is the point, because the cooldown is the only thing pacing side missions now
// that the slot frees the moment one ends. `time` is also saved and restored with the mission,
// where a diag_tickTime stamp is not.
params ["_missionType"];

private _until = missionNamespace getVariable [format ["mission_cooldown_%1", _missionType], 0];
private _left = _until - time;

// A deadline further ahead than one full cooldown cannot have been stamped by this system against
// this clock, so it is a stale stamp rather than a live wait. Expired rather than left wedging
// that mission type for the rest of the campaign.
if (_left <= 0 || {_left > (missionNamespace getVariable ["mission_cooldown_seconds", 1800])}) exitWith { 0 };
_left
