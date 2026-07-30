// Locality: any -- broadcast. The server gates on it, the HQ readout and the strategic map both
// display it, and all three must agree on what "ready" means.
//
// In-game hours left on a side-mission type; 0 when it is ready.
//
// The clock is the campaign's own date, not diag_tickTime. Resting at HQ skips three in-game
// hours, and a cooldown counted in real seconds is untouched by that -- the two were measuring
// different kinds of time, so no amount of resting could ever clear the board. dateToNumber
// returns the fraction of the year elapsed, which both setTimeMultiplier and skipTime move, and
// 8760 is the hours in a year. It also survives a savegame, where a diag_tickTime stamp does not
// (server/server_init.sqf carries the sweep that repairs the ones still on that clock).
//
// The year is deliberately left out of the figure. SQF numbers are 32-bit floats, so folding in
// a year number puts the stamp in the millions, where one unit of precision is worth more than
// the whole cooldown.
params ["_missionType"];

private _until = missionNamespace getVariable [format ["mission_cooldown_%1", _missionType], 0];
private _left = _until - ((dateToNumber date) * 8760);

// A stamp further ahead than one full cooldown means the in-game year rolled over between the
// stamp and this read, dropping the clock back to zero underneath it. Expired rather than left
// wedging that mission type for the rest of the campaign.
if (_left <= 0 || {_left > (missionNamespace getVariable ["mission_cooldown_hours", 3])}) exitWith { 0 };
_left
