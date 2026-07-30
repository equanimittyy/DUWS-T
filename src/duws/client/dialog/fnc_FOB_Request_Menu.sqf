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

// A FOB offers the first five of the faction's units, not the full HQ list.
{
	_displayName = [configFile >> "CfgVehicles" >> (_x select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2120, _displayName  + " (" + str (_x select 2) + "cp)"];
} forEach ((["UNIT"] call fnc_faction_rqst_list) select [0, 5]);

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
// Ten vehicles at a FOB against the HQ's full list.
{
	_displayName = [configFile >> "CfgVehicles" >> (_x select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2122, _displayName  + " (" + str (_x select 2) + "cp)"];
} forEach ((["VEHICLE"] call fnc_faction_rqst_list) select [0, 10]);

lbSetCurSel [2122, 0];
