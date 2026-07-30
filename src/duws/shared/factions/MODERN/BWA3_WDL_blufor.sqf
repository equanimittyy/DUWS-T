
///////////////
///////////////   "BWA3", "BWA3 German Bundeswehr + KSK (Wood)", "BWA3_WDL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"BWA3_Rifleman_G27_Fleck";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"BWA3_RiflemanAT_RGW90_Fleck";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"BWA3_Grenadier_G27_Fleck";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"BWA3_TL_Fleck";					//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"BWA3_SL_Fleck";					//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"BWA3_MachineGunner_MG5_Fleck";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"BWA3_Marksman_Fleck";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"BWA3_Officer_Fleck";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"BWA3_Helipilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"NH_90_Fleck";							//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"AW159_BW_Fleck";   					//random patrol
blufor_HELI_ATTACK_X =			"BWA3_Tiger_RMK_Heavy";					//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_dynamicLoadout_F";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"BWA3_Dingo2_FLW200_M2_Fleck";			//random patrol
blufor_APC_PATROL1_X =			"KGB_B_MRAP_03_hmg_F";						//random patrol
blufor_APC_PATROL2_X =			"BWA3_Puma_Fleck";				//random patrol
blufor_TANK_PATROL1_X =			"BWA3_Leopard2_Fleck";					//random patrol


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

blufor_SPECOPS_X =				"BWA3_recon_Fleck";						//operator
blufor_SPECOPS_GL_X =			"BWA3_Grenadier_G27_Fleck";				//operator
blufor_SPECOPS_LAT_X =			"BWA3_recon_LAT_Fleck";					//operator
blufor_SPECOPS_HAT_X =			"BWA3_RiflemanAT_PzF3_Fleck";			//operator
blufor_SPECOPS_AA_X =			"BWA3_RiflemanAA_Fliegerfaust_Fleck";	//operator
blufor_SPECOPS_MG_X =			"BWA3_MachineGunner_MG5_Fleck";			//operator
blufor_SPECOPS_MEDIC_X =		"BWA3_recon_Medic_Fleck";				//operator
blufor_SPECOPS_MARK_X =			"BWA3_recon_Marksman_Fleck";			//operator
blufor_SPECOPS_SNIPER_X =		"BWA3_Sniper_G29_Fleck";				//operator
blufor_SPECOPS_EXP_X =			"BWA3_recon_Pioneer_Fleck";				//operator
blufor_SPECOPS_ENG_X = 			"BWA3_recon_Pioneer_Fleck";				//operator





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
	["BWA3_Rifleman_G27_Fleck","Rifleman (Wood) (2CP)",2],
	["BWA3_Grenadier_G27_Fleck","Grenadier (Wood) (3CP)",3],
	["BWA3_MachineGunner_MG3_Fleck","Automatic Rifleman (Wood) (3CP)",3],
	["BWA3_MachineGunner_MG5_Fleck","Heavy Gunner (Wood) (4CP)",4],
	["BWA3_Medic_Fleck","Medic (Wood) (4CP)",4],
	["BWA3_RiflemanAT_RGW90_Fleck","AT Specialist (Wood) (4CP)",4],
	["BWA3_RiflemanAA_Fliegerfaust_Fleck","AA Specialist (Wood) (4CP)",4],
	["BWA3_Engineer_Fleck","Engineer (Wood) (4CP)",4],
	["BWA3_Marksman_Fleck","Marksman (Wood) (3CP)",3],
	["BWA3_Sniper_G29_Fleck","Sniper (Wood) (4CP)",4]
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
	["B_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5],
	["B_LSV_01_armed_F","Prowler HMG (15CP)",15],
	["B_LSV_01_AT_F","Prowler AT (20CP)",20],
	["BWA3_Eagle_Fleck","Eagle IV Unarmed (8CP)",8],
	["BWA3_Eagle_FLW100_Fleck","Eagle IV HMG (15CP)",15],
	["BWA3_Dingo2_FLW200_M2_CG13_Fleck","Dingo 2-GE M2 (18CP)",18],
	["BWA3_Dingo2_FLW100_MG3_CG13_Fleck","Dingo 2-GE MG3 (18CP)",18],
	["BWA3_Dingo2_FLW200_GMW_CG13_Fleck","Dingo 2-GE GMG (20CP)",20],
	["KGB_B_MRAP_03_F","Fennek Unarmed (8CP)",8],
	["KGB_B_MRAP_03_hmg_F","Fennek HMG (18CP)",18],
	["KGB_B_MRAP_03_gmg_F","Fennek GMG (20CP)",20],
	["BW_LKW_Transport_offen_fleck","LKW Transport Uncovered (8CP)",8],
	["BW_LKW_Transport_Fleck","LKW Transport Covered (8CP)",8],
	["BW_LKW_Reparatur_Fleck","LKW Repair Truck(50CP)",50],
	["BW_LKW_Munition_Fleck","LKW Ammo Truck (50CP)",50],
	["BW_LKW_Treibstoff_Fleck","LKW Fuel Truck (50CP)",50],
	["BWA3_Puma_Fleck","Puma IFV (35CP)",35],
	["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (35CP)",35],
	["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["BWA3_Leopard2_Fleck","Leopard 2 MBT (50CP)",50],
	["B_MBT_01_arty_F","M4 Scorcher (75CP)",75],
	["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75],
	["MH6_Littlebird_BW_Fleck","MH-6 Littlebird (15CP)",15],
	["AH6_Littlebird_BW_Fleck","AH-6 Littlebird Armed (25CP)",25],
	["AW159_BW_Fleck_Unbewaffnet","AW-159 Wildcat Trans (22CP)",22],
	["AW159_BW_Fleck","AW-159 Wildcat Gunship (26CP)",26],
	["NH_90_Fleck","NH-90 Trans Heli (30CP)",30],
	["BWA3_Tiger_RMK_Heavy","UH Tiger RMK Heavy (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout (45CP)",45],
	["B_Plane_Fighter_01_F","FA-181 Black Wasp (50CP)",50],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


