// Locality: client -- sent by the server's operative claim (server/operative/fnc_operator_roster.sqf) to the player
// who asked, with the row as the server holds it, since this client's copy can be a broadcast behind.
params ["_selected_soldier_index", "_selected_soldier"];

_selected_soldier_aim = _selected_soldier select 0;
_selected_soldier_reflexes = _selected_soldier select 1;
_selected_soldier_spotting = _selected_soldier select 2;
_selected_soldier_courage = _selected_soldier select 3;
_selected_soldier_comms = _selected_soldier select 4;
_selected_soldier_reload = _selected_soldier select 5;

_selected_soldier_name = _selected_soldier select 8;
_selected_soldier_identity = _selected_soldier select 9;
_selected_soldier_class = missionNamespace getVariable (_selected_soldier select 10);

// The operative menu opens only from the request menu, so its context names the base.
// respawn_west stands at the HQ rest tent (fnc_BluHQinit).
(uiNamespace getVariable ["DUWS_requestMenu_ctx", []]) params ["", ["_isFob", false]];
_spawnPos = if (_isFob) then {[getPos player select [0, 2], 50] call fnc_safe_pos} else {getMarkerPos "respawn_west"};
_group = [_spawnPos, WEST, [_selected_soldier_class]] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_soldier = units _group select 0;
// loadAIS ignores AIS's own ACE shutdown and strips every HandleDamage handler, ACE medical's included.
if (!ais_ace_shutDown && {(["Revive", 1] call BIS_fnc_getParamValue) != 0}) then {
	[_soldier] call AIS_System_fnc_loadAIS;
};

addswitchableUnit _soldier;
// The roster keeps what was paid, so the unit carries no DUWS_hireCP for the cleanup and the save's refunds skip it.
_soldier setVariable ["DUWS_operative", true, true];

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
_soldier setskill ["general",(_selected_soldier select [0, 6]) call BIS_fnc_arithmeticMean];

// The soldier's stored hat (index 11 of duws_operator_list) is not applied; recruited operatives spawn bare-headed.

{[_x] joinSilent (group player)} forEach units _group;
hint format [localize "STR_DUWS_T_PURCHASED_UNIT", _selected_soldier_name];

[_soldier, _selected_soldier_index] remoteExec ["DUWS_fnc_operatorWatch", 2];
