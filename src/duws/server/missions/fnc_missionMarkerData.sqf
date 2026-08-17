// Locality: server -- called by every mission thread; those are spawned server-side or
// remoteExec'd to target 2. All seventeen threads call it, each right after its site resolves.

// One marker: an orange ellipse the size of the search radius. The task spawns at the circle's
// centre, so the circle both bounds the objective and points to it; an objective icon on top would
// only restate that centre. The circle is the radius ellipse a zone draws (fnc_createzone); a
// mission just leaves off the capture icon a zone carries on top of it.
//
// Drawn the moment a mission's ground is settled and never hidden: a side mission is somewhere the
// player is being sent, so the area is the briefing. Nothing has ever revealed it later -- the
// search payout hands out zone and town intel and knows nothing about missions.
//
// Returns the ellipse's name, which fnc_missionMarkerClear takes to remove it.
params ["_randomPos", "_radius"];

private _ellipse = format ["%1%2cache", round (_randomPos select 0), round (_randomPos select 1)];

// Cleared before it is drawn, not after it fails. The name is a rounded position, so a mission
// built where an earlier one left its marker behind asks for a name already in use -- and
// createMarker answers "" for that, which makes every styling call below throw on an empty name.
// On the map that reads as a mission with no area at all.
[_ellipse] call fnc_missionMarkerClear;

createMarker [str(_ellipse), _randomPos];
str(_ellipse) setMarkerShape "ELLIPSE";
str(_ellipse) setMarkerBrush "SolidBorder";
// Orange rather than the zones' red, so an objective does not read as ground to capture.
str(_ellipse) setMarkerColor "ColorOrange";
str(_ellipse) setMarkerSize [_radius, _radius];
str(_ellipse) setMarkerAlpha 0.3;

// Logged because a marker that does not appear leaves nothing else behind: setMarkerColor and
// setMarkerAlpha on a name matching no marker throw nothing and log nothing
// (docs/info/arma_engine_gotchas.md), so this line is the only proof the marker was drawn at all.
["INFO", "MISSION", format ["marked %1 at %2, radius %3", _ellipse, _randomPos, _radius]] call fnc_log;

// And read back on every machine that has a map, because the line above only proves the call was
// made here. This thread runs on the server, which in a client/server session is not the machine
// anyone is looking at, and its RPT is not the one the player reads. A marker that never arrived
// answers "" to markerShape, so the report tells the two failures apart: nothing drawn, or drawn
// and not rendered.
//
// Excludes a dedicated server, which has no map to hold one, and sleeps first: marker creation and
// this message are separate broadcasts with no ordering between them.
[[_ellipse], {
	params ["_e"];
	uiSleep 2;
	["INFO", "MISSION", format ["marker %1: shape=%2 colour=%3 alpha=%4 size=%5",
		_e, markerShape str(_e), markerColor str(_e), markerAlpha str(_e), markerSize str(_e)]] call fnc_log;
}] remoteExec ["spawn", [0,-2] select isDedicated];

_ellipse
