// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp:74).
_index = lbCurSel 2100;

_skill = blufor_ai_skill_random;

// respawn_west stands at the HQ rest tent (fnc_BluHQinit).
(uiNamespace getVariable ["DUWS_requestMenu_ctx", []]) params ["", ["_isFob", false]];
_spawnPos = if (_isFob) then {[getPos player select [0, 2], 50] call fnc_safe_pos} else {getMarkerPos "respawn_west"};

if (_index < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};

_unitType = (["UNIT"] call fnc_faction_rqst_list) param [_index - 2, []];
// Refused before the spend: a row with no faction entry behind it must not charge CP, and
// `select 2` on the missing entry would otherwise throw with nothing said to the player.
if (_unitType isEqualTo []) exitWith {hint localize "STR_DUWS_T_9607znvh"};

if !(["CP", _unitType select 2] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};

hint format [localize "STR_DUWS_T_PURCHASED_UNIT", [configFile >> "CfgVehicles" >> (_unitType select 0)] call BIS_fnc_displayName];
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
