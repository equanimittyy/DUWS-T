// Locality: client; the map-click bodies below run on the machine that triggers them, not
// here (passed as an addAction function value in client/supports/taxi/fnc_helotaxi.sqf).

_timer = 9999999;
clicked = false;
_helo = _this select 0;
_actionID = _this select 2;

openMap true;

while {_timer>0} do {

	waituntil {sleep 0.5;visiblemap};
	_playerClosed_map = false;

	// Claimed before the action is removed: a refusal must leave the player able to try again.
	if (!(["TAXI", "ClickedPos1 = _pos; clicked = true;"] call fnc_mapclick_claim)) exitWith {};
	titleText [format ["<t color='#00ff00' size='2'>%1</t>", localize "STR_DUWS_T_helotaxiwp_brief"], "PLAIN DOWN", -1, true, true];
	_helo removeAction _actionID;

	// TIMER & MAPCLICK
	hint parseText localize "STR_DUWS_T_helotaxi2wp";

	TaxiMarker1 = "";
	TaxiMarker2 = "";
	waituntil {sleep 0.5;clicked or !(visiblemap)};
    if (clicked) then { // player has clicked the map
		// create temp marker on WP1
		TaxiMarker1 = "foo";
		_markerstr = createMarker [str(TaxiMarker1), ClickedPos1];
		_markerstr setMarkerShape "ICON";
		str(TaxiMarker1) setMarkerType "hd_objective";
		str(TaxiMarker1) setMarkerColor "ColorYellow";
		str(TaxiMarker1) setMarkerText "TaxiWP1";
	
		clicked = false;
		["TAXI"] call fnc_mapclick_release;
		hint localize "STR_DUWS_T_helotaxi1wpmarked";
		sleep 2;
	} else {
		hint localize "STR_DUWS_T_helotaxiwp_reopen";
		_playerClosed_map = true;
	};
	
	if !(_playerClosed_map) then {
		["TAXI", "ClickedPos2 = _pos; clicked = true;"] call fnc_mapclick_claim;
		waituntil {sleep 0.5;clicked or !(visiblemap)};
		if (clicked) then {
			// create temp marker on WP2
			TaxiMarker2 = "foo2";
			_markerstr2 = createMarker [str(TaxiMarker2), ClickedPos2];
			_markerstr2 setMarkerShape "ICON";
			str(TaxiMarker2) setMarkerType "hd_objective";
			str(TaxiMarker2) setMarkerColor "ColorYellow";
			str(TaxiMarker2) setMarkerText "TaxiWP2";

			clicked = false;
			["TAXI"] call fnc_mapclick_release;
			hint localize "STR_DUWS_T_helotaxi2wpmarked";
			sleep 2;
		} else {
			deletemarker str(TaxiMarker1);
			hint localize "STR_DUWS_T_helotaxiwp_reopen";
			_playerClosed_map = true;
		};
	};

	while {!taxiCanTakeOff} do {
		["TAXI", "ClickedPos3 = _pos; clicked = true;"] call fnc_mapclick_claim;
		_playerClosed_map = false;
		waituntil {sleep 0.5;clicked or !(visiblemap)};
		if (clicked) then {
			_foundPickupPos = [ClickedPos3, 0,100,20,0,0.2,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos

			if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) then {
				clicked = false;
				titleText [format ["<t color='#ff0000' size='2'>%1</t>", localize "STR_DUWS_T_helotaxiwp_nolz"], "PLAIN DOWN", -1, true, true];
			} else {
				ClickedTaxiPos = _foundPickupPos;
				["TAXI"] call fnc_mapclick_release;
				_timer = 0;
				taxiCanTakeOff = true;
			};    
		} else {
			_playerClosed_map = true;
		};
		if (_playerClosed_map) exitWith {
			hint localize "STR_DUWS_T_helotaxiwp_reopen";
			deletemarker str(TaxiMarker1);
			deletemarker str(TaxiMarker2);
		};
	};
	_timer = _timer-1; // remove 1 to timer
	sleep 0.5;
	if (taxiCanTakeOff) exitWith{};
};

// Catch-all for the exits above -- timer expiry and the player closing the map both leave the
// loops without passing a release. A release from a non-holder is a no-op, so the paths that
// already released are unaffected.
["TAXI"] call fnc_mapclick_release;
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		