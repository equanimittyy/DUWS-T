
///////////////   "CUP_B_US_Army", "CUP US Army (OCP Desert)","CUP_B_USArmy_OCP_Desert"


blufor_SOLDIER_X =				"CUP_B_US_Soldier_ACOG_OCP";					//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"CUP_B_US_Soldier_LAT_OCP";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"CUP_B_US_Soldier_GL_OCP";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"CUP_B_US_Soldier_TL_OCP";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"CUP_B_US_Soldier_SL_OCP";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"CUP_B_US_Soldier_AR_OCP";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"CUP_B_US_Soldier_Marksman_OCP";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_US_Officer_OCP";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_US_Soldier_Crew_OCP";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CFP_B_USRANGERS_Assault_Boat_WDL_01";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"CUP_B_US_Soldier_Crew_OCP";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_UH60M_US";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_B_UH60M_Unarmed_US";   //random patrol
blufor_ATTACK_HELI_X =			"CUP_B_AH64_DL_USA";			//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"CUP_B_A10_DYN_USA";				//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"CUP_B_RG31_M2_USA";				//random patrol
blufor_APC1_X =					"CUP_B_M1126_ICV_MK19_Desert";	//random patrol
blufor_APC2_X =					"CUP_B_M2A3Bradley_USA_D";		//random patrol
blufor_MBT_TANK1_X =			"CUP_B_M1A2C_TUSK_II_Desert_US_Army";				//random patrol



blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW2_TriPod_US";
blufor_TURRET_HMG =				"CUP_B_M2StaticMG_US";
blufor_TURRET_GMG =				"CUP_B_MK19_TriPod_US";



blufor_SPECOPS_X =				"CUP_B_US_SpecOps";					//operator
blufor_SPECOPS_GL_X =			"CUP_B_US_SpecOps_Assault";				//operator
blufor_SPECOPS_LAT_X =			"CUP_B_US_Soldier_AT_OCP";				//operator
blufor_SPECOPS_HAT_X =			"CUP_B_US_Soldier_HAT_OCP";		//operator
blufor_SPECOPS_AA_X =			"CUP_B_US_Soldier_AA_OCP";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_US_SpecOps_MG";		//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_US_SpecOps_Medic";				//operator
blufor_SPECOPS_MARK_X =			"CUP_B_US_SpecOps_M";					//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_US_Sniper_OCP";					//operator
blufor_SPECOPS_EXP_X =			"CUP_B_US_Soldier_Engineer_EOD_OCP";				//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_US_Soldier_Engineer_OCP";			//operator





// REQUEST Units/Vehicles
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.

// REQUEST MENU defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


// dialog\fnc_request_unit
//   _index = lbCurSel 2100;
// dialog\fnc_request_unit_fob
//   _index = lbCurSel 2120;


blufor_RQST_UNITS = [
	["CUP_B_US_Soldier_ACOG_OCP","Rifleman (2CP)",2],
	["CUP_B_US_Soldier_GL_OCP","Grenadier (3CP)",3],
	["CUP_B_US_Soldier_AR_OCP","Automatic Rifleman (3CP)",3],
	["CUP_B_US_Soldier_MG_OCP","Heavy Gunner (4CP)",4],
	["CUP_B_US_Medic_OCP","Medic (4CP)",4],
	["CUP_B_US_Soldier_LAT_OCP","AT Rifleman (3CP)",3],
	["CUP_B_US_Soldier_AT_OCP","AT Specialist (4CP)",4],
	["CUP_B_US_Soldier_AA_OCP","AA Specialist (4CP)",4],
	["CUP_B_US_Soldier_Engineer_OCP","Engineer (4CP)",4],
	["CUP_B_US_Soldier_Marksman_OCP","Marksman (3CP)",3],
	["CUP_B_US_Sniper_M107_OCP","Sniper (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["CUP_B_M1030_USA","Motorcycle (1CP)",1],
	["CUP_B_M1152_USA","Humvee Uncovered (2CP)",2],
	["CUP_B_nM1037sc_USA_DES","Humvee Shelter (6CP)",6],
	["CUP_B_M1151_USA","Humvee Unarmed (5CP)",5],
	["CUP_B_M1151_M2_USA","Humvee HMG (18CP)",18],
	["CUP_B_M1151_MK19_USA","Humvee GMG (25CP)",25],
	["CUP_B_nM1038_USA_DES","Humvee Unarmed Cargo (5CP)",5],
	["CUP_B_nM1025_SOV_M2_USA_DES","Humvee Recon HMG (15CP)",15],
	["CUP_B_nM1036_TOW_USA_DES","Humvee AT (20CP)",20],
	["CUP_B_nM1038_4s_USA_DES","Humvee Transport Cargo (8CP)",8],
	["CUP_B_MTVR_USA","MTVR Transport Covered (8CP)",8],
	["CUP_B_MTVR_Repair_USA","MTVR Repair (50CP)",50],
	["CUP_B_MTVR_Ammo_USA","MTVR Ammo (50CP)",50],
	["CUP_B_MTVR_Refuel_USA","MTVR Fuel (50CP)",50],
	["CUP_B_M1128_MGS_Desert","M1128 MGS APC (35CP)",35],
	["CUP_B_M1126_ICV_MK19_Desert","M1126 MK19 APC (30CP)",30],
	["CUP_B_M2Bradley_USA_D","M2 Bradley (35CP)",35],
	["CUP_B_M2A3Bradley_USA_D","M2A3 Bradley (35CP)",35],
	["CUP_B_M1130_CV_M2_Desert","M1130 M2 APC (28CP)",28],
	["CUP_B_M1126_ICV_M2_Desert","M1126 M2 APC (25CP)",25],
	["CUP_B_M1135_ATGMV_Desert","M1135 ATGMV APC (35CP)",35],
	["CUP_B_M1A1SA_Desert_US_Army","M1A1 Tank (40CP)",40],
	["CUP_B_M1A1SA_Desert_TUSK_US_Army","M1A1 Tusk Tank (40CP)",40],
	["CUP_B_M1A2SEP_TUSK_II_Desert_US_Army","M1A2 SEPV1 Tusk2 Tank (50CP)",50],
	["CUP_B_M1A2C_TUSK_Desert_US_Army","M1A2 SEPV3 Tusk Tank (75CP)",75],
	["CUP_B_M1A2C_TUSK_II_Desert_US_Army","M1A2 SEPV3 Tusk2 Tank (75CP)",75],
	["CUP_B_AH6J_USA","AH6J Armed Heli (25CP)",25],
	["CUP_B_MH6J_USA","MH6J Little Bird Heli (15CP)",15],
	["CUP_B_AH64_DL_USA","AH64 Attack Heli (45CP)",45],
	["CUP_B_MH47E_US","MH47 Heli (40CP)",40],
	["CUP_B_UH60M_US","UH60 Blackhawk Heli (22CP)",22],
	["CUP_B_CH47F_VIV_USA","CH47 Sidemounted Heli (26CP)",26],
	["CUP_B_CH47F_USA","CH47 Fullmounted Heli (26CP)",26],
	["CUP_B_CESSNA_T41_ARMED_USA","T41 Armed Plane (45CP)",45],
	["CUP_B_AC47_SPOOKY_USA","AC47 Armed Plane (50CP)",50],
	["CUP_B_A10_DYN_USA","A10 Thunderbolt Plane (60CP)",60]
];


