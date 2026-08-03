// Locality: server -- called by every mission thread; those are spawned server-side or
// remoteExec'd to target 2.

// Two markers, and both are needed. The ellipse shows the radius the objective is somewhere inside;
// the icon is the thing a player actually spots on a map covered in zones and towns. The icon was
// dropped once on the reasoning that the task's own marker replaced it, and a side mission has had
// nothing findable on the map since -- a task marker is drawn for whoever holds the task and in the
// state the engine decides, where a map marker is simply there.
//
// Drawn the moment a mission's ground is settled and never hidden: a side mission is somewhere the
// player is being sent, so the area is the briefing. Nothing has ever revealed it later -- the
// search payout hands out zone and town intel and knows nothing about missions.
//
// Returns the ellipse's name. The icon's is that name plus a suffix, which is what lets
// fnc_missionMarkerClear take one name and remove both.
params ["_randomPos", "_radius"];

_markername2 = format["%1%2cache",round(_randompos select 0),round(_randompos select 1)]; // Define marker name
_markerstr2 = createMarker [str(_markername2), _randompos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
str(_markername2) setMarkerColor "ColorOrange";
str(_markername2) setMarkerSize [_radius, _radius];
str(_markername2) setMarkerAlpha 0.3;

// Orange rather than the zones' red, so an objective does not read as ground to capture.
_iconName = _markername2 + "icon";
createMarker [str(_iconName), _randompos];
str(_iconName) setMarkerShape "ICON";
str(_iconName) setMarkerType "hd_objective";
str(_iconName) setMarkerColor "ColorOrange";
str(_iconName) setMarkerSize [0.6, 0.6];

_markername2;
