
///////////////   "CUP_B_US_Army", "CUP US Army UCP Wood", "CUP_B_US_Army_W"


blufor_SOLDIER_X =				"CUP_B_US_Soldier";					//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"CUP_B_US_Soldier_LAT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"CUP_B_US_Soldier_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"CUP_B_US_Soldier_TL";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"CUP_B_US_Soldier_SL";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"CUP_B_US_Soldier_AR";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"CUP_B_US_Soldier_Marksman";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_US_Officer";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_US_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_B_RHIB_USMC";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_UH60M_US";					//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_B_MH47E_USA";  					//random patrol
blufor_ATTACK_HELI_X =			"CUP_B_AH64D_DL_USA";				//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"CUP_B_A10_DYN_USA";				//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"CUP_B_M1151_M2_WDL_USA";			//random patrol
blufor_APC1_X =					"CUP_B_M1126_ICV_M2_Woodland";		//random patrol
blufor_APC2_X =					"CUP_B_M2A3Bradley_USA_W";			//random patrol
blufor_MBT_TANK1_X =			"CUP_B_M1A1_Woodland_US_Army";		//random patrol



blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW_TriPod_US";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";



blufor_SPECOPS_X =				"CUP_B_US_SpecOps_JTAC";			//operator
blufor_SPECOPS_GL_X =			"CUP_B_US_SpecOps_Assault";			//operator
blufor_SPECOPS_LAT_X =			"CUP_B_US_Soldier_LAT";		 		//operator 
blufor_SPECOPS_HAT_X =			"CUP_B_US_Soldier_AT";				//operator
blufor_SPECOPS_AA_X =			"CUP_B_US_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_US_SpecOps_AR";				//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_US_SpecOps_Medic";		 	//operator
blufor_SPECOPS_MARK_X	=		"CUP_B_US_SpecOps_M";				//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_US_Soldier_Sniper";			//operator
blufor_SPECOPS_EXP_X =			"CUP_B_US_SpecOps";					//operator
blufor_SPECOPS_ENG_X =			"CUP_B_US_Soldier_Engineer"; 		//operator





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
	["CUP_B_US_Soldier","Rifleman (USA) (2CP)",2],
	["CUP_B_US_Soldier_GL","Grenadier (USA) (3CP)",3],
	["CUP_B_US_Soldier_AR","Automatic Rifleman (USA) (3CP)",3],
	["CUP_B_US_Soldier_MG","Heavy Gunner (USA) (4CP)",4],
	["CUP_B_US_Medic","Medic (USA) (4CP)",4],
	["CUP_B_US_Soldier_LAT","AT Rifleman (USA) (3CP)",3],
	["CUP_B_US_Soldier_HAT","AT Specialist (USA) (4CP)",4],
	["CUP_B_US_Soldier_AA","AA Specialist (USA) (4CP)",4],
	["CUP_B_US_Soldier_Engineer_EOD","Engineer (USA) (4CP)",4],
	["CUP_B_US_Soldier_Engineer_EOD","Repair (USA) (4CP)",4],
	["CUP_B_US_Engineer","Explosive Specialist (USA) (4CP)",4],
	["CUP_B_US_Soldier_Spotter","Spotter (USA) (3CP)",3],
	["CUP_B_US_Soldier_Marksman","Marksman (USA) (3CP)",3],
	["CUP_B_US_Soldier_Sniper","Sniper (USA) (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["CUP_B_M1151_WDL_USA","HMMWV Unarmed (5CP)",5],
	["CUP_B_M1152_WDL_USA","HMMWV Transport (8CP)",8],
	["CUP_B_M1151_M2_WDL_USA","HMMWV HMG (18CP)",18],
	["CUP_B_M1167_WDL_USA","HMMWV TOW (25CP)",25],
	["CUP_B_RG31E_M2_OD_USA","RG-31 HMG (10CP)",10],
	["CUP_B_RG31_Mk19_OD_USA","RG-31 GMG (18CP)",18],
	["CUP_B_RG31_M2_OD_GC_USA","RG-31 Nayala (25CP)",25],
	["CUP_B_MTVR_USMC","MTVR Transport Covered (8CP)",8],
	["CUP_B_MTVR_Repair_USMC","MTVR Repair (50CP)",50],
	["CUP_B_MTVR_Ammo_USMC","MTVR Ammo (50CP)",50],
	["CUP_B_MTVR_Refuel_USMC","MTVR Fuel (50CP)",50],
	["CUP_B_M1126_ICV_M2_Woodland","M1126 HMG crows (25CP)",25],
	["CUP_B_M1126_ICV_MK19_Woodland","M1126 GMG crows (28CP)",28],
	["CUP_B_M1128_MGS_Woodland","M1128 MGS cannon (30CP)",30],
	["CUP_B_M1130_CV_M2_Woodland","M1130 CV HMG (35CP)",35],
	["CUP_B_M1135_ATGMV_Woodland","M1135 ATGMV (35CP)",35],
	["CUP_B_M2A3Bradley_USA_W","Bradley ERA (35CP)",35],
	["CUP_B_M7Bradley_USA_W","Bradley M7 (35CP)",35],
	["CUP_B_M1A1_Woodland_US_Army","M1A1 Tank  (40CP)",40],
	["CUP_B_M1A2_TUSK_MG_US_Army","M1A2 TUSK (40CP)",40],
	["CUP_B_Challenger2_2CW_BAF","NATO Challenger Tank (50CP)",50],
	["CUP_B_M1129_MC_MK19_Woodland","M1129 Mortar GMG (50CP)",50],
	["CUP_B_M270_DPICM_USA","M270 MLRS DPICM (75CP)",75],
	["CUP_B_MH6J_USA","MH-6J Littlebird (15CP)",15],
	["CUP_B_AH6M_USA","AH-6M Armed (25CP)",25],
	["CUP_B_AH64_DL_USA","AH-64 Apache (40CP)",40],
	["CUP_B_AH64D_DL_USA","AH-64D Apache (45CP)",45],
	["CUP_B_UH60M_US","UH-60M Blackhawk Unarmed (22CP)",22],
	["CUP_B_UH60M_FFV_US","UH-60M Blackhawk Armed (28CP)",28],
	["CUP_B_MH47E_USA","MH-47E Chinook (26CP)",26],
	["CUP_B_A10_DYN_USA","A-10 Warthog (45CP)",45],
	["CUP_B_AV8B_DYN_USMC","AV-8B Harrier (50CP)",50],
	["CUP_B_F35B_USMC","F-35B Lightning (55CP)",55],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_B_USMC_DYN_MQ9","UAV MQ-9 Reaper (USMC)(15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


