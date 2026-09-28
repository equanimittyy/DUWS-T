// Locality: any -- broadcast. The server gates on it and the strategic map displays it, and both
// must agree on what "ready" means.
//
// In-game hours until the next side mission may start; 0 when it is ready.
//
// A rolling window: it opens when the oldest start that still counts ages out. The clock is the
// campaign date (dateToNumber date), not `time`, so anything that moves the in-game clock moves it.
// Resting at HQ skips three in-game hours (skiptime 3) and so clears the gate in one go -- the
// intended shortcut -- and the date also advances on its own as the day/night cycle runs, so simply
// playing on clears it too. dateToNumber is a fraction of the year; 8760 h is one 365-day year,
// exact for the campaign's 2035 start (not a leap year), and the in-game clock never runs long
// enough to reach the next.

private _stamps = missionNamespace getVariable ["DUWS_missionStartDates", []];
private _allowance = missionNamespace getVariable ["mission_gate_allowance", 2];
if (count _stamps < _allowance) exitWith { 0 };

private _elapsedH = (dateToNumber date - (_stamps select (count _stamps - _allowance))) * 8760;
private _left = (missionNamespace getVariable ["mission_gate_hours", 3]) - _elapsedH;

// Negative elapsed means the in-game year rolled past the stamp -- far more time than the gate, not
// less -- so treat it as ready rather than let a wrapped fraction wedge missions shut for good.
if (_elapsedH < 0 || _left <= 0) exitWith { 0 };
_left
