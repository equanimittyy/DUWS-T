
///////////////   "ffaa_bripac", "FFAA Spanish Army BRIPAC + MOE Desert", "FFAA_BRIPAC_DES"


blufor_SOLDIER_X =				"ffaa_bripac_fusilero_mochila_ds";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"ffaa_bripac_c90_ds";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"ffaa_bripac_granadero_ds";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"ffaa_bripac_jefe_peloton_ds";			//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"ffaa_bripac_jefe_escuadra_ds";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"ffaa_bripac_mg4_ds";					//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"ffaa_bripac_tirador_ds";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"ffaa_bripac_oficial_ds";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"ffaa_pilot_f18";						//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"ffaa_famet_cougar_armed";				//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"ffaa_nh90_nfh_transport";   			//random patrol
blufor_ATTACK_HELI_X =			"ffaa_famet_tigre";						//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"ffaa_ar_harrier";						//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"ffaa_et_lince_m2";						//random patrol
blufor_APC1_X =					"ffaa_et_toa_m2";						//random patrol        
blufor_APC2_X =					"ffaa_et_pizarro_mauser";				//random patrol     
blufor_MBT_TANK1_X =			"ffaa_et_leopardo";						//random patrol


blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";



blufor_SPECOPS_X =				"ffaa_et_moe_fusilero_mochila_ds";		//operator
blufor_SPECOPS_GL_X =			"ffaa_et_moe_lg_ds";					//operator
blufor_SPECOPS_LAT_X =			"ffaa_et_moe_at_C90_ds";				//operator
blufor_SPECOPS_HAT_X =			"ffaa_et_moe_at_ds";					//operator
blufor_SPECOPS_AA_X =			"B_soldier_AA_F";						//operator
blufor_SPECOPS_MG_X =			"ffaa_et_moe_mg_ds";					//operator
blufor_SPECOPS_MEDIC_X =		"ffaa_et_moe_medico_ds";				//operator
blufor_SPECOPS_MARK_X =			"ffaa_ar_fgne_tirador_ds";				//operator
blufor_SPECOPS_SNIPER_X =		"ffaa_et_moe_tirador_ds";				//operator
blufor_SPECOPS_EXP_X =			"ffaa_et_moe_sabot_ds";					//operator
blufor_SPECOPS_ENG_X = 			"ffaa_ar_fgne_sabot_ds";				//operator





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
	["ffaa_bripac_fusilero_mochila_ds","Rifleman (Desert) (2CP)",2],
	["ffaa_bripac_granadero_ds","Grenadier (Desert) (3CP)",3],
	["ffaa_bripac_mg4_ds","Automatic Rifleman (Desert) (3CP)",3],
	["ffaa_bripac_mg42_ds","Heavy Gunner (Desert) (4CP)",4],
	["ffaa_bripac_medico_ds","Medic (Desert) (4CP)",4],
	["ffaa_bripac_c90_ds","Rifleman AT (Desert) (4CP)",4],
	["ffaa_bripac_alcotan_ds","AT Specialist (Desert) (4CP)",4],
	["ffaa_bripac_ingeniero_ds","Engineer (Desert) (4CP)",4],
	["ffaa_bripac_tirador_ds","Marksman (Desert) (3CP)",3],
	["ffaa_bripac_francotirador_accuracy_ds","Sniper (Desert) (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["ffaa_et_vamtac_crows","VAMTAC HMG crows (18CP)",18],
	["ffaa_et_vamtac_tow","VAMTAC TOW (25CP)",25],
	["ffaa_et_vamtac_mistral","VAMTAC Mistral (28CP)",28],
	["ffaa_et_lince_m2","Lince HMG (15CP)",15],
	["ffaa_et_lince_lag40","Lince GMG (20CP)",20],
	["ffaa_et_rg31_samson","RG-31 Samson (25CP)",25],
	["ffaa_et_pegaso_carga","Pegaso Transport Uncovered (8CP)",8],
	["ffaa_et_pegaso_carga_lona","Pigaso Transport Covered (8CP)",8],
	["ffaa_et_pegaso_repara_municion","Pigaso Repair (50CP)",50],
	["ffaa_et_pegaso_municion","Pigaso Ammo (50CP)",50],
	["ffaa_et_pegaso_combustible","Pigaso Fuel (50CP)",50],
	["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (35CP)",35],
	["ffaa_et_toa_m2","TOA M-113 HMG (35CP)",35],
	["ffaa_et_toa_spike","TOA M-113 Spike (35CP)",35],
	["ffaa_et_pizarro_mauser","Pizarro Mauser (35CP)",35],
	["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25],
	["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["ffaa_et_leopardo","Leopard 2E (50CP)",50],
	["B_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75],
	["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["ffaa_nh90_tth_armed","NH-90 Heli Armed (25CP)",25],
	["ffaa_famet_cougar_armed","AS-53 Cougar Armed (30CP)",30],
	["ffaa_famet_ch47_mg","CH-47 Chinook (30CP)",30],
	["ffaa_famet_tigre","EC-665 Tiger (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["ffaa_ar_harrier","AV-8B Harrier (45CP)",45],
	["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


