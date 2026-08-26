// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:147).
_position = _this select 0;
_size = _this select 1;
_cost  = _this select 2;

// A FOB is a forward base, so it is refused within 2 km of enemy ground -- any OPFOR-held zone or
// town in the OPFOR band. Checked before the survey and the charge so a bad site costs nothing but
// the hint; the comm item is handed back the same way the other refusals below do.
if ([_position] call fnc_pos_near_enemy) exitWith {
  hint localize "STR_DUWS_T_too_close_enemy";
  sleep 15;
  ["fob_support"] call fnc_support_comm_add;
};

// Advisory only -- it saves a player with no CP the 10 s site survey below. The charge
// itself is the server's call, once a site has been cleared.
if (commandpointsblu1 < _cost) exitWith {
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
  sleep 15;
  ["fob_support"] call fnc_support_comm_add;
};

_tooMany = false;
private _maxFOB = floor(amount_zones_created * 0.7); // 70%, rounded down
if (count Array_of_FOBS >= _maxFOB) then {
    ["info",[localize "STR_DUWS_T_m7h89a4s",format[localize "STR_DUWS_T_6vjxo4eb",_maxFOB]]] call bis_fnc_showNotification;
    sleep 15;
    ["fob_support"] call fnc_support_comm_add;
    _tooMany = true;
};

if (_tooMany) exitWith {};

[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_cp9cw550", "", name player] remoteExec ["fnc_duws_dialogue", 0];
_triggerSize = _size / 4;
_trg=createTrigger["EmptyDetector",_position];
_trg setTriggerArea[_triggerSize,_triggerSize,0,false];
_trg setTriggerActivation["EAST","PRESENT",true];
_trg setTriggerStatements["this", "", ""];
sleep 10;
_amountOPFOR = count list _trg;

deleteVehicle _trg;

if (_amountOPFOR > 0) exitWith {
	[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_8zn96920"] remoteExec ["fnc_duws_dialogue", 0];
	sleep 15;
	["fob_support"] call fnc_support_comm_add;
};

// try to find a pos, if no pos is found exit the script
_direction = direction player;
_newpos = [_position, 20, _direction] call BIS_fnc_relPos;
_foundPickupPos = _newpos;
// The survey above takes 10 s, so the balance read at the top of this file is long stale
// by now; this is the read that decides.
if !(["CP", _cost] call fnc_pool_spend) exitWith {
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
  sleep 15;
  ["fob_support"] call fnc_support_comm_add;
};
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_1k60dqrv"] remoteExec ["fnc_duws_dialogue", 0];

[_foundPickupPos, _size, (vehicleVarname player)] remoteExec ["fnc_fob_server", 2];

sleep 600;
["fob_support"] call fnc_support_comm_add;


