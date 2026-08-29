// Locality: client -- the closing half of both HQ placement modes (fnc_HQ_random_place.sqf,
// fnc_HQ_manual_place.sqf), which differ only in how PosOfBLUHQ is arrived at. Reads that global
// rather than taking it as an argument: it is published by the time either caller gets here.
// Scheduled only -- it sleeps, and both callers are spawned.

// Temp marker so the player sees where the base landed before the map closes again.
_markername = "foo";
_markerstr = createMarker [str(_markername), PosOfBLUHQ];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "mil_flag";
str(_markername) setMarkerColor "ColorBlue";

sleep 2;

forceMap false;
[localize "STR_DUWS_T_k9kxtm85"] call fnc_map_prompt;
OnMapSingleClick "ClickedPos2 = _pos; clicked = true;";
waituntil {sleep 0.1; clicked or !(visiblemap)};
if (clicked) then {
	AO_direction = ClickedPos2;
	publicVariable "AO_direction";
	_markername2 = "foo2";
	_markerstr2 = createMarker [str(_markername2), AO_direction];
	_markerstr2 setMarkerShape "ICON";
	str(_markername2) setMarkerType "mil_flag";
	str(_markername2) setMarkerColor "ColorRed";
	sleep 2;
	deletemarker str(_markername2);
};
deletemarker str(_markername);
hint "";
[""] call fnc_map_prompt;
openMap [false, false];
titleCut ["", "BLACK FADED", 999];

// server_init.sqf gates the whole campaign on this flag, so it must be the last thing sent:
// everything it implies is already published above.
chosen_hq_placement = true;
publicVariable "chosen_hq_placement";
