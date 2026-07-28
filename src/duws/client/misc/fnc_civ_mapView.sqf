// Locality: the client that used the board. Opens the map in town-readout mode, where every
// click is a question for the server -- this machine holds none of the civilian data.
if (!hasInterface) exitWith {};

// The engine keeps exactly one onMapSingleClick handler, and the base fast-travel action on
// this same board owns it while it runs. Refusing here is what stops the second action
// silently stealing the first one's click and stranding it.
if (!isNil "DUWS_baseTravelMapOpen" && {DUWS_baseTravelMapOpen}) exitWith {
	hint localize "STR_DUWS_T_FAST_TRAVEL_BUSY";
};
if (!isNil "DUWS_civMapViewOpen" && {DUWS_civMapViewOpen}) exitWith {};
DUWS_civMapViewOpen = true;

openMap true;
[localize "STR_DUWS_T_civ_mapview_open"] call fnc_map_prompt;

// Returns true to swallow the click: the default action places a waypoint marker, and this
// mode is a reader.
onMapSingleClick {
	params ["_pos"];
	[_pos, player] remoteExec ["fnc_civ_townQuery", 2];
	true
};

// The mode ends when the player closes the map, which the engine gives no callback for.
[] spawn {
	waitUntil { !visibleMap };
	onMapSingleClick "";
	// Orphans any readout timer still counting: its banner died with the map display, and a
	// stale one firing later would clear whatever is drawn then.
	uiNamespace setVariable ["DUWS_civ_mapInfo_seq",
		(uiNamespace getVariable ["DUWS_civ_mapInfo_seq", 0]) + 1];
	DUWS_civMapViewOpen = nil;
};
