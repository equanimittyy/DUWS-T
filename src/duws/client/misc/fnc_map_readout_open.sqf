// Locality: the client that used the board. Opens the map in readout mode, where every click is a
// question for the server -- this machine holds neither the civilian data nor any zone's garrison
// state.
if (!hasInterface) exitWith {};

if (!isNil "DUWS_mapReadoutOpen" && {DUWS_mapReadoutOpen}) exitWith {};

// Returns true to swallow the click: the default action places a waypoint marker, and this
// mode is a reader. The claim refuses, and says so, if another map mode is mid-flight.
private _got = ["MAPREADOUT", {
	params ["_pos"];
	[_pos, player] remoteExec ["fnc_map_readout_query", 2];
	true
}] call fnc_mapclick_claim;
if (!_got) exitWith {};

DUWS_mapReadoutOpen = true;
openMap true;
[localize "STR_DUWS_T_civ_mapview_open"] call fnc_map_prompt;

// The mode ends when the player closes the map, which the engine gives no callback for.
[] spawn {
	waitUntil { !visibleMap };
	["MAPREADOUT"] call fnc_mapclick_release;
	// Orphans any readout timer still counting: its banner died with the map display, and a
	// stale one firing later would clear whatever is drawn then.
	uiNamespace setVariable ["DUWS_mapReadout_seq",
		(uiNamespace getVariable ["DUWS_mapReadout_seq", 0]) + 1];
	DUWS_mapReadoutOpen = nil;
};
