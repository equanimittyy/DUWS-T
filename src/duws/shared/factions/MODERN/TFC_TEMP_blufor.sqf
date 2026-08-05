///////////////
///////////////   "TFC", "Task Force Canada (Tmpr-OTW) + USMC", "TFC_TEMP"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TFC_C_Soldier_OTW_Rifleman_TW_F";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"TFC_C_Soldier_OTW_M72_TW_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"TFC_C_Soldier_OTW_Grenadier_TW_F";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"TFC_C_Soldier_OTW_IC_TW_F";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"TFC_C_Soldier_OTW_2IC_TW_F";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"TFC_C_Soldier_OTW_C9_TW_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"TFC_C_Soldier_OTW_Rifleman_Lite_TW_F";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TFC_C_Instructor_Army_Inf_TW";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TFC_C_Soldier_Aircrew_Pilot_Helo_TW_F";	//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"rhsusf_mkvsoc";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TFC_CH146430_unarmed_F";					//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"TFC_CH146408_unarmed_F";   				//random patrol
blufor_ATTACK_HELI_X =			"TFC_CH146451_dynamicLoadout_F";			//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"RHS_A10";									//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"TFC_vs_luvw_armed_F";						//random patrol
blufor_APC1_X =					"TFC_Wheeled_LAV6_ISC";						//random patrol
blufor_APC2_X =					"TFC_Wheeled_LAV6_ISC";						//random patrol
blufor_MBT_TANK1_X =			"TFC_Leopard2A_4_cannon_TW";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_Stinger_AA_pod_USMC_WD";
blufor_TURRET_AT =				"RHS_TOW_TriPod_USMC_WD";
blufor_TURRET_HMG =				"RHS_M2StaticMG_USMC_WD";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"TFC_C_Soldier_OTW_Rifleman_MT_F";				//operator
blufor_SPECOPS_GL_X =			"TFC_C_Soldier_OTW_Grenadier_MT_F";				//operator
blufor_SPECOPS_LAT_X =			"TFC_C_Soldier_OTW_M72_MT_F";					//operator
blufor_SPECOPS_HAT_X =			"TFC_C_Soldier_OTW_CarlG_MT_F";					//operator
blufor_SPECOPS_AA_X =			"TFC_C_Soldier_OTW_CarlG_MT_F";					//operator
blufor_SPECOPS_MG_X =			"TFC_C_Soldier_OTW_C9_MT_F";					//operator
blufor_SPECOPS_MEDIC_X =		"TFC_C_Soldier_OTW_Medic_MT_F";					//operator
blufor_SPECOPS_MARK_X =			"TFC_C_Soldier_OTW_Rifleman_Lite_MT_F";			//operator
blufor_SPECOPS_SNIPER_X =		"rhsusf_usmc_recon_marpat_wd_sniper_M107";		//operator
blufor_SPECOPS_EXP_X =			"TFC_C_Soldier_OTW_2IC_MT_F";					//operator
blufor_SPECOPS_ENG_X = 			"TFC_C_Soldier_OTW_Engineer_MT_F";				//operator





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
	["TFC_C_Soldier_OTW_Rifleman_TW_F","Rifleman (Temperate) (2CP)",2],
	["TFC_C_Soldier_OTW_Grenadier_TW_F","Grenadier (Temperate) (3CP)",3],
	["TFC_C_Soldier_OTW_C9_TW_F","Automatic Rifleman (Temperate) (3CP)",3],
	["TFC_C_Soldier_OTW_C6_TW_F","Heavy Gunner (Temperate) (4CP)",4],
	["TFC_C_Soldier_OTW_Medic_TW_F","Medic (Temperate) (4CP)",4],
	["TFC_C_Soldier_OTW_M72_TW_F","Rifleman AT (Temperate) (4CP)",4],
	["TFC_C_Soldier_OTW_CarlG_TW_F","AT Specialist (Temperate) (4CP)",4],
	["TFC_C_Soldier_OTW_Engineer_TW_F","Engineer (Temperate) (4CP)",4],
	["TFC_C_Soldier_OTW_Rifleman_Lite_TW_F","Marksman (Temperate) (3CP)",3],
	["rhsusf_socom_marsoc_sniper_m107","Sniper (Temperate) (4CP)",4],
	["TFC_C_soldier_OTW_Paratrooper_TW_F","Paratrooper (Temperate) (4CP)",4]
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
	["rhsusf_m1043_w_s","HMMWV Unarmed (5CP)",5],
	["rhsusf_m1151_m240_v3_usmc_wd","HMMWV HMG (15CP)",15],
	["rhsusf_m1151_mk19_v3_usmc_wd","HMMWV GMG (20CP)",20],
	["rhsusf_m1045_w_s","HMMWV TOW (25CP)",25],
	["rhsusf_m1240a1_m240_usmc_wd","M-1240 Oshkosh HMG (16CP)",16],
	["rhsusf_CGRCAT1A2_M2_usmc_wd","CGR MRAP CAT1A2 HMG (20CP)",20],
	["rhsusf_CGRCAT1A2_Mk19_usmc_wd","CGR MRAP CAT1A2 GMG (25CP)",25],
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
	["rhsusf_m1a1fep_wd","M1A1 FEP Tank (40CP)",40],
	["rhsusf_m1a2sep1wd_usarmy","M1A2 SEP (40CP)",40],
	["rhsusf_m1a2sep1tuskiiwd_usarmy","M1A2 TUSK 3 (50CP)",50],
	["rhsusf_M142_usarmy_WD","M-142 HIMARS (50CP)",50],
	["rhsusf_m109_usarmy","M-109A6 Arty (75CP)",75],
	["RHS_MELB_MH6M","MH-6M Littlebird (15CP)",15],
	["RHS_MELB_AH6M","AH-6M Armed (25CP)",25],
	["RHS_AH1Z","AH-1Z Viper (45CP)",45],
	["RHS_UH60M_d","UH-60M Blackhawk Unarmed (22CP)",22],
	["rhsusf_CH53E_USMC_GAU21_D","CH-53E Sea Stallion (26CP)",26],
	["RHS_A10","A-10 Warthog (45CP)",45],
	["rhsusf_f22","F-22 Raptor (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["TFC_vs_luvw_F","LUVW unarmed (5CP)",5],
	["TFC_vs_luvw_armed_F","LUVW armed (15CP)",15],
	["C_TFC_VS_LSVW_transport_uncovered_F","LSWV Transport Uncovered (8CP)",8],
	["C_TFC_VS_LSVW_transport_covered_F","LSWV Transport Covered (8CP)",8],
	["TFC_Wheeled_LAV6_ISC","LAV 6.0 IFV (25CP)",25],
	["TFC_Leopard2A_4_cannon_TW","Leopard2A4 (50CP)",50],
	["TFC_CH146402_unarmed_F","CH146402 EGRESS Griffon (15CP)",15],
	["TFC_CH146444_dynamicLoadout_F","CH146444 CAS Griffon (25CP)",25],
	["TFC_AIR_CC130J_Cargo","CC130J Hercules Cargo (50CP)",50],
	["TFC_AIR_CC130J","CC130J Hercules Troop Transport (50CP)",50]
];

