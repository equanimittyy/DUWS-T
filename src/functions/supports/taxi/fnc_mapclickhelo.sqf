
_timer = 9999999;
clicked = false;
_helo = _this select 0;
_actionID = _this select 2;

openMap true;

while {_timer>0} do {

	waituntil {sleep 0.5;visiblemap};
	_playerClosed_map = false;

	titleText ["<t color='#00ff00' size='2'>Pilot: Give me 2 waypoints and an LZ, I'll see what i can do.</t>", "PLAIN DOWN", -1, true, true];
	_helo removeAction _actionID;

	// TIMER & MAPCLICK
	onMapSingleClick "";
	hint parseText localize "STR_DUWS_T_helotaxi2wp";

	OnMapSingleClick "ClickedPos1 = _pos; clicked = true;";

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
		onMapSingleClick "";
		hint localize "STR_DUWS_T_helotaxi1wpmarked";
		sleep 2;
	} else {
		hint "Open the map and try again.";
		_playerClosed_map = true;
	};
	
	if !(_playerClosed_map) then {
		OnMapSingleClick "ClickedPos2 = _pos; clicked = true;";
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
			onMapSingleClick "";
			hint localize "STR_DUWS_T_helotaxi2wpmarked";
			sleep 2;
		} else {
			deletemarker str(TaxiMarker1);
			hint "Open the map and try again.";
			_playerClosed_map = true;
		};
	};

	while {!taxiCanTakeOff} do {
		OnMapSingleClick "ClickedPos3 = _pos; clicked = true;";
		_playerClosed_map = false;
		waituntil {sleep 0.5;clicked or !(visiblemap)};
		if (clicked) then {
			_foundPickupPos = [ClickedPos3, 0,100,20,0,0.2,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos

			if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) then {
				clicked = false;
				titleText ["<t color='#ff0000' size='2'>Pilot: No clear LZ around here, give me another location</t>", "PLAIN DOWN", -1, true, true];
			} else {
				ClickedTaxiPos = _foundPickupPos;
				onMapSingleClick "";
				_timer = 0;
				taxiCanTakeOff = true;
			};    
		} else {
			_playerClosed_map = true;
		};
		if (_playerClosed_map) exitWith {
			hint "Open the map and try again.";
			deletemarker str(TaxiMarker1);
			deletemarker str(TaxiMarker2);
		};
	};
	_timer = _timer-1; // remove 1 to timer
	sleep 0.5;
	if (taxiCanTakeOff) exitWith{};
};	
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		