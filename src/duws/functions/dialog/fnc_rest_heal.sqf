// Locality: server -- callers remoteExec to target 2.

{deleteVehicle _x} forEach allDeadMen;

// Heals the enemy also
{
	_x setdammage 0;
} forEach allUnits;

{
	if (isClass (configFile >> "CfgPatches" >> "ace_medical")) then {
		[_x] call ace_medical_treatment_fnc_fullHealLocal;
	};
	if (isClass (configFile >> "CfgPatches" >> "ace_main")) then {
		[_x] call ace_medical_treatment_fnc_fullHealLocal;
	};
} forEach call BIS_fnc_ListPlayers;

skiptime 3;
sleep 0.3;
    
[{hint localize "STR_DUWS_T_437x650k"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
sleep 2;
[] remoteExec ["fnc_bottom_right_message", [0,-2] select isDedicated,true];
sleep 30;