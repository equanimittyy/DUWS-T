
///////////////
///////////////   "ASZ_EI", "PEDAGNE Italian Army + SOF (Vegecam + Vegetata)", "ASZ_EI"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"ASZ_EI_rifleman_06A";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"ASZ_EI_operator_AT_A";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"ASZ_EI_riflemanGL_04A";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"ASZ_EI_commander_03A";				//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"ASZ_EI_commander_03A";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"ASZ_EI_mg_02A";					//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"ASZ_EI_marksman_01A";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"ASZ_EI_commander_08Acap";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"ASZ_Pilot_Hely_AM";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"ASZ_NH90_EI_reos";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"ASZ_CH47_EI";   					//random patrol
blufor_HELI_ATTACK_X =			"ASZ_A129_AT";						//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"ASZ_AV8B_MM_GBU";					//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"ASZ_VTML_EI_M2";					//random patrol
blufor_APC_PATROL1_X =			"ASZ_VCC1_EI_camo";					//random patrol
blufor_APC_PATROL2_X =			"ASZ_SuperAV_EI_battlefield";		//random patrol
blufor_TANK_PATROL1_X =			"ASZ_Ariete_camo_plus";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"ASZ_SOF_operator_landing";				//operator
blufor_SPECOPS_GL_X =			"ASZ_SOF_operator_05";					//operator
blufor_SPECOPS_LAT_X =			"ASZ_SOF_operator_AT";					//operator
blufor_SPECOPS_HAT_X =			"ASZ_EI_HAT_01Llanding";				//operator
blufor_SPECOPS_AA_X =			"ASZ_SOF_operator_AA";					//operator
blufor_SPECOPS_MG_X =			"ASZ_SOF_operatorMG";					//operator
blufor_SPECOPS_MEDIC_X =		"ASZ_SOF_operator_Medic";				//operator
blufor_SPECOPS_MARK_X =			"ASZ_SOF_operator_04";					//operator
blufor_SPECOPS_SNIPER_X =		"ASZ_Ghillie_SniperTOP";				//operator
blufor_SPECOPS_EXP_X =			"ASZ_SOF_sabotatore";					//operator
blufor_SPECOPS_ENG_X = 			"B_Patrol_Engineer_F";					//operator





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
	["ASZ_EI_rifleman_06A","Rifleman (2CP)",2],
	["ASZ_EI_riflemanGL_04A","Grenadier (3CP)",3],
	["ASZ_EI_mg_02A","Heavy Gunner (4CP)",4],
	["ASZ_EI_medic_A","Medic (4CP)",4],
	["ASZ_EI_operator_AT_A","AT Rifleman (3CP)",3],
	["ASZ_EI_operator_AA_A","AA Specialist (4CP)",4],
	["B_engineer_F","NATO Engineer (4CP)",4],
	["ASZ_EI_marksman_01A","Marksman (3CP)",3],
	["ASZ_Ghillie_SniperTOP","Sniper (4CP)",4]
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
	["ASZ_LR90_EIs","LR-90 Unarmed (10CP)",10],
	["ASZ_VM90spop","VM-90 SpecOps (15CP)",15],
	["ASZ_VTML_EI_M2","Lince VTML HMG (15CP)",15],
	["ASZ_VTML_EI_MK19","Lince VTML GMG (18CP)",18],
	["ASZ_VTML_EI_TOW","Lince VTML TOW (20CP)",20],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["ASZ_ACTL4x4_EI","Astra Transport Covered (8CP)",8],
	["ASZ_ACTL6x6_EI_repair","Astra Repair (50CP)",50],
	["ASZ_ACTL6x6_EI_logistic","Astra Ammo (50CP)",50],
	["ASZ_ACTL6x6_EI_fuel","Astra Fuel (50CP)",50],
	["ASZ_VCC1_EI_camo_plus","VCC1 HMG (25CP)",25],
	["ASZ_SuperAV_EI_battlefield","Super AV (30CP)",30],
	["ASZ_PUMA4x4_M2","PUMA HMG (32CP)",32],
	["ASZ_PUMA4x4_TOW","PUMA TOW (35CP)",35],
	["ASZ_PUMA6x6_hitrole","PUMA Hitrole (35CP)",35],
	["ASZ_Centauro_B1","Blindo Centauro (40CP)",40],
	["ASZ_Ariete_camo_plus","Ariete MBT (45CP)",40],
	["B_MBT_01_mlrs_F","Sandstorm MLRS (75CP)",75],
	["B_MBT_01_arty_F","M4 Scorcher (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["ASZ_NH90_EI_reos","NH-90 Armed Heli (22CP)",22],
	["ASZ_CH47_EI","CH-47 Transport (26CP)",26],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["ASZ_A129_AT","A-129 Attack Chopper (45CP)",45],
	["ASZ_AV8B_MM_GBU","AV-8B Harrier GBU (45CP)",45],
	["ASZ_EFA_AM_AA","Typhoon AA (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","Black Wasp 2 Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


