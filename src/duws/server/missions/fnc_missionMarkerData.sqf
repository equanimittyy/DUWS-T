// Locality: server -- called by every mission thread; those are spawned server-side or
// remoteExec'd to target 2.

// Only the area ellipse is drawn. The objective icon this used to add alongside it is now the
// task's own marker, which carries the mission name and a type icon the marker never had; the
// ellipse stays because a task marker is a point and cannot show the mission radius.
params ["_randomPos", "_radius"];

_markername2 = format["%1%2cache",round(_randompos select 0),round(_randompos select 1)]; // Define marker name
_markerstr2 = createMarker [str(_markername2), _randompos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
str(_markername2) setMarkerColor "Color3_FD_F";
str(_markername2) setMarkerSize [_radius, _radius];
str(_markername2) setMarkerAlpha 0.3;

_markername2;
