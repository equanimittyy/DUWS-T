
///////////////
///////////////   "CUP_B_GER", "German Bundeswehr + KSK Desert", "CUP_B_GER_BW"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_GER_BW_Soldier";					//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"CUP_B_GER_BW_Soldier_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"CUP_B_GER_BW_Soldier_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"CUP_B_GER_BW_Soldier_TL";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"CUP_B_GER_BW_Soldier_TL";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"CUP_B_GER_BW_Soldier_MG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"CUP_B_GER_BW_Soldier_Marksman";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_GER_Soldier_TL";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_GER_HPilot";						//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_UH1D_gunship_GER_KSK_Des";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_B_CH53E_GER";   					//random patrol
blufor_ATTACK_HELI_X =			"CUP_B_UH1D_gunship_GER_KSK_Des";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"CUP_B_A10_DYN_USA";					//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"CUP_B_Dingo_GER_Des";					//random patrol
blufor_APC1_X =					"CUP_I_FENNEK_HMG_ION";					//random patrol        
blufor_APC2_X =					"CUP_B_Boxer_HMG_GER_DES";				//random patrol     
blufor_MBT_TANK1_X =			"CUP_B_Leopard2A6DST_GER";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW_TriPod_US";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_B_GER_Soldier";				//operator
blufor_SPECOPS_GL_X =			"CUP_B_GER_Operator_GL";			//operator
blufor_SPECOPS_LAT_X =			"CUP_B_GER_Soldier_AT";				//operator
blufor_SPECOPS_HAT_X =			"CUP_B_GER_Soldier_AT";				//operator
blufor_SPECOPS_AA_X =			"CUP_B_GER_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_GER_Soldier_MG3";			//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_GER_Operator_Medic";			//operator
blufor_SPECOPS_MARK_X =			"CUP_B_GER_BW_Soldier_Marksman";	//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_GER_Soldier_Sniper";			//operator
blufor_SPECOPS_EXP_X =			"CUP_B_GER_Operator_EXP";			//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_GER_Soldier_Engineer";		//operator





/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.
//
/////////////////////////////////////////////////////////////////

// REQUEST MENU defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


///////////////////////////////
// dialog\fnc_request_unit
//   _index = lbCurSel 2100;
// dialog\fnc_request_unit_fob
//   _index = lbCurSel 2120;
///////////////////////////////


blufor_RQST_UNITS = [
	["CUP_B_GER_BW_Soldier","Rifleman (Desert) (2CP)",2],
	["CUP_B_GER_BW_Soldier_GL","Grenadier (Desert) (3CP)",3],
	["CUP_B_GER_BW_Soldier_MG","Automatic Rifleman (Desert) (3CP)",3],
	["CUP_B_GER_BW_Soldier_MG3","Heavy Gunner (Desert) (4CP)",4],
	["CUP_B_GER_BW_Medic","Medic (Desert) (4CP)",4],
	["CUP_B_GER_BW_Soldier_AT","AT Specialist (Desert) (4CP)",4],
	["CUP_B_GER_BW_Soldier_AA","AA Specialist (Desert) (4CP)",4],
	["CUP_B_GER_BW_Soldier_Engineer","Engineer (Desert) (4CP)",4],
	["CUP_B_GER_BW_Soldier_Marksman","Marksman (Desert) (3CP)",3],
	["CUP_B_GER_BW_Soldier_Sniper","Sniper (Desert) (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["B_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["CUP_B_Dingo_GER_Des","Dingo HMG (18CP)",18],
	["CUP_B_Dingo_GL_GER_Des","Dingo GMG (25CP)",25],
	["CUP_B_FENNEK_GER_Des","Fennek Unarmed (8CP)",8],
	["CUP_I_FENNEK_HMG_ION","Fennek HMG (15CP)",15],
	["B_LSV_01_AT_F","Prowler AT (20CP)",20],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (35CP)",35],
	["CUP_B_Boxer_HMG_GER_DES","GTK Boxer HMG (35CP)",35],
	["CUP_B_Boxer_GMG_GER_DES","GTK Boxer GMG (35CP)",35],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25],
	["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["CUP_B_M1A2_TUSK_MG_DES_US_Army","M1A2 TUSK (40CP)",40],
	["CUP_B_Leopard2A6DST_GER","Leopard 2A6 Desert (50CP)",50],
	["B_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75],
	["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_B_UH1D_slick_GER_KSK_Des","UH-1D Heli Slick (22CP)",22],
	["CUP_B_UH1D_gunship_GER_KSK_Des","UH-1D Gunship (26CP)",26],
	["CUP_B_AH1_DL_BAF","AH-1H Cobra (45CP)",45],
	["CUP_B_CH53E_GER","CH-53 Super Stallion (30CP)",30],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["CUP_B_A10_DYN_USA","A-10 Warthog (45CP)",45],
	["CUP_B_AV8B_DYN_USMC","AV-8B Harrier (50CP)",50],
	["CUP_B_F35B_USMC","F-35B Lightning (55CP)",55],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


