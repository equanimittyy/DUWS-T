
///////////////
///////////////   "RHS_faction_USAIRBORNE_WD", "RHS USA Airborne (OCP Wood) + SOCOM", "RHS_faction_USAIRBORNE_OCP_WD"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"rhsusf_army_ocp_arb_rifleman";				//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"rhsusf_army_ocp_arb_maaws";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"rhsusf_army_ocp_arb_grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"rhsusf_army_ocp_arb_teamleader";			//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"rhsusf_army_ocp_arb_squadleader";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"rhsusf_army_ocp_arb_machinegunner";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"rhsusf_army_ocp_arb_marksman";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"rhsusf_socom_swcc_officer";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"rhsusf_army_ocp_helipilot";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"RHS_UH60M";						//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"RHS_CH_47F";  						//random patrol
blufor_ATTACK_HELI_X =			"RHS_AH64D_wd";						//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"RHS_A10";							//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"rhsusf_m1043_w_m2";				//random patrol
blufor_APC1_X =					"rhsusf_stryker_m1126_m2_wd";		//random patrol
blufor_APC2_X =					"RHS_M2A3_BUSKIII_wd";				//random patrol
blufor_MBT_TANK1_X =			"rhsusf_m1a2sep1wd_usarmy";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_Stinger_AA_pod_D";
blufor_TURRET_AT =				"RHS_TOW_TriPod_D";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"rhsusf_socom_marsoc_cso";				//operator
blufor_SPECOPS_GL_X =			"rhsusf_socom_marsoc_cso_grenadier";	//operator
blufor_SPECOPS_LAT_X =			"rhsusf_army_ocp_arb_riflemanat";		//operator 
blufor_SPECOPS_HAT_X =			"rhsusf_army_ocp_arb_maaws";			//operator
blufor_SPECOPS_AA_X =			"rhsusf_army_ocp_aa";					//operator
blufor_SPECOPS_MG_X =			"rhsusf_army_ocp_arb_machinegunner";	//operator
blufor_SPECOPS_MEDIC_X =		"rhsusf_socom_marsoc_sarc";		 		//operator
blufor_SPECOPS_MARK_X =			"rhsusf_socom_marsoc_marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"rhsusf_socom_marsoc_sniper_m107";		//operator
blufor_SPECOPS_EXP_X =			"rhsusf_socom_marsoc_cso_eod";			//operator
blufor_SPECOPS_ENG_X =			"rhsusf_socom_marsoc_cso_mechanic"; 	//operator





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
	["rhsusf_army_ocp_arb_rifleman","Rifleman (USA) (2CP)",2],
	["rhsusf_army_ocp_arb_grenadier","Grenadier (USA) (3CP)",3],
	["rhsusf_army_ocp_arb_autorifleman","Automatic Rifleman (USA) (3CP)",3],
	["rhsusf_army_ocp_arb_machinegunner","Heavy Gunner (USA) (4CP)",4],
	["rhsusf_army_ocp_arb_medic","Medic (USA) (4CP)",4],
	["rhsusf_army_ocp_arb_riflemanat","AT Rifleman (USA) (3CP)",3],
	["rhsusf_army_ocp_arb_maaws","AT Specialist (USA) (4CP)",4],
	["rhsusf_army_ocp_aa","AA Specialist (USA) (4CP)",4],
	["rhsusf_army_ocp_arb_engineer","Engineer (USA) (4CP)",4],
	["rhsusf_army_ocp_arb_marksman","Marksman (USA) (3CP)",3],
	["rhsusf_army_ocp_arb_sniper_m107","Sniper (USA) (4CP)",4]
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
	["rhsusf_m1043_w","HMMWV Unarmed (5CP)",5],
	["rhsusf_m1043_w_m2","HMMWV HMG (15CP)",15],
	["rhsusf_m1043_w_mk19","HMMWV GMG (20CP)",20],
	["rhsusf_m1045_w","HMMWV TOW (25CP)",25],
	["rhsusf_m1240a1_m2_usarmy_wd","M-1240 Oshkosh HMG (16CP)",16],
	["rhsusf_M1220_M2_usarmy_wd","M-1220 Caiman HMG (20CP)",20],
	["rhsusf_M1237_MK19_usarmy_wd","RG-31 GMG (25CP)",25],
	["rhsusf_M1083A1P2_WD_fmtv_usarmy","M-1083 Transport Covered (8CP)",8],
	["rhsusf_M977A4_REPAIR_usarmy_wd","M-977 Repair (50CP)",50],
	["rhsusf_M977A4_AMMO_usarmy_wd","M-977 Ammo (50CP)",50],
	["rhsusf_M978A4_usarmy_wd","M-978 Fuel (50CP)",50],
	["rhsusf_stryker_m1126_m2_wd","M1126 Stryker HMG crows (25CP)",25],
	["rhsusf_m113_usarmy","M-113A3 HMG (28CP)",28],
	["rhsusf_m113_usarmy_MK19","M-113A3 GMG (30CP)",30],
	["RHS_M2A2_BUSKI_wd","M2A2 Bradley BUSK1 (35CP)",35],
	["RHS_M2A3_BUSKIII_wd","M2A3 Bradley BUSK3 (35CP)",35],
	["RHS_M6_wd","M6A2 Bradley (35CP)",35],
	["rhsusf_m1a1aimwd_usarmy","M1A1 Tank (40CP)",40],
	["rhsusf_m1a2sep1wd_usarmy","M1A2 SEP (40CP)",40],
	["rhsusf_m1a2sep1tuskiiwd_usarmy","M1A2 TUSK 3 (50CP)",50],
	["rhsusf_M142_usarmy_WD","M-142 HIMARS (50CP)",50],
	["rhsusf_m109_usarmy","M-109A6 Arty (75CP)",75],
	["RHS_MELB_MH6M","MH-6M Littlebird (15CP)",15],
	["RHS_MELB_AH6M","AH-6M Armed (25CP)",25],
	["RHS_AH64D_wd","AH-64D Apache (45CP)",45],
	["RHS_UH60M","UH-60M Blackhawk Unarmed (22CP)",22],
	["RHS_CH_47F","CH-47F Chinook (26CP)",26],
	["RHS_A10","A-10 Warthog (45CP)",45],
	["rhsusf_f22","F-22 Raptor (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];

