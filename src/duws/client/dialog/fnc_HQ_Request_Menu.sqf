// Locality: client -- passed as an addAction function value in
// client/misc/fnc_addHQLaptopActions.sqf, so it runs on whoever opens the menu.
// case #

_handle = createDialog "ressourceheader";
waitUntil {dialog};
ctrlSetText [1000, format["%1",commandpointsblu1]];
ctrlSetText [1001, format["%1",zoneundercontrolblu]];
ctrlSetText [1002, format["%1",WARCOM_blufor_ap]];

// REQUEST UNITS - 14 MAX
_index = lbAdd [2100, localize "STR_DUWS_T_zo6ih0pt"];      // 0
_index = lbAdd [2100, ""];                              	// 1

_var_count = 1;
while {true} do {
	_unitArray = [];
	_var = "";
	if (_var_count > 99) exitWith {};
	if (_var_count > 9) then {
		_var = "blufor_RQST_UNIT_" + str _var_count + "_X"; // Parse the name of the variable as a string
	} else {
		_var = "blufor_RQST_UNIT_0" + str _var_count + "_X"; // Parse the name of the variable as a string
	};
	if (isNil _var) exitWith {}; // Get the vehicle variable
	_unitArray = call (compile _var);
	if (_unitArray select 0 == "empty" || _unitArray select 2 == 0) exitWith {}; 
	_displayName = [configFile >> "CfgVehicles" >> (_unitArray select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2100, _displayName  + " (" + str (_unitArray select 2) + "cp)"];
	_var_count = _var_count + 1;
};
lbSetCurSel [2100, 0];

// REQUEST SQUADS
switch (VERSION_X) do {
	case "MODERN": {  // - 10 Squads MAX
		_index0 = lbAdd [2101, localize "STR_DUWS_T_zo6ih0pt"];     		// 0
		_index0 = lbAdd [2101, ""];                  						// 1
		_index0 = lbAdd [2101, "HC " + (blufor_RECON_TEAM_X select 1)];		// 2
		_index0 = lbAdd [2101, "HC " + (blufor_INF_SQUAD_X select 1)];		// 3
		_index0 = lbAdd [2101, "HC " + (blufor_MOTOR_SECTION_X select 1)];	// 4
		_index0 = lbAdd [2101, "HC " + (blufor_MECH_SECTION_X select 1)];	// 5
		_index0 = lbAdd [2101, "HC " + (blufor_ARMOR_SECTION_X select 1)];	// 6
		_index0 = lbAdd [2101, ""];                  						// 7
		_index0 = lbAdd [2101, "TF " + (blufor_RECON_TEAM_X select 1)];		// 8
		_index0 = lbAdd [2101, "TF " + (blufor_INF_SQUAD_X select 1)];		// 9
		_index0 = lbAdd [2101, "TF " + (blufor_MOTOR_SECTION_X select 1)];	// 10
		_index0 = lbAdd [2101, "TF " + (blufor_MECH_SECTION_X select 1)];	// 11
		_index0 = lbAdd [2101, "TF " + (blufor_ARMOR_SECTION_X select 1)];	// 12
	};
};
	
lbSetCurSel [2101, 0];

// REQUEST VEHICLES-STATICS - 50 MAX
_index1 = lbAdd [2102, localize "STR_DUWS_T_zo6ih0pt"]; 	// 0
_index1 = lbAdd [2102, ""];              					// 1

_var_count = 1;
while {true} do {
	_vehArray = "";
	_var = "";
	if (_var_count > 99) exitWith {};
	if (_var_count > 9) then {
		_var = "blufor_RQST_VEHICLE_" + str _var_count + "_X"; // Parse the name of the variable as a string
	} else {
		_var = "blufor_RQST_VEHICLE_0" + str _var_count + "_X"; // Parse the name of the variable as a string
	};
	if (isNil _var) exitWith {}; 
	_vehArray = call (compile _var);
	if (_vehArray select 0 == "empty" || _vehArray select 2 == 0) exitWith {}; 
	_displayName = [configFile >> "CfgVehicles" >> (_vehArray select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2102, _displayName  + " (" + str (_vehArray select 2) + "cp)"];
	_var_count = _var_count + 1;
};

lbSetCurSel [2102, 0];

// Supports  

index_support_supply = lbAdd [2103, localize "STR_DUWS_T_5n277nzo"];                 // 0
index_support_armory = lbAdd [2103, localize "STR_DUWS_T_kw2lnaig"];                      // 1

switch (VERSION_X) do {
	case "MODERN": {
		index_support_veh_supply = lbAdd [2103, localize "STR_DUWS_T_oq3q7yrq"];   // 2
	};
};

switch (VERSION_X) do {
	case "MODERN": {
		index_support_siva_supply = lbAdd [2103, localize "STR_DUWS_T_jjzzkt01"];   // 3
	};
};

index_support_sawp = lbAdd [2103, localize "STR_DUWS_T_sawp1234"];                 // 4

index_support_halo = lbAdd [2103, localize "STR_DUWS_T_xghf3qqd"];				          	 // 5

switch (VERSION_X) do {
	case "MODERN": {
		index_support_uavrecon = lbAdd [2103, localize "STR_DUWS_T_892wo8h0"];         // 6
	};
};	
switch (VERSION_X) do {
	case "MODERN": {
		index_support_helotaxi = lbAdd [2103, localize "STR_DUWS_T_witoiij3"];       // 7
	};
};
switch (VERSION_X) do {
	case "MODERN": {
		index_support_helolift = lbAdd [2103, localize "STR_DUWS_T_heloliftbuy"];       // 8
	};
};

index_support_boattaxi = lbAdd [2103, localize "STR_DUWS_T_3wiovyga"];               // 9
index_support_recycle = lbAdd [2103, localize "STR_DUWS_T_zaijvhuishouzhan1"];                    // 10
// 在现有列表末尾添加
index_support_repair = lbAdd [2103, localize "STR_DUWS_T_vehicle_repair"];
index_support_arty = lbAdd [2103, localize "STR_DUWS_T_btiiyafy"];                  // 11
index_support_mortar = lbAdd [2103, localize "STR_DUWS_T_xca5aaxu"];                // 12

switch (VERSION_X) do {
	case "MODERN": {
		index_support_jdam = lbAdd [2103, localize "STR_DUWS_T_mbhh2q2e"];           // 13
	};
};	
switch (VERSION_X) do {
	case "MODERN": {
		index_support_laser = lbAdd [2103, localize "STR_DUWS_T_xja6gemx"];		  	// 14
	};
};
switch (VERSION_X) do {
	case "MODERN": {
		index_support_cluster = lbAdd [2103, localize "STR_DUWS_T_d5qzh6mj"];    		// 15
	};
};

index_support_napalm = lbAdd [2103, localize "STR_DUWS_T_owven8ki"];       			// 16

switch (VERSION_X) do {
	case "MODERN": {
		index_support_hcAttChop = lbAdd [2103, localize "STR_DUWS_T_t4jo046q"];   	// 17
	};
};
switch (VERSION_X) do {
	case "MODERN": {
		index_support_hcCAS = lbAdd [2103, localize "STR_DUWS_T_6khosjp7"];        	// 18
	};
};

index_support_paradrop = lbAdd [2103, localize "STR_DUWS_T_9hmlads9"];              	// 19
private _mhqText = localize "STR_DUWS_T_b7gmddq3";
if (!isNil "insurgent_mode_enable" && insurgent_mode_enable) then {
    _mhqText = localize "STR_DUWS_T_b7gmddq3_free";
};
index_mobile_HQ = lbAdd [2103, _mhqText];

////////////////////////////////////////////
// Change menu colors
//  lbSetCurSel [2103, 0];
if (support_supplydrop_available) then {
    lbSetColor [2103, 0, [0, 1, 0, 1]];
};
if (support_armory_available) then {
    lbSetColor [2103, 1, [0, 1, 0, 1]];
};
if (support_veh_drop_available) then {
    lbSetColor [2103, 2, [0, 1, 0, 1]];
};
if (support_siva_drop_available) then {
    lbSetColor [2103, 3, [0, 1, 0, 1]];
};
if (support_sawp_drop_available) then {
    lbSetColor [2103, 4, [0, 1, 0, 1]];
};
if (support_halo_available) then {
	lbSetColor [2103, 5, [0, 1, 0, 1]];
};
if (support_uav_recon_available) then {
    lbSetColor [2103, 6, [0, 1, 0, 1]];
};
if (support_helotaxi_available) then {
    lbSetColor [2103, 7, [0, 1, 0, 1]];
};
if (support_helolift_available) then {
    lbSetColor [2103, 8, [0, 1, 0, 1]];
};
if (support_boattaxi_available) then {
    lbSetColor [2103, 9, [0, 1, 0, 1]];
};
if (support_veh_recycle_available) then {
    lbSetColor [2103, 10, [0, 1, 0, 1]];
};
if (support_veh_repair_available) then {
    lbSetColor [2103, 11, [0, 1, 0, 1]];
};
if (support_arty_available) then {
    lbSetColor [2103, 12, [0, 1, 0, 1]];
};
if (support_mortar_available) then {
    lbSetColor [2103, 13, [0, 1, 0, 1]];
};
if (support_jdam_available) then {
    lbSetColor [2103, 14, [0, 1, 0, 1]];
};
if (support_laser_available) then {
    lbSetColor [2103, 15, [0, 1, 0, 1]];
};
if (support_cluster_available) then {
    lbSetColor [2103, 16, [0, 1, 0, 1]];
};
if (support_napalm_available) then {
    lbSetColor [2103, 17, [0, 1, 0, 1]];
};
if (support_hcAttChop_available) then {
	lbSetColor [2103, 18, [0, 1, 0, 1]];
};
if (support_hcCAS_available) then {
	lbSetColor [2103, 19, [0, 1, 0, 1]];
};
if (support_paradrop_available) then {
    lbSetColor [2103, 20, [0, 1, 0, 1]];
};
if (!support_mobile_HQ_available) then {
    lbSetColor [2103, 21, [0, 1, 0, 1]];
};
// 叛军模式下禁用部分支援（置灰显示）
if (!isNil "insurgent_mode_enable" && {insurgent_mode_enable}) then {
    private _disabledIndices = [3,4,5,6,12,14,15,16,17,18,19,20];
    { lbSetColor [2103, _x, [0.5,0.5,0.5,1]]; } forEach _disabledIndices;
};

//hint format["index: %1",_index2];