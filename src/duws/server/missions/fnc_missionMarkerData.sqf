// Locality: server -- called by every mission thread; those are spawned server-side or
// remoteExec'd to target 2.

// Only the area ellipse is drawn. The objective icon this used to add alongside it is now the
// task's own marker, which carries the mission name and a type icon the marker never had; the
// ellipse stays because a task marker is a point and cannot show the mission radius.
//
// Drawn the moment a mission's ground is settled and never hidden: a side mission is somewhere the
// player is being sent, so the area is the briefing. Nothing has ever revealed it later -- the
// search payout hands out zone and town intel and knows nothing about missions.
params ["_randomPos", "_radius"];

_markername2 = format["%1%2cache",round(_randompos select 0),round(_randompos select 1)]; // Define marker name
_markerstr2 = createMarker [str(_markername2), _randompos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
// A named CfgMarkerColors class, not a literal: setMarkerColor takes the name of one, and a name no
// class answers to leaves the marker at whatever it was, which for a fresh area marker is nothing
// the player can see. Orange rather than the zones' red, so an objective does not read as ground to
// capture.
str(_markername2) setMarkerColor "ColorOrange";
str(_markername2) setMarkerSize [_radius, _radius];
str(_markername2) setMarkerAlpha 0.3;

_markername2;
