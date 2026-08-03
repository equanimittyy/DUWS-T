// Locality: server -- the mission threads that call it all run there.

// Removes both markers fnc_missionMarkerData drew, from the one name it handed back. A thread that
// deleted the ellipse by hand left the icon on the map for the rest of the campaign, and every such
// site had to spell str() itself -- the marker names carry literal quote characters
// (docs/info/arma_engine_gotchas.md), and an unquoted deleteMarker misses silently.
params ["_ellipse"];
if (isNil "_ellipse" || {!(_ellipse isEqualType "")} || {_ellipse isEqualTo ""}) exitWith {};

deleteMarker str(_ellipse);
deleteMarker str(_ellipse + "icon");
