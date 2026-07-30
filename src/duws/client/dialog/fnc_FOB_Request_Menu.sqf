// Locality: client -- passed as an addAction function value in
// shared/functions/fnc_FOBactions.sqf, so it runs on whoever opens the menu.
// case #

_handle = createDialog "ressourceheader2";
waitUntil {dialog};
ctrlSetText [1000, format["%1",commandpointsblu1]];
ctrlSetText [1001, format["%1",zoneundercontrolblu]];
ctrlSetText [1002, format["%1",WARCOM_blufor_ap]];

// REQUEST UNITS - 5 MAX
_index = lbAdd [2120, localize "STR_DUWS_T_zo6ih0pt"]; 					// 0
_index = lbAdd [2120, ""]; 									// 1

_var_count = 1;  // 99 max
_unit_count = 1;  // 5 max
while {true} do {
	if (_unit_count > 5) exitWith {};
	if (_var_count > 99) exitWith {};
	if (_var_count > 9) then {
		_var = "blufor_RQST_UNIT_" + str _var_count + "_X"; // Parse the name of the variable as a string
	} else {
		_var = "blufor_RQST_UNIT_0" + str _var_count + "_X"; // Parse the name of the variable as a string
	};
	if (isNil _var) exitWith {}; // Get the vehicle variable
	_unitArray = missionNamespace getVariable _var;
	if (_unitArray select 0 == "empty" || _unitArray select 2 == 0) exitWith {}; 
	_displayName = [configFile >> "CfgVehicles" >> (_unitArray select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2120, _displayName  + " (" + str (_unitArray select 2) + "cp)"];
	_var_count = _var_count + 1;
	_unit_count = _unit_count + 1;
};

lbSetCurSel [2120, 0];

// REQUEST SQUADS
switch (VERSION_X) do {
	case "MODERN": {  // - 10 Squads MAX
		_index0 = lbAdd [2121, localize "STR_DUWS_T_zo6ih0pt"]; 			// 0
		_index0 = lbAdd [2121, ""];              							// 1
		_index0 = lbAdd [2121, "HC " + (blufor_RECON_TEAM_X select 1)];		// 2
		_index0 = lbAdd [2121, "HC " + (blufor_INF_SQUAD_X select 1)];		// 3
		_index0 = lbAdd [2121, "HC " + (blufor_MOTOR_SECTION_X select 1)];	// 4
		_index0 = lbAdd [2121, ""];              							// 5
		_index0 = lbAdd [2121, "TF " + (blufor_RECON_TEAM_X select 1)];		// 6
		_index0 = lbAdd [2121, "TF " + (blufor_INF_SQUAD_X select 1)];		// 7
		_index0 = lbAdd [2121, "TF " + (blufor_MOTOR_SECTION_X select 1)];	// 8
		_index0 = lbAdd [2121, "TF " + (blufor_MECH_SECTION_X select 1)];	// 9
		_index0 = lbAdd [2121, "TF " + (blufor_ARMOR_SECTION_X select 1)];	// 10
	};
};
	
lbSetCurSel [2121, 0];

// REQUEST VEHICLES - 10 MAX
_index1 = lbAdd [2122, localize "STR_DUWS_T_zo6ih0pt"]; 					// 0
_index1 = lbAdd [2122, ""];              									// 1
_var_count = 1;
_veh_count = 1;  // 10 max
while {true} do {
	if (_veh_count > 10) exitWith {};
	if (_var_count > 99) exitWith {};
	if (_var_count > 9) then {
		_var = "blufor_RQST_VEHICLE_" + str _var_count + "_X"; // Parse the name of the variable as a string
	} else {
		_var = "blufor_RQST_VEHICLE_0" + str _var_count + "_X"; // Parse the name of the variable as a string
	};
	if (isNil _var) exitWith {}; 
	_vehArray = missionNamespace getVariable _var;
	if (_vehArray select 0 == "empty" || _vehArray select 2 == 0) exitWith {}; 
	_displayName = [configFile >> "CfgVehicles" >> (_vehArray select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2122, _displayName  + " (" + str (_vehArray select 2) + "cp)"];
	_var_count = _var_count + 1;
	_veh_count = _veh_count + 1;
};

lbSetCurSel [2122, 0];
