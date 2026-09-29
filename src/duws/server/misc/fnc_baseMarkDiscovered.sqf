// Locality: server. The marker is global, so one machine sets its text for all.
params ["_marker"];
_marker setMarkerText (markerText _marker + " (discovered)");
