
params ["_randomPos", "_markerText", "_markerText2", "_radius"];

// CREATE MARKER (ICON)
_markername = format["%1%2%3",_markerText,round(_randomPos select 0),round(_randomPos select 1)]; // Define marker name
_markerstr = createMarker [str(_markername), _randompos];
_markerstr setMarkerShape "ICON";

str(_markername) setMarkerType "hd_objective";
str(_markername) setMarkerSize [.6,.6];
str(_markername) setMarkerColor "Color3_FD_F";
str(_markername) setMarkerText " "+_markerText2;

// CREATE MARKER (ELLIPSE ZONE)
_markername2 = format["%1%2cache",round(_randompos select 0),round(_randompos select 1)]; // Define marker name
_markerstr2 = createMarker [str(_markername2), _randompos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
str(_markername2) setMarkerColor "Color3_FD_F";
str(_markername2) setMarkerSize [_radius, _radius];
str(_markername2) setMarkerAlpha 0.3; 

_returnArray = [_markername, _markername2];
_returnArray;
