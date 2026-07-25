_position = _this select 0;
_size = _this select 1;
_cost  = _this select 2;

// Advisory only -- it saves a player with no CP the 10 s site survey below. The charge
// itself is the server's call, once a site has been cleared.
if (commandpointsblu1 < _cost) exitWith {
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
  sleep 15;
  _art = [player,"fob_support"] call BIS_fnc_addCommMenuItem;
};

// Make sure not too many FOBs
_tooMany = false;
private _maxFOB = floor(amount_zones_created * 0.7); // 70% 向下取整
if (count Array_of_FOBS >= _maxFOB) then {
    ["info",[localize "STR_DUWS_T_m7h89a4s",format[localize "STR_DUWS_T_6vjxo4eb",_maxFOB]]] call bis_fnc_showNotification;
    sleep 15;
    _art = [player,"fob_support"] call BIS_fnc_addCommMenuItem;
    _tooMany = true;
};

if (_tooMany) exitWith {};

// CHECK FOR GOOD LOCATION
Hint localize "STR_DUWS_T_cp9cw550";
[localize "STR_DUWS_T_cp9cw550"] spawn fnc_sideChat_filter;
_triggerSize = _size / 4;
_trg=createTrigger["EmptyDetector",_position];
_trg setTriggerArea[_triggerSize,_triggerSize,0,false];
_trg setTriggerActivation["EAST","PRESENT",true];
_trg setTriggerStatements["this", "", ""];
sleep 10;
_amountOPFOR = count list _trg;

deleteVehicle _trg;

if (_amountOPFOR > 0) exitWith {
	Hint localize "STR_DUWS_T_8zn96920";
	[localize "STR_DUWS_T_8zn96920"] spawn fnc_sideChat_filter;
	sleep 15;
	_art = [player,"fob_support"] call BIS_fnc_addCommMenuItem;
};

// try to find a pos, if no pos is found exit the script
_direction = direction player;
_newpos = [_position, 20, _direction] call BIS_fnc_relPos;
//_foundPickupPos = [_newpos, 0,40,10,0,0.2,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos
//_foundPickupPos = [_newpos, 0,10,0,0,0.25,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos
//if ((0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) || ((count nearestObjects [_foundPickupPos, [], 10]) > 0))
//	exitWith {hint localize "STR_DUWS_T_lqsyni7b"; sleep 5; _art = [player,"fob_support"] call BIS_fnc_addCommMenuItem;};
_foundPickupPos = _newpos;
// FOUND GOOD LOCATION
// The survey above takes 10 s, so the balance read at the top of this file is long stale
// by now; this is the read that decides.
if !(["CP", _cost] call fnc_pool_spend) exitWith {
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
  sleep 15;
  _art = [player,"fob_support"] call BIS_fnc_addCommMenuItem;
};
[localize "STR_DUWS_T_1k60dqrv"] spawn fnc_sideChat_filter;

// SPAWN FOB ON SERVER
[_foundPickupPos, _size, (vehicleVarname player)] remoteExec ["fnc_fob_server", 2];

sleep 600;
_null = [player,"fob_support"] call BIS_fnc_addCommMenuItem;


