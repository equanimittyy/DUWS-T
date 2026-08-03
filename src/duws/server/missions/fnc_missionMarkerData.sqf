// Locality: server -- called by every mission thread; those are spawned server-side or
// remoteExec'd to target 2. All seventeen threads call it, each right after its site resolves.

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

private _ellipse = format ["%1%2cache", round (_randomPos select 0), round (_randomPos select 1)];

// Cleared before it is drawn, not after it fails. The name is a rounded position, so a mission
// built where an earlier one left its markers behind asks for a name already in use -- and
// createMarker answers "" for that, which makes every styling call below throw on an empty name and
// takes the icon down with the ellipse. On the map that reads as a mission with no area at all.
[_ellipse] call fnc_missionMarkerClear;

createMarker [str(_ellipse), _randomPos];
str(_ellipse) setMarkerShape "ELLIPSE";
str(_ellipse) setMarkerBrush "SolidBorder";
str(_ellipse) setMarkerColor "ColorOrange";
str(_ellipse) setMarkerSize [_radius, _radius];
str(_ellipse) setMarkerAlpha 0.3;

// Orange rather than the zones' red, so an objective does not read as ground to capture.
private _icon = _ellipse + "icon";
createMarker [str(_icon), _randomPos];
str(_icon) setMarkerShape "ICON";
str(_icon) setMarkerType "hd_objective";
str(_icon) setMarkerColor "ColorOrange";
str(_icon) setMarkerSize [0.6, 0.6];

// Logged because a marker that does not appear leaves nothing else behind: setMarkerColor and
// setMarkerAlpha on a name matching no marker throw nothing and log nothing
// (docs/info/arma_engine_gotchas.md), so this line is the only proof the pair was drawn at all.
["INFO", "MISSION", format ["marked %1 at %2, radius %3", _ellipse, _randomPos, _radius]] call fnc_log;

// And read back on every machine that has a map, because the line above only proves the call was
// made here. This thread runs on the server, which in a client/server session is not the machine
// anyone is looking at, and its RPT is not the one the player reads. A marker that never arrived
// answers "" to markerShape, so the report tells the two failures apart: nothing drawn, or drawn
// and not rendered.
//
// Excludes a dedicated server, which has no map to hold one, and sleeps first: marker creation and
// this message are separate broadcasts with no ordering between them.
[[_ellipse, _icon], {
	params ["_e", "_i"];
	uiSleep 2;
	["INFO", "MISSION", format ["marker %1: shape=%2 colour=%3 alpha=%4 size=%5 -- icon %6 shape=%7 type=%8",
		_e, markerShape str(_e), markerColor str(_e), markerAlpha str(_e), markerSize str(_e),
		_i, markerShape str(_i), markerType str(_i)]] call fnc_log;
}] remoteExec ["spawn", [0,-2] select isDedicated];

_ellipse
