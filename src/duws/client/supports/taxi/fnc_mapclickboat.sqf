// Locality: client; the map-click body below runs on the machine that triggers it, not
// here (passed as an addAction function value in client/supports/taxi/fnc_boatTaxi.sqf).
_timer = 9999999;
clicked = false;
_helo = _this select 0;
_actionID = _this select 2;
  
titleText [localize "STR_DUWS_T_boattaxiwp_brief", "PLAIN DOWN"];
OnMapSingleClick "ClickedTaxiPos = _pos; clicked = true;";
_helo removeAction _actionID;



// TIMER & MAPCLICK
while {_timer>0} do {
    if (clicked) then { // player has clicked the map
    _foundPickupPos = [ClickedTaxiPos, 0,50,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos

    if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) then {
		if (ClickedTaxiPos distance player < 100) exitWith {
		clicked = false;
		titleText [localize "STR_DUWS_T_boattaxiwp_close", "PLAIN DOWN"];
		};
	clicked = false;
	titleText [localize "STR_DUWS_T_boattaxiwp_bad", "PLAIN DOWN"];
	}
	else
	{onMapSingleClick "";_timer = 0;taxiCanTakeOff = true;}  
    
    };
  _timer = _timer-1; // remove 1 to timer
  sleep 0.5;
};
