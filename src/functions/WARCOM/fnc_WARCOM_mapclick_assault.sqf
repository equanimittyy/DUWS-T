
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
	{
		if ((ClickedPos distance _x) < 150) then {
			
			// Remove the clicked zone
			WARCOM_zones_controled_by_OPFOR deleteAt _forEachIndex;
			// Sort the rest of the zones by distance to HQ
			WARCOM_zones_controled_by_OPFOR = [WARCOM_zones_controled_by_OPFOR,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
			// Insert the clicked zone at index 0
			WARCOM_zones_controled_by_OPFOR insert [0, [_x]];
			publicVariable "WARCOM_zones_controled_by_OPFOR";
			// tell GPS marker loop to change primary
			BLUFOR_primary_chg = true;
			publicVariable "BLUFOR_primary_chg";
			//wait until the gps loops (4sec) finish
			sleep 4.1;
		};
		if (BLUFOR_primary_chg == true) exitWith {BLUFOR_primary_chg = false;publicVariable "BLUFOR_primary_chg"};
	} forEach WARCOM_zones_controled_by_OPFOR;
	_speaker = localize "STR_DUWS_T_OVERLORD";
    _message = localize "STR_DUWS_T_astchange";
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];

} else {
	hint "Cancelled";	
};
