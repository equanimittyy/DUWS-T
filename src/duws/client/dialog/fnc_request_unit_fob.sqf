// Locality: client -- invoked from a dialog action (shared/includes/request_fob_menu.hpp:77).
_index = lbCurSel 2120;

_skill = (blufor_ai_skill select 0)+0.2;
_skillSF = (blufor_ai_skill select 0)+0.5;
_spawnPos = getpos player;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],150,200,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;

///  5 UNITS MAX

if (_index < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};

if (_index > 10) then {
	_var = "blufor_RQST_UNIT_" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
} else {
	_var = "blufor_RQST_UNIT_0" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
};	
_unitType = missionNamespace getVariable [_var, []];
// Refused before the spend: a row with no faction entry behind it must not charge CP, and
// `select 2` on the missing entry would otherwise throw with nothing said to the player.
if (_unitType isEqualTo []) exitWith {hint localize "STR_DUWS_T_9607znvh"};

if !(["CP", _unitType select 2] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_unitready"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
ctrlSetText [1000, format["%1",commandpointsblu1]];
_group = group player ;
(_unitType select 0) createUnit [_spawnpos, _group, "if (player_fatigue == 0) then {this enablefatigue false};", _skill, "private"];
{
	_x allowDamage false;
} forEach (units _group);
sleep 15;
{
	_x allowDamage true;
} forEach (units _group);
