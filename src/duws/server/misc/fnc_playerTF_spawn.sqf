if (!isServer) exitWith {};
params ["_spawnPos","_grouptype","_TFname",["_tier",1]];

// Tier gate, matching the client's own refusal. A task force carries no squad-type the server can
// re-derive from, so the tier is passed rather than recomputed -- the same client-trust surface the
// vehicle and support gates already stand on.
if !(["BLU", _tier] call DUWS_fnc_ap_unlocked) exitWith {
	["WARN", "WARCOM", format ["TF squad tier %1 above BLUFOR earned; spawn refused", _tier]] call fnc_log;
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
// Keep units from dying on spawn
{
	_x allowDamage false;
} forEach (units _group);
sleep 15;
{
	_x allowDamage true;
} forEach (units _group);

[localize "STR_DUWS_T_OVERLORD", format[localize "STR_DUWS_T_32ci6fa1", _TFname]] remoteExec ["fnc_duws_dialogue", 0];
sleep 10; // give squads a chance to mount up
[_group] spawn fnc_WARCOM_wp_blu_assault;
[_group,_TFname] spawn fnc_WARCOM_gps_marker;

