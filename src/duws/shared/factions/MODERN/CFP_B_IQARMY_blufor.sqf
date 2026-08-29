
///////////////   "CFP_B_IQARMY", "CFP Iraqi Army (modern) + USA SpecOps", "CFP_B_IQARMY"


blufor_SOLDIER_X =				"cfp_b_iqarmy_rifleman";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"cfp_b_iqarmy_at";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"cfp_b_iqarmy_grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"cfp_b_iqarmy_officer";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"cfp_b_iqarmy_officer";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"cfp_b_iqarmy_machinegunner";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"cfp_b_iqarmy_sniper";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"cfp_b_iqarmy_sf_team_leader";		//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"cfp_b_iqarmy_helicopter_pilot_01";	//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_I_RHIB_RACS";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"cfp_b_iqarmy_MI24V";				//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CFP_O_IQARMY_Mi_8MT_01";   		//random patrol
blufor_ATTACK_HELI_X =			"cfp_b_iqarmy_MI24V";				//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"cfp_b_iqarmy_SU25";				//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"cfp_b_iqarmy_mrap_rg31";			//random patrol
blufor_APC1_X =					"cfp_b_iqarmy_BTR60";				//random patrol
blufor_APC2_X =					"cfp_b_iqarmy_BMP2";				//random patrol
blufor_MBT_TANK1_X =			"cfp_b_iqarmy_T72";					//random patrol



blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW_TriPod_US";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";



blufor_SPECOPS_X =				"cfp_b_iqarmy_sf";									//operator
blufor_SPECOPS_GL_X =			"cfp_b_iqarmy_grenadier";							//operator
blufor_SPECOPS_LAT_X =			"CFP_B_USCIA_paramilitary_officer_assault_03";		//operator
blufor_SPECOPS_HAT_X =			"cfp_b_iqarmy_at";									//operator
blufor_SPECOPS_AA_X =			"CUP_I_RACS_Soldier_AA";							//operator
blufor_SPECOPS_MG_X =			"CFP_B_USCIA_paramilitary_officer_assault_04";		//operator
blufor_SPECOPS_MEDIC_X =		"CFP_B_USCIA_paramilitary_officer_assault_02";		//operator
blufor_SPECOPS_MARK_X =			"CFP_B_USSEALS_Marksman_Light_AOR1_DES_01";			//operator
blufor_SPECOPS_SNIPER_X =		"cfp_b_iqarmy_sniper";								//operator
blufor_SPECOPS_EXP_X =			"CFP_B_USSEALS_Explosive_Specialist_AOR1_DES_01";	//operator
blufor_SPECOPS_ENG_X = 			"cfp_b_iqarmy_sapper";								//operator





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
	["cfp_b_iqarmy_rifleman","Rifleman (2CP)",2],
	["cfp_b_iqarmy_grenadier","Grenadier (3CP)",3],
	["cfp_b_iqarmy_machinegunner","Heavy Gunner (4CP)",4],
	["cfp_b_iqarmy_medic","Medic (3CP)",3],
	["cfp_b_iqarmy_at","AT Specialist (4CP)",4],
	["cfp_b_iqarmy_sapper","Engineer (4CP)",4],
	["cfp_b_iqarmy_sniper","Sniper (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["B_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["CFP_B_IQARMY_HMMWV_Mk19_GPK_IQSF","HMMV GMG (18CP)",18],
	["cfp_b_iqarmy_hmmwv_m2_gpk","HMMV HMG (15CP)",15],
	["cfp_b_iqarmy_mrap_rg31","RG-31 HMG (20CP)",20],
	["cfp_b_iqarmy_mrap_ridgback_hmg","Ridgeback HMG(25CP)",25],
	["cfp_b_iqarmy_mrap_wolfhound_hmg","Wolfhound HMG (28CP)",28],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (10CP)",10],
	["cfp_b_iqarmy_Ural","URAL Transport Covered (8CP)",8],
	["cfp_b_iqarmy_Ural_Repair_01","URAL Repair (50CP)",50],
	["cfp_b_iqarmy_Ural_Ammo_01","URAL Ammo (50CP)",50],
	["cfp_b_iqarmy_Ural_Refuel_01","URAL Fuel (50CP)",50],
	["CFP_B_IQARMY_M113","M113 HMG (25CP)",25],
	["cfp_b_iqarmy_BTR60","BTR-60 (28CP)",28],
	["cfp_b_iqarmy_BMP1","BMP-1 (30CP)",30],
	["cfp_b_iqarmy_BMP1P","BMP-1P (32CP)",32],
	["cfp_b_iqarmy_BMP2","BMP-2 (35CP)",35],
	["CUP_B_M1126_ICV_MK19_Desert","Stryker GMG (30CP)",30],
	["CUP_B_M2A3Bradley_USA_D","Bradley ERA (40CP)",40],
	["cfp_b_iqarmy_T55","T-55 Tank (40CP)",40],
	["cfp_b_iqarmy_T72","T-72 Tank (45CP)",45],
	["cfp_b_iqarmy_M1A1","M1A1 Abrahms (50CP)",50],
	["cfp_b_iqarmy_ZSU","ZSU-23 Tunguska (50CP)",50],
	["CUP_I_M270_DPICM_RACS","M270 MLRS Artillery (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CFP_B_USCIA_Mi_8MT_01","MI-8 Trans (20CP)",20],
	["cfp_b_iqarmy_MI24P","MI-24P (25CP)",25],
	["CUP_B_UH60M_FFV_US","UH-60 Armed (28CP)",28],
	["CUP_B_AH64D_DL_USA","AH-64 Attack Heli (40CP",40],
	["CUP_B_CH47F_USA","CH-47 Transport (26CP)",26],
	["CUP_B_MH47E_USA","MH-47 Trans Armed (30CP)",30],
	["cfp_b_iqarmy_SU25","SU-25 Frogfoot CAS (45CP)",45],
	["CUP_B_AV8B_DYN_USMC","AV-8 Harrier (50CP)",50],
	["CUP_B_MV22_USMC_RAMPGUN","MV-22 Osprey (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_B_USMC_DYN_MQ9","UAV MQ-9 Reaper (USMC)(15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


