// Locality: client -- reached from the operative menu's onLBSelChanged via fnc_lbselected,
// and it reads lbCurSel and group player.
_selected_soldier = duws_operator_list select lbCurSel 1500;
_selected_soldier_index = lbCurSel 1500;

_selected_soldier_aim = _selected_soldier select 0;
_selected_soldier_reflexes = _selected_soldier select 1;
_selected_soldier_spotting = _selected_soldier select 2;
_selected_soldier_courage = _selected_soldier select 3;
_selected_soldier_comms = _selected_soldier select 4;
_selected_soldier_reload = _selected_soldier select 5;

_selected_soldier_status = _selected_soldier select 7;
_selected_soldier_name = _selected_soldier select 8;
_selected_soldier_identity = _selected_soldier select 9;
_selected_soldier_class = _selected_soldier select 10;

hint _selected_soldier_identity;

// Re-deploying an already-recruited, healed operative is free, so only "Ready"
// costs CP. The hint lives inside the guard because exitWith is transparent to
// switch and unwinds to the spawn scope: a flag checked after the switch could
// never be read.
switch (_selected_soldier_status) do
{
  case "Ready": {
	if !(["CP", 8] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_operative_no_cp"};
  };
};

_spawnPos = getpos player;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],200,300,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;
_group = [_spawnPos, WEST, [_selected_soldier_class]] call BIS_fnc_spawnGroup;
//_group = [[(getpos player select 0)-78, (getpos player select 1)-73.5], WEST, [_selected_soldier_class]] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_soldier = units _group select 0;
[_soldier] call AIS_System_fnc_loadAIS;

addswitchableUnit _soldier;

if (player_fatigue == 0) then {_soldier enablefatigue false;};

removeGoggles _soldier;

_soldier setidentity _selected_soldier_identity;

_soldier setskill ["aimingAccuracy",_selected_soldier_aim];
_soldier setskill ["aimingShake",_selected_soldier_aim];
_soldier setskill ["aimingSpeed",_selected_soldier_reflexes];
_soldier setskill ["spotDistance",_selected_soldier_spotting];
_soldier setskill ["spotTime",_selected_soldier_spotting];
_soldier setskill ["courage",_selected_soldier_courage];
_soldier setskill ["reloadSpeed",_selected_soldier_reload];
_soldier setskill ["commanding",_selected_soldier_comms];

// No headgear

{[_x] joinSilent (group player)} forEach units _group;

_selected_index = lbCurSel 1500;
lbSetColor [1500, _selected_index, [0, 1, 0, 1]];

duws_operator_list select lbCurSel 1500 set [7,"Operating"];
ctrlSetText [1013, format["%1",_selected_soldier_status]];

buttonSetAction [1601, "hint ""This operative is already active in this theatre of operation"""]; 
ctrlSetText [1601, "ALREADY DEPLOYED"];	


// wait until the operator is dead
waitUntil {sleep 5; !alive _soldier}; 

_soldier_timeheal = 60;
duws_operator_list select _selected_soldier_index set [12,_soldier_timeheal];
duws_operator_list select _selected_soldier_index set [7,"Injured"];

// the timer
for [{_timer=_soldier_timeheal}, {_timer>0}, {_timer=_timer-1}] do
{
    duws_operator_list select _selected_soldier_index set [12,_timer];
	sleep 1;
};
// soldier is healed
duws_operator_list select _selected_soldier_index set [12,0];
duws_operator_list select _selected_soldier_index set [7,"Healed"];
["info",[localize "STR_DUWS_T_OPERATOR_HEALED", _selected_soldier_name]] call bis_fnc_showNotification;