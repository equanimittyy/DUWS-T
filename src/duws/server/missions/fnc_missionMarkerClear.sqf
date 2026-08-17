// Locality: server -- the mission threads that call it all run there.

// Removes the marker fnc_missionMarkerData drew, from the name it handed back. A thread that deleted
// it by hand and spelled the name itself missed silently -- the marker names carry literal quote
// characters (docs/info/arma_engine_gotchas.md), and an unquoted deleteMarker deletes nothing.
params ["_ellipse"];
if (isNil "_ellipse" || {!(_ellipse isEqualType "")} || {_ellipse isEqualTo ""}) exitWith {};

deleteMarker str(_ellipse);
