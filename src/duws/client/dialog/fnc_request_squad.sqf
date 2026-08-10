// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp:85).

_sel = lbCurSel 2101;
if (_sel < 0) exitWith {};

// The section token rides in lbData -- "<HC|TF>:<type>" -- because tier-locked squads sort to the
// bottom and the row's position no longer names it. A heading or spacer carries no data.
_data = lbData [2101, _sel];
if (_data == "") exitWith {hint localize "STR_DUWS_T_9607znvh"};
_parts = _data splitString ":";
_task_force = (_parts select 0) == "TF";
_row = [_parts select 1] call DUWS_fnc_squadRow;
if (_row isEqualTo []) exitWith {hint localize "STR_DUWS_T_9607znvh"};
_row params ["", "_globalName", "_HCsquadtype", "", "_tier"];

_squad = missionNamespace getVariable [_globalName, []];
if (count _squad < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};
_cost = _squad select 1;
_grouptype = _squad select 0;

// Tier gate before the charge, the same lock the greyed row advertises.
if !(["BLU", _tier] call DUWS_fnc_ap_unlocked) exitWith {
	hint format [localize "STR_DUWS_T_tier_locked_hint", [_tier] call DUWS_fnc_tierName];
};

if (_task_force && hardcore_visibleZone_found == false) exitWith {hint localize "STR_DUWS_T_b20y3byh"};

_spawnPos = getpos player;
if (_task_force) then {_spawnPos = PosOfBLUHQ;};
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],300,400,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;

_TFname = [1] call fnc_random_name;
sleep 2;

// Charge before spawning: the server rules on affordability, so a refused request must
// not leave a squad standing.
if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};

if (_task_force) then {
	[_spawnPos, _grouptype, _TFname, _tier] remoteExec ["fnc_playerTF_spawn", 2, false];
} else {
	// Spawn, name, register and muster all happen on the server; it hands
	// hcSetGroup back here, since that needs this machine's own player.
	[_spawnPos, _grouptype, _HCsquadtype, player] remoteExec ["fnc_HCsquad_spawn", 2];
};

// if TF squad, exit
if (_task_force) exitWith {hint localize "STR_DUWS_T_0a6o9dsm" + _TFname};

hint localize "STR_DUWS_T_gu6cbc5f";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
