// Locality: client -- passed as an addAction function value in
// client/misc/fnc_addHQBuildingActions.sqf, so it runs on whoever opens the menu.
// case #

_handle = createDialog "ressourceheader";
waitUntil {dialog};
ctrlSetText [1000, format["%1",commandpointsblu1]];
ctrlSetText [1001, format["%1",zoneundercontrolblu]];
ctrlSetText [1002, format["%1",WARCOM_blufor_ap]];

// REQUEST UNITS - 14 MAX
_index = lbAdd [2100, localize "STR_DUWS_T_zo6ih0pt"];      // 0
_index = lbAdd [2100, ""];                              	// 1

{
	_displayName = [configFile >> "CfgVehicles" >> (_x select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2100, _displayName  + " (" + str (_x select 2) + "cp)"];
} forEach (["UNIT"] call fnc_faction_rqst_list);
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

{
	_displayName = [configFile >> "CfgVehicles" >> (_x select 0)] call BIS_fnc_displayName;
	_index = lbAdd [2102, _displayName  + " (" + str (_x select 2) + "cp)"];
} forEach (["VEHICLE"] call fnc_faction_rqst_list);

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

// Last row, and the only conditional one: a FOB is not offered until a zone has been taken, which
// is what the comm-menu item this replaces waited on. Appended rather than slotted in beside the
// other logistics rows because every index below is a literal in the colour block and a key in
// fnc_request_support's table -- inserting anywhere else renumbers both.
// Absent rather than greyed: an index that was never added cannot be selected, so nothing
// downstream needs a second condition to refuse it.
if (zoneundercontrolblu >= 1) then {
    index_support_fob = lbAdd [2103, localize "STR_DUWS_T_fob_request_row"];
};

// Escalation surcharge, appended rather than substituted. Each label carries its base cost
// inside its own stringtable text ("Supply Drop (5CP) Radio"), so the written number stays as
// the base and the scaled figure follows it. Stripping the numbers out and re-formatting from
// a placeholder is tidier and rejected: a %1 added to English but not to the other four
// languages leaves them printing the stale baked figure, which is a wrong number rather than
// an untranslated one.
// Rows are conditional on VERSION_X, so entries are looked up by name and skipped when absent.
if ((missionNamespace getVariable ["escalation_multiplier", 1]) > 1) then {
    private _baseCosts = [
        ["index_support_supply", 5],     ["index_support_armory", 10],
        ["index_support_veh_supply", 5], ["index_support_siva_supply", 10],
        ["index_support_sawp", 10],      ["index_support_halo", 15],
        ["index_support_uavrecon", 10],  ["index_support_helotaxi", 5],
        ["index_support_helolift", 10],  ["index_support_boattaxi", 2],
        ["index_support_recycle", 5],    ["index_support_repair", 5],
        ["index_support_arty", 20],      ["index_support_mortar", 10],
        ["index_support_jdam", 10],      ["index_support_laser", 10],
        ["index_support_cluster", 25],   ["index_support_napalm", 20],
        ["index_support_hcAttChop", 20], ["index_support_hcCAS", 25],
        ["index_support_paradrop", 20],  ["index_support_fob", 10]
    ];
    // Free under insurgent mode, and its label already says so.
    if (isNil "insurgent_mode_enable" || {!insurgent_mode_enable}) then {
        _baseCosts pushBack ["index_mobile_HQ", 10];
    };
    {
        _x params ["_name", "_base"];
        if (!isNil _name) then {
            private _row = missionNamespace getVariable [_name, -1];
            if (_row >= 0) then {
                lbSetText [2103, _row, format [localize "STR_DUWS_T_escalation_row",
                    lbText [2103, _row], [_base] call fnc_escalation_cost]];
            };
        };
    } forEach _baseCosts;
};

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
// By name, not by literal: this row only exists once a zone has been taken.
if (support_FOB_available && !isNil "index_support_fob") then {
    lbSetColor [2103, index_support_fob, [0, 1, 0, 1]];
};
// 叛军模式下禁用部分支援（置灰显示）
if (!isNil "insurgent_mode_enable" && {insurgent_mode_enable}) then {
    private _disabledIndices = [3,4,5,6,12,14,15,16,17,18,19,20];
    { lbSetColor [2103, _x, [0.5,0.5,0.5,1]]; } forEach _disabledIndices;
};
