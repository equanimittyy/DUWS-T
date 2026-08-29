// Locality: client; the map-click body below runs on the machine that triggers it, not
// here (passed as an addAction function value in client/supports/taxi/fnc_boatTaxi.sqf).
_timer = 9999999;
clicked = false;
_helo = _this select 0;
_actionID = _this select 2;
  
// Claimed before the action is removed: a refusal must leave the player able to try again.
if (!(["BOATTAXI", "ClickedTaxiPos = _pos; clicked = true;"] call fnc_mapclick_claim)) exitWith {};
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxiwp_brief"] remoteExec ["fnc_duws_dialogue", 0];
_helo removeAction _actionID;



while {_timer>0} do {
    if (clicked) then {
    _foundPickupPos = [ClickedTaxiPos, 0,50,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

    if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) then {
		if (ClickedTaxiPos distance player < 100) exitWith {
		clicked = false;
		[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxiwp_close"] remoteExec ["fnc_duws_dialogue", 0];
		};
	clicked = false;
	[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxiwp_bad"] remoteExec ["fnc_duws_dialogue", 0];
	}
	else
	{["BOATTAXI"] call fnc_mapclick_release;_timer = 0;taxiCanTakeOff = true;}
    
    };
  _timer = _timer-1;
  sleep 0.5;
};

// Catch-all: the loop can also fall out on timer expiry, which passes no release.
["BOATTAXI"] call fnc_mapclick_release;
