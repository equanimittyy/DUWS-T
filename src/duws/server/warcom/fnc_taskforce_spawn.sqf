// Locality: server. Caller: fnc_taskforce_tick, when the free task force is due.
private _section = switch ([WARCOM_blufor_ap_earned] call DUWS_fnc_ap_tier) do {
	case 1: { blufor_INF_SQUAD_X };
	case 2: { blufor_MOTOR_SECTION_X };
	case 3: { selectRandom [blufor_MECH_SECTION_X, blufor_MECH_SECTION_X, blufor_MOTOR_SECTION_X] };
	default { selectRandom [blufor_ARMOR_SECTION_X, blufor_ARMOR_SECTION_X, blufor_MECH_SECTION_X, blufor_MOTOR_SECTION_X] };
};
private _pos = [WARCOM_blu_hq_pos, 300, 200, 15, 0.3] call fnc_safe_pos;
private _group = [_pos, WEST, _section select 0, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
if (vehicle leader _group != leader _group) then { _group addVehicle (vehicle leader _group) };

private _tfName = [1] call fnc_random_name;
[_group, _tfName, true] call fnc_taskforce_create;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_DEPLOYED", _tfName]] remoteExec ["fnc_duws_dialogue", 0];

// A crew spawned into its hull can die on the collision.
{ _x allowDamage false } forEach units _group;
[_group] spawn {
	params ["_group"];
	sleep 15;
	{ _x allowDamage true } forEach units _group;
};
