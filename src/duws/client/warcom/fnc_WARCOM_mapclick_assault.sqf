// Locality: client -- invoked from a dialog action.

//  SET THE FIRST ZONE FOR BLUFOR TO ASSAULT
//  THE REST ARE ORDERED BY DISTANCE FROM HQ

_pos = [];
hint localize "STR_DUWS_T_0v7xnprx";
openMap true;

clicked = false;
OnMapSingleClick "ClickedPos = _pos; clicked = true;";	
_found_distance = false;

waituntil {sleep 0.1;clicked or !(visiblemap)};
if (!visibleMap) exitwith {
	hint localize "STR_DUWS_T_26hvx0yt";
};

// CLICKED OR ESCAPE

if (clicked) then {
	openMap false;
	hint "";
	// findIf rather than forEach with a break: the loop used to stop on
	// BLUFOR_primary_chg, which fnc_AI_Master_Control also sets, so a click was
	// silently dropped whenever that flag happened to be true on entry.
	private _i = WARCOM_zones_controled_by_OPFOR findIf {(ClickedPos distance _x) < 150};
	if (_i >= 0) then {
		// Reorder on the server: this runs on the clicking player's machine, and
		// it would otherwise iterate the very list it mutates and rebroadcast it.
		[WARCOM_zones_controled_by_OPFOR select _i] remoteExec ["fnc_warcom_set_primary_zone", 2];
		// tell GPS marker loop to change primary
		BLUFOR_primary_chg = true;
		publicVariable "BLUFOR_primary_chg";
		//wait until the gps loops (4sec) finish
		sleep 4.1;
		BLUFOR_primary_chg = false;
		publicVariable "BLUFOR_primary_chg";
	};
	_speaker = localize "STR_DUWS_T_OVERLORD";
    _message = localize "STR_DUWS_T_astchange";
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];

} else {
	hint "Cancelled";	
};
