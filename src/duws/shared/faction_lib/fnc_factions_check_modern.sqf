
// make 2 local arrays [_faction_files_BLU] and [_faction_files_OPF]
//  - fill them with meta data about the faction files
//  - faction files for BLUFOR have a completely different unit/vehicle format
//    than OPFOR faction files
//  - BLUFOR array contents should be identical to the OPFOR array
//
// [basic rifleman classname, faction class, selection menu label, faction file]
//
//  - faction class defines the faction classname i.e.  BLU_F for NATO (arid)
//  - faction class is used primarily for Random Vehicle patrols
//  - faction file defines the file containing all of the classnames available 

//  Don't need a BLUFOR (BLU_F_ARID) or OPFOR (OPF_F_ARID)
//	 - they are DEFAULTs
if (!isServer) exitWith {};

// Publish the AutoDetect helpers (fnc_factionSelector, fnc_getAllFactionsClean,
// fnc_parseFaction, ...) up front so the setup-screen faction picker can use them
// before START. Otherwise they only come into existence when an AUTODETECT faction
// file is compiled at the post-START commit, and the picker fires too late.
call compile preprocessFileLineNumbers "duws\shared\factions\MODERN\fn_factionAutoDetect.sqf";

_faction_files_BLUFOR = [
["O_T_Soldier_F", "BLU_AUTO", "AutoDetect - [RECOMMENDED]","AUTODETECT"],    // classnames for check are units that're always available,csat
["O_R_Patrol_Soldier_A_F", "OPF_R_F_Spetsnaz", "Spetsnaz","OPF_R_F_Spetsnaz"],

["B_T_Soldier_F", "BLU_F_T", "NATO (Pacific)","BLU_F_PACIFIC"],
["O_Soldier_F", "OPF_F", "CSAT (Arid)","OPF_F_ARID"],
["O_T_Soldier_F", "OPF_F_T", "CSAT (Pacific)","OPF_F_PACIFIC"],
["I_soldier_F", "IND_F", "AAF Altis Armed Forces","IND_F"],
["rhs_msv_emr_rifleman", "RHS_msv", "RHS Russia MSV+Spetsnaz (EMR)","RHS_MSV_EMR"],
["rhs_msv_rifleman", "RHS_msv", "RHS Russia MSV+Spetsnaz (Flora)","RHS_MSV_flora"],
["rhs_vdv_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (EMR)", "RHS_VDV_emr"],
["rhs_vdv_des_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (Desert)", "RHS_VDV_DES"],
["rhs_vdv_flora_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (Flora)", "RHS_VDV_flora"],
["rhs_vdv_mflora_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (m.Flora)", "RHS_VDV_mflora"],
["rhsusf_army_ocp_rifleman", "RHSUSF_ARMY", "RHS US Army (OCP Desert) + SOCOM", "RHSUSF_ARMY_OCP_D"],
["rhsusf_army_ocp_rifleman", "RHSUSF_ARMY", "RHS US Army (OCP Wood) + SOCOM", "RHSUSF_ARMY_OCP_WD"],
["rhsusf_army_ucp_rifleman", "RHSUSF_ARMY", "RHS US Army (UCP Desert) + SOCOM", "RHSUSF_ARMY_UCP_D"],
["rhsusf_army_ucp_rifleman", "RHSUSF_ARMY", "RHS US Army (UCP Wood) + SOCOM", "RHSUSF_ARMY_UCP_WD"],
["rhsusf_army_ocp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (OCP Desert) + SOCOM", "RHSUSF_AIRBORNE_OCP_D"],
["rhsusf_army_ocp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (OCP Wood) + SOCOM", "RHSUSF_AIRBORNE_OCP_WD"],
["rhsusf_army_ucp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (UCP Desert) + SOCOM", "RHSUSF_AIRBORNE_UCP_D"],
["rhsusf_army_ucp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (UCP Wood) + SOCOM", "RHSUSF_AIRBORNE_UCP_WD"],
["rhsusf_usmc_marpat_d_rifleman", "RHSUSF_USMC", "RHS USMC (Desert) + RECON", "RHSUSF_USMC_D"],
["rhsusf_usmc_marpat_wd_rifleman", "RHSUSF_USMC", "RHS USMC (Wood) + RECON", "RHSUSF_USMC_WD"],
["LOP_ISTS_OPF_Infantry_Rifleman", "LOP_ISTS_OPF", "PrOPFOR Middle East Insurgents", "LOP_ISTS_OPF"],
["LOP_UA_Infantry_Rifleman_2", "LOP_UA", "PrOPFOR Eastern Bloc Insurgents", "LOP_EASTBLOC"],
["LOP_IA_Infantry_Rifleman", "LOP_IA", "PrOPFOR IRAQI Army + USA Specops", "LOP_IA"],
["LOP_SYR_Infantry_Rifleman", "LOP_SYR", "PrOPFOR SYRIAN Army + Spetsnaz", "LOP_SYR"],
["LOP_IRAN_Infantry_Rifleman_2", "LOP_IRAN", "PrOPFOR IRAN Army", "LOP_IRAN"],
["LOP_UKR_Infantry_Rifleman", "LOP_UKR", "PrOPFOR UKRAINE Army", "LOP_UKR"],
["CUP_O_RU_Soldier_M_EMR", "CUP_O_RU", "CUP Russian MSV(emr) + Spetsnaz","CUP_O_RU_MMSV"],
["CUP_O_RU_Soldier_VDV_M_EMR", "CUP_O_RU", "CUP Russian VDV(emr) + Spetsnaz","CUP_O_RU_MVDV"],
["CUP_O_RU_Soldier_VDV", "CUP_O_RU", "CUP Russian VDV(ttsko) + Spetsnaz","CUP_O_RU_VDVT"],
["CUP_O_RU_Soldier_Ratnik_Winter", "CUP_O_RU", "CUP Russian Ratnik(Winter)+Spetsnaz","CUP_O_RU_WINTER"],
["CUP_B_US_Soldier", "CUP_B_US_Army", "CUP US Army (UCP Desert) + SpecOps","CUP_B_US_Army_UCP_D"],
["CUP_B_US_Soldier", "CUP_B_US_Army", "CUP US Army (UCP Wood) + SpecOps","CUP_B_US_Army_UCP_W"],
["CUP_B_US_Soldier_ACOG_OCP", "CUP_B_US_Army", "CUP US Army (OCP Desert) + SpecOps","CUP_B_US_Army_OCP_D"],
["CUP_B_US_Soldier_ACOG_OCP", "CUP_B_US_Army", "CUP US Army (OCP Wood) + SpecOps","CUP_B_US_Army_OCP_W"],
["CUP_B_USMC_Soldier_FROG_DES", "CUP_B_USMC", "CUP USMC SpecOps Desert","CUP_B_USMC_D"],
["CUP_B_USMC_Soldier", "CUP_B_USMC", "CUP USMC (Wood) + SpecOps","CUP_B_USMC_W"],
["CUP_B_GER_BW_Soldier", "CUP_B_GER", "CUP Bundeswehr (Desert) + KSK","CUP_B_GER_BW"],
["CUP_B_GER_BW_Fleck_Soldier", "CUP_B_GER", "CUP Bundeswehr (Wood) + KSK","CUP_B_GER_BW_Fleck"],
["CUP_B_BAF_Soldier_Rifleman_DDPM", "CUP_B_BAF", "CUP British AF (DDPM)","CUP_B_BAF_DDPM"],
["CUP_B_BAF_Soldier_Rifleman_MTP", "CUP_B_BAF", "CUP British AF (MTP)","CUP_B_BAF_MTP"],
["CUP_I_RACS_Soldier", "CUP_O_RACS", "CUP Sahrani RACS (Desert)", "CUP_I_RACS_DESERT"],
["CUP_I_RACS_Soldier_wdl", "CUP_O_RACS", "CUP Sahrani RACS (Wood)", "CUP_I_RACS_WOOD"],
["CUP_O_SLA_Soldier_Backpack_desert", "CUP_O_SLA", "CUP Sahrani SLA (Desert)", "CUP_O_SLA_DESERT"],
["CUP_O_SLA_Soldier_Backpack", "CUP_O_SLA", "CUP Sahrani SLA (Wood)", "CUP_O_SLA_WOOD"],
["CUP_B_CDF_Soldier_MNT", "CUP_B_CDF", "CUP Chernarus Defense Force (Mntn)", "CUP_B_CDF_MNT"],
["CUP_O_INS_Soldier", "CUP_O_INS", "CUP ChDKZ + Spetsnaz","CUP_O_ChDKZ"],
["CUP_I_GUE_Soldier_AKS74", "CUP_I_GUE", "CUP Chernarus NAPA + USMC Recon","CUP_I_GUE"],
["CUP_O_TK_Soldier", "CUP_O_TK", "CUP Takistani Army","CUP_O_TK_Army2"],
["CUP_O_TK_Soldier", "CUP_O_TK", "CUP Takistani Army + USA SpecOps","CUP_O_TK_Army"],
["CUP_O_TK_INS_Soldier", "CUP_I_TK_GUE", "CUP Takistani Insurgents + Militia","CUP_I_TK_GUE_MIX"],
["cfp_o_is_rifleman", "CFP_O_IS", "CFP Middle East Insurgents", "CFP_O_IS"],
["cfp_b_ypg_rifleman","CFP_B_YPG", "CFP YPG (Kurds) + USAF Support", "CFP_B_YPG"],
["CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01","CFP_O_HEZBOLLAH","CFP Hezbollah + Captured Vehicles","CFP_O_HEZBOLLAH"],
["cfp_b_iqarmy_rifleman", "CFP_B_IQARMY", "CFP IRAQI Army (modern) + USA SpecOps", "CFP_B_IQARMY"],
["CFP_O_IRARMY_Rifleman_01", "CFP_O_IRARMY", "CFP IRAN Army", "CFP_O_IRARMY"],
["cfp_o_syarmy_rifleman", "CFP_O_SYARMY", "CFP SYRIAN Arab Army (SAA) + Spetsnaz", "CFP_O_SYARMY"],
["CUP_B_CDF_Soldier_SNW", "CFP_B_CDF", "CFP Chernarus Defense Force (Winter)", "CFP_B_CDF_SNW"],
["CFP_O_CHDKZ_Rifleman_AK_74_SNW_01", "CFP_O_CHDKZ", "CFP ChDKZ + Spetsnaz (Winter)", "CFP_O_CHDKZ_SNW"],
["ffaa_bripac_fusilero_mochila_ds", "ffaa_bripac", "FFAA Spanish Army BRIPAC + MOE Desert", "FFAA_BRIPAC_DES"],
["ffaa_bripac_fusilero_mochila", "ffaa_bripac", "FFAA Spanish Army BRIPAC + MOE Wood", "FFAA_BRIPAC_WDL"],
["BWA3_Rifleman_G27_Tropen", "BWA3", "BWA3 German Bundeswehr + KSK (Desert)", "BWA3_DES"],
["BWA3_Rifleman_G27_Fleck", "BWA3", "BWA3 German Bundeswehr + KSK (Wood)", "BWA3_WDL"],
["PLA_Soldier_HM_F", "PLA", "VME PLA Chinese Army + SpecOps (Desert)", "VME_PLA_DES"],
["PLAFOR_Soldier", "PLAFOR", "VME PLA Chinese Army + SpecOps (Forest)", "VME_PLA_FOR"],
["PLA_Soldier_F", "PLA", "VME PLA Chinese Army + SpecOps (Wood)", "VME_PLA_WDL"],
["sfp_m90d_rifleman_long_m08", "SFP", "SFP Swedish Forces + SOG (Desert)", "SFP_DES"],
["sfp_m90w_rifleman_ak5", "SFP", "SFP Swedish Forces + SOG (Wood)", "SFP_WDL"],
["B_FR_Fusilier_01", "B_FR", "AMF AIO French Army (T3 camo)", "B_FR_AMFAIO"],
["PSZ_PL_DES20_Soldier_Rifleman", "PSZ_PL", "PSZ Polish Army (DES20)", "PSZ_PL_DES20"],
["PSZ_PL_WDL20_Soldier_Rifleman", "PSZ_PL", "PSZ Polish Army (WDL20)", "PSZ_PL_WDL20"],
["Japan_JP_Jeitai_Soldier_Base", "JAPAN_JP", "JP Japan JGSDF (Jeitai-D)", "JAPAN_JP_JeitaiD"],
["Japan_JP_Jeitai_Soldier_Base", "JAPAN_JP", "JP Japan JGSDF (Jeitai-W)", "JAPAN_JP_JeitaiW"],
["ASZ_EI_rifleman_06A", "ASZ_EI", "PEDAGNE Italian Army + SOF (Vegecam + Vegetata)", "ASZ_EI"],
["TFC_C_Soldier_OTW_Rifleman_TW_F", "TFC", "Task Force Canada (Tmpr-OTW) + USMC", "TFC_TEMP"],
["UK3CB_BAF_Pointman_DDPM", "UK3CB_BAF", "3CB British AF (Desert)", "UK3CB_BAF_DES"],
["UK3CB_BAF_Pointman_MTP", "UK3CB_BAF", "3CB British AF (MTP)", "UK3CB_BAF_MTP"],
["UK3CB_BAF_Pointman_DPMW", "UK3CB_BAF", "3CB British AF (Woodland)", "UK3CB_BAF_WDL"],
["UK3CB_CW_US_B_LATE_RIF_1", "UK3CB_CW_US_B", "3CB US Army 80s (Wood)","3CB_US80_WDL"],
["UK3CB_CW_SOV_O_LATE_RIF_1", "UK3CB_CW_SOV_O", "3CB USSR MSV 80s (Wood)","3CB_USSR80_MSV_WDL"],
["UK3CB_CW_SOV_O_LATE_VDV_RIF_1", "UK3CB_CW_SOV_O", "3CB USSR VDV 80s (Wood)","3CB_USSR80_VDV_WDL"],
["B_A_Soldier_F", "BLU_A_F", "Aegis British - 2035 (Arid)", "AEG_BLU_A_F_ARID"],
["B_A_Soldier_TNA_F", "BLU_A_TNA_F", "Aegis British - 2035 (Pacific)", "AEG_BLU_A_TNA_F"],
["B_A_Soldier_WDL_F", "BLU_A_WDL_F", "Aegis British - 2035 (Woodland)", "AEG_BLU_A_WDL_F"],
["O_R_Soldier_ard_F", "OPF_R_ard_F", "Aegis Russia - 2035 (Arid)", "AEG_OPF_R_ARD_F"],
["O_R_Soldier_F", "OPF_R_F", "Aegis Russia - 2035 (Wood)", "AEG_OPF_R_F_WDL"],
["NATO_WINTER_SOLDIER", "NATO_WINTER", "NATO (Winter)", "NATO_WINTER"],
["RIFLEMAN_WINTER_HEX", "CSAT_WINTER", "CSAT (Winter)", "CSAT_WINTER"],
["CWR3_o_soldier", "CWR3_O", "CWR3 Soviet Armed Forces (1985)", "CWR3_RUS"],
["CWR3_b_soldier", "CWR3_B", "CWR3 US Armed Forces (1985)", "CWR3_USA"],
["MIN_RF_SOLDIER", "MIN_RF", "Russia 2035 (Wood)", "MIN_RF_WDL"],
["MIN_RF_SOLDIER_DESERT", "MIN_RF", "Russia 2035 (Desert)", "MIN_RF_DES"],
["OPTRE_UNSC_Marine_Soldier_Rifleman_BR", "OPTRE_UNSC", "OPTRE UNSCDF (Marines)", "OPTRE_UNSC_MAR"],
["OPTRE_UNSC_Army_Soldier_Rifleman_BR_OLI", "OPTRE_UNSC", "OPTRE UNSCDF (Olive)", "OPTRE_UNSC_OLI"],
["OPTRE_UNSC_Army_Soldier_Rifleman_BR_WDL","OPTRE_UNSC", "OPTRE UNSCDF (Woodland)", "OPTRE_UNSC_WDL"],
["TIOW_Cad_GM667th", "TIOW_CADIAN_667", "Cadian 667th (White)", "TIOW_CADIAN_667"],
["TIOW_Cad_GM700th", "TIOW_CADIAN_700", "Cadian 700th (White-Brown)", "TIOW_CADIAN_700"],
["TIOW_Cad_GM776th", "TIOW_CADIAN_776", "Cadian 776th (Green)", "TIOW_CADIAN_776"],
["TIOW_Cad_GM836th", "TIOW_CADIAN_836", "Cadian 836th (Brown)", "TIOW_CADIAN_836"],
["DKoK_GM_1489th", "TIOW_DKOK_1489", "Death Korps of Krieg 1489th (Black)", "TIOW_DKOK_1489"],
["DKoK_GM_1490th", "TIOW_DKOK_1490", "Death Korps of Krieg 1490th (Feldgrau)", "TIOW_DKOK_1490"],
["DKoK_GM_1491st", "TIOW_DKOK_1491", "Death Korps of Krieg 1491st (Steingrau)", "TIOW_DKOK_1491"],
["DKoK_GM_82nd", "TIOW_DKOK_82", "Death Korps of Krieg 82nd (Blue)", "TIOW_DKOK_82"],
["TIOW_Mordian_Trooper_1_Blu", "TIOW_MORDIAN_blue", "TIOW Mordian Iron Guard (blue)", "TIOW_MORDIAN_blue"],
["TIOW_Valhallan_Trooper_1_brown_Blu", "TIOW_VALHALLAN_brown", "TIOW Valhallans (brown)", "TIOW_VALHALLAN_brown"],
["TIOW_Valhallan_Trooper_1_white_Blu", "TIOW_VALHALLAN_white", "TIOW Valhallans (white)", "TIOW_VALHALLAN_white"],
["TIOW_Valhallan_Trooper_1_camo_Blu", "TIOW_VALHALLAN_camo", "TIOW Valhallans (camo)", "TIOW_VALHALLAN_camo"],
["TIOW_Valhallan_Trooper_1_Blu", "TIOW_VALHALLAN_grey", "TIOW Valhallans (grey)", "TIOW_VALHALLAN_grey"],
["TIOW_B_Ren_BL_Rifleman", "TIOW_REN_BL", "TIOW Chaos Renegades (Black)", "TIOW_REN_BL"],
["TIOW_B_Ren_B_Rifleman", "TIOW_REN_B", "TIOW Chaos Renegades (Brown)", "TIOW_REN_B"],
["TIOW_B_Ren_GR_Rifleman", "TIOW_REN_GR", "TIOW Chaos Renegades (Grey)", "TIOW_REN_GR"],
["TIOW_B_Ren_G_Rifleman", "TIOW_REN_G", "TIOW Chaos Renegades (Green)", "TIOW_REN_G"],
["gm_ge_army_rifleman_g36a1_90_flk", "gm_fc_ge", "GM German Bundeswehr 90s (Wood) + USA (3CB)","GM_BW90_WDL"],
["gm_ge_army_rifleman_g36a1_90_win", "gm_fc_ge", "GM German Bundeswehr 90s (Winter) + USA (3CB)","GM_BW90_WIN"],
["gm_ge_army_rifleman_g3a3_parka_80_win", "gm_fc_ge", "GM German Bundeswehr 80s (Wood) + USA (3CB)","GM_BW80_WDL"],
["gm_ge_army_rifleman_g3a3_parka_80_win", "gm_fc_ge", "GM German Bundeswehr 80s (Winter) + USA (3CB)","GM_BW80_WIN"],
["gm_gc_army_rifleman_mpiak74n_80_str", "gm_fc_gc", "GM East German NVA (Wood) + USSR (3CB)", "GM_NVA_WDL"],
["gm_gc_army_rifleman_mpiak74n_80_win", "gm_fc_gc", "GM East German NVA (Winter) + USSR (3CB)", "GM_NVA_WIN"],
["gm_pl_army_rifleman_akm_80_moro", "gm_fc_pl", "GM Poland (Wood) + USSR (3CB)","GM_POLAND_WDL"],
["gm_pl_army_rifleman_akm_80_win", "gm_fc_pl", "GM Poland (Winter) + USSR (3CB)","GM_POLAND_WIN"],
["I_E_soldier_F", "I_E_F", "LDF Livonian Defense Force (Woodland)", "LDF_E_F_WDL"]

];

_faction_files_OPFOR = [

["O_T_Soldier_F", "OPFOR_AUTO", "AutoDetect - [RECOMMENDED]","AUTODETECT"],    // classnames for check are units that're always available,csat
["O_T_Soldier_F", "OPFOR_AUTO_RANDOM", "AutoDetect - RANDOM","AUTODETECT_RANDOM"],    // classnames for check are units that're always available,csat
["O_R_Patrol_Soldier_A_F", "OPF_R_F_Spetsnaz", "Spetsnaz","OPF_R_F_Spetsnaz"],


["O_T_Soldier_F", "OPF_F_T", "CSAT (Pacific)","OPF_F_PACIFIC"],
["B_Soldier_F", "BLU_F", "NATO (Arid)","BLU_F_ARID"],
["B_T_Soldier_F", "BLU_F_T", "NATO (Pacific)","BLU_F_PACIFIC"],
["I_soldier_F", "IND_F", "AAF Altis Armed Forces","IND_F"],
["O_G_Soldier_F", "OPF_G_F", "FIA Guerillas","OPF_G_F"],
["I_C_Soldier_Para_8_F", "I_C", "Syndikat Guerillas","I_C"],
["rhs_msv_emr_rifleman", "RHS_msv", "RHS Russia MSV+Spetsnaz (EMR)","RHS_MSV_EMR"],
["rhs_msv_rifleman", "RHS_msv", "RHS Russia MSV+Spetsnaz (Flora)","RHS_MSV_flora"],
["rhs_vdv_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (EMR)", "RHS_VDV_emr"],
["rhs_vdv_des_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (Desert)", "RHS_VDV_DES"],
["rhs_vdv_flora_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (Flora)", "RHS_VDV_flora"],
["rhs_vdv_mflora_rifleman", "RHS_vdv", "RHS Russia VDV+Spetsnaz (m.Flora)", "RHS_VDV_mflora"],
["rhsusf_army_ocp_rifleman", "RHSUSF_ARMY", "RHS US Army (OCP Desert) + SOCOM", "RHSUSF_ARMY_OCP_D"],
["rhsusf_army_ocp_rifleman", "RHSUSF_ARMY", "RHS US Army (OCP Wood) + SOCOM", "RHSUSF_ARMY_OCP_WD"],
["rhsusf_army_ucp_rifleman", "RHSUSF_ARMY", "RHS US Army (UCP Desert) + SOCOM", "RHSUSF_ARMY_UCP_D"],
["rhsusf_army_ucp_rifleman", "RHSUSF_ARMY", "RHS US Army (UCP Wood) + SOCOM", "RHSUSF_ARMY_UCP_WD"],
["rhsusf_army_ocp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (OCP Desert) + SOCOM", "RHSUSF_AIRBORNE_OCP_D"],
["rhsusf_army_ocp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (OCP Wood) + SOCOM", "RHSUSF_AIRBORNE_OCP_WD"],
["rhsusf_army_ucp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (UCP Desert) + SOCOM", "RHSUSF_AIRBORNE_UCP_D"],
["rhsusf_army_ucp_arb_rifleman", "RHSUSF_ARMY", "RHS USA Airborne (UCP Wood) + SOCOM", "RHSUSF_AIRBORNE_UCP_WD"],
["rhsusf_usmc_marpat_d_rifleman", "RHSUSF_USMC", "RHS USMC (Desert) + RECON", "RHSUSF_USMC_D"],
["rhsusf_usmc_marpat_wd_rifleman", "RHSUSF_USMC", "RHS USMC (Wood) + RECON", "RHSUSF_USMC_WD"],
["LOP_ISTS_OPF_Infantry_Rifleman", "LOP_ISTS_OPF", "PrOPFOR Middle East Insurgents", "LOP_ISTS_OPF"],
["LOP_AFR_OPF_Infantry_Rifleman", "LOP_AFR_OPF", "PrOPFOR African Insurgents", "LOP_AFR_OPF"],
["LOP_UA_Infantry_Rifleman_2", "LOP_UA", "PrOPFOR Eastern Bloc Insurgents", "LOP_EASTBLOC"],
["LOP_IA_Infantry_Rifleman", "LOP_IA", "PrOPFOR IRAQI Army + USA Specops", "LOP_IA"],
["LOP_SYR_Infantry_Rifleman", "LOP_SYR", "PrOPFOR SYRIAN Army + Spetsnaz", "LOP_SYR"],
["LOP_IRAN_Infantry_Rifleman_2", "LOP_IRAN", "PrOPFOR IRAN Army", "LOP_IRAN"],
["LOP_UKR_Infantry_Rifleman", "LOP_UKR", "PrOPFOR UKRAINE Army", "LOP_UKR"],
["CUP_O_RU_Soldier_M_EMR", "CUP_O_RU", "CUP Russian MSV(emr) + Spetsnaz","CUP_O_RU_MMSV"],
["CUP_O_RU_Soldier_VDV_M_EMR", "CUP_O_RU", "CUP Russian VDV(emr) + Spetsnaz","CUP_O_RU_MVDV"],
["CUP_O_RU_Soldier_VDV", "CUP_O_RU", "CUP Russian VDV(ttsko) + Spetsnaz","CUP_O_RU_VDVT"],
["CUP_O_RU_Soldier_Ratnik_Winter", "CUP_O_RU", "CUP Russian Ratnik(Winter)+Spetsnaz","CUP_O_RU_WINTER"],
["CUP_B_US_Soldier", "CUP_B_US_Army", "CUP US Army (UCP Desert) + SpecOps","CUP_B_US_Army_UCP_D"],
["CUP_B_US_Soldier", "CUP_B_US_Army", "CUP US Army (UCP Wood) + SpecOps","CUP_B_US_Army_UCP_W"],
["CUP_B_US_Soldier_ACOG_OCP", "CUP_B_US_Army", "CUP US Army (OCP Desert) + SpecOps","CUP_B_US_Army_OCP_D"],
["CUP_B_US_Soldier_ACOG_OCP", "CUP_B_US_Army", "CUP US Army (OCP Wood) + SpecOps","CUP_B_US_Army_OCP_W"],
["CUP_B_USMC_Soldier_FROG_DES", "CUP_B_USMC", "CUP USMC SpecOps Desert","CUP_B_USMC_D"],
["CUP_B_USMC_Soldier", "CUP_B_USMC", "CUP USMC (Wood) + SpecOps","CUP_B_USMC_W"],
["CUP_B_GER_BW_Soldier", "CUP_B_GER", "CUP Bundeswehr (Desert) + KSK","CUP_B_GER_BW"],
["CUP_B_GER_BW_Fleck_Soldier", "CUP_B_GER", "CUP Bundeswehr (Wood) + KSK","CUP_B_GER_BW_Fleck"],
["CUP_B_BAF_Soldier_Rifleman_DDPM", "CUP_B_BAF", "CUP British AF (DDPM)","CUP_B_BAF_DDPM"],
["CUP_B_BAF_Soldier_Rifleman_MTP", "CUP_B_BAF", "CUP British AF (MTP)","CUP_B_BAF_MTP"],
["CUP_I_RACS_Soldier", "CUP_O_RACS", "CUP Sahrani RACS (Desert)", "CUP_I_RACS_DESERT"],
["CUP_I_RACS_Soldier_wdl", "CUP_O_RACS", "CUP Sahrani RACS (Wood)", "CUP_I_RACS_WOOD"],
["CUP_O_SLA_Soldier_Backpack_desert", "CUP_O_SLA", "CUP Sahrani SLA (Desert)", "CUP_O_SLA_DESERT"],
["CUP_O_SLA_Soldier_Backpack", "CUP_O_SLA", "CUP Sahrani SLA (Wood)", "CUP_O_SLA_WOOD"],
["CUP_B_CDF_Soldier_MNT", "CUP_B_CDF", "CUP Chernarus Defense Force (Mntn)", "CUP_B_CDF_MNT"],
["CUP_I_GUE_Soldier_AKS74", "CUP_I_GUE", "CUP Chernarus NAPA + USMC Recon","CUP_I_GUE"],
["CUP_O_INS_Soldier", "CUP_O_INS", "CUP ChDKZ + Spetsnaz","CUP_O_ChDKZ"],
["CUP_O_TK_Soldier", "CUP_O_TK", "CUP Takistani Army","CUP_O_TK_Army2"],
["CUP_O_TK_Soldier", "CUP_O_TK", "CUP Takistani Army + USA SpecOps","CUP_O_TK_Army"],
["CUP_O_TK_INS_Soldier", "CUP_I_TK_GUE", "CUP Takistani Insurgents + Militia","CUP_I_TK_GUE_MIX"],
["cfp_o_is_rifleman", "CFP_O_IS", "CFP Middle East Insurgents", "CFP_O_IS"],
["cfp_b_ypg_rifleman","CFP_B_YPG", "CFP YPG (Kurds) + USAF Support", "CFP_B_YPG"],
["CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01","CFP_O_HEZBOLLAH","CFP Hezbollah + Captured Vehicles","CFP_O_HEZBOLLAH"],
["CFP_O_TBAN_Rifleman_AK_47_01","CFP_O_TBAN", "CFP Taliban (Modern)", "CFP_O_TBAN"],
["CFP_O_CFRebels_Rifleman_01", "CFP_O_CFRebels", "CFP African Insurgents", "CFP_O_CFRebels"],
["CFP_O_NKARMY_Rifleman_01", "CFP_O_NKARMY", "CFP North Korean Peoples Army", "CFP_O_NKARMY"],
["cfp_b_iqarmy_rifleman", "CFP_B_IQARMY", "CFP IRAQI Army (modern) + USA SpecOps", "CFP_B_IQARMY"],
["CFP_O_IRARMY_Rifleman_01", "CFP_O_IRARMY", "CFP IRAN Army", "CFP_O_IRARMY"],
["cfp_o_syarmy_rifleman", "CFP_O_SYARMY", "CFP SYRIAN Arab Army (SAA) + Spetsnaz", "CFP_O_SYARMY"],
["CUP_B_CDF_Soldier_SNW", "CFP_B_CDF", "CFP Chernarus Defense Force (Winter)", "CFP_B_CDF_SNW"],
["CFP_O_CHDKZ_Rifleman_AK_74_SNW_01", "CFP_O_CHDKZ", "CFP ChDKZ + Spetsnaz (Winter)", "CFP_O_CHDKZ_SNW"],
["ffaa_bripac_fusilero_mochila_ds", "ffaa_bripac", "FFAA Spanish Army BRIPAC + MOE Desert", "FFAA_BRIPAC_DES"],
["ffaa_bripac_fusilero_mochila", "ffaa_bripac", "FFAA Spanish Army BRIPAC + MOE Wood", "FFAA_BRIPAC_WDL"],
["BWA3_Rifleman_G27_Tropen", "BWA3", "BWA3 German Bundeswehr + KSK (Desert)", "BWA3_DES"],
["BWA3_Rifleman_G27_Fleck", "BWA3", "BWA3 German Bundeswehr + KSK (Wood)", "BWA3_WDL"],
["PLA_Soldier_HM_F", "PLA", "VME PLA Chinese Army + SpecOps (Desert)", "VME_PLA_DES"],
["PLAFOR_Soldier", "PLAFOR", "VME PLA Chinese Army + SpecOps (Forest)", "VME_PLA_FOR"],
["PLA_Soldier_F", "PLA", "VME PLA Chinese Army + SpecOps (Wood)", "VME_PLA_WDL"],
["sfp_m90d_rifleman_long_m08", "SFP", "SFP Swedish Forces + SOG (Desert)", "SFP_DES"],
["sfp_m90w_rifleman_ak5", "SFP", "SFP Swedish Forces + SOG (Wood)", "SFP_WDL"],
["B_FR_Fusilier_01", "B_FR", "AMF AIO French Army (T3 camo)", "B_FR_AMFAIO"],
["PSZ_PL_DES20_Soldier_Rifleman", "PSZ_PL", "PSZ Polish Army (DES20)", "PSZ_PL_DES20"],
["PSZ_PL_WDL20_Soldier_Rifleman", "PSZ_PL", "PSZ Polish Army (WDL20)", "PSZ_PL_WDL20"],
["Japan_JP_Jeitai_Soldier_Base", "JAPAN_JP", "JP Japan JGSDF (Jeitai-D)", "JAPAN_JP_JeitaiD"],
["Japan_JP_Jeitai_Soldier_Base", "JAPAN_JP", "JP Japan JGSDF (Jeitai-W)", "JAPAN_JP_JeitaiW"],
["ASZ_EI_rifleman_06A", "ASZ_EI", "PEDAGNE Italian Army + SOF (Vegecam + Vegetata)", "ASZ_EI"],
["UK3CB_BAF_Pointman_DDPM", "UK3CB_BAF", "3CB British AF (Desert)", "UK3CB_BAF_DES"],
["UK3CB_BAF_Pointman_MTP", "UK3CB_BAF", "3CB British AF (MTP)", "UK3CB_BAF_MTP"],
["UK3CB_BAF_Pointman_DPMW", "UK3CB_BAF", "3CB British AF (Woodland)", "UK3CB_BAF_WDL"],
["UK3CB_CW_US_B_LATE_RIF_1", "UK3CB_CW_US_B", "3CB US Army 80s (Wood)","3CB_US80_WDL"],
["UK3CB_CW_SOV_O_LATE_RIF_1", "UK3CB_CW_SOV_O", "3CB USSR MSV 80s (Wood)","3CB_USSR80_MSV_WDL"],
["UK3CB_CW_SOV_O_LATE_VDV_RIF_1", "UK3CB_CW_SOV_O", "3CB USSR VDV 80s (Wood)","3CB_USSR80_VDV_WDL"],
["B_A_Soldier_F", "BLU_A_F", "Aegis British - 2035 (Arid)", "AEG_BLU_A_F_ARID"],
["B_A_Soldier_TNA_F", "BLU_A_TNA_F", "Aegis British - 2035 (Pacific)", "AEG_BLU_A_TNA_F"],
["B_A_Soldier_WDL_F", "BLU_A_WDL_F", "Aegis British - 2035 (Woodland)", "AEG_BLU_A_WDL_F"],
["O_R_Soldier_ard_F", "OPF_R_ard_F", "Aegis Russia - 2035 (Arid)", "AEG_OPF_R_ARD_F"],
["O_R_Soldier_F", "OPF_R_F", "Aegis Russia - 2035 (Wood)", "AEG_OPF_R_F_WDL"],
["NATO_WINTER_SOLDIER", "NATO_WINTER", "NATO (Winter)", "NATO_WINTER"],
["RIFLEMAN_WINTER_HEX", "CSAT_WINTER", "CSAT (Winter)", "CSAT_WINTER"],
["CWR3_o_soldier", "CWR3_O", "CWR3 Soviet Armed Forces (1985)", "CWR3_RUS"],
["CWR3_b_soldier", "CWR3_B", "CWR3 US Armed Forces (1985)", "CWR3_USA"],
["MIN_RF_SOLDIER", "MIN_RF", "Russia 2035 (Wood)", "MIN_RF_WDL"],
["MIN_RF_SOLDIER_DESERT", "MIN_RF", "Russia 2035 (Desert)", "MIN_RF_DES"],
["OPTRE_UNSC_Marine_Soldier_Rifleman_BR", "OPTRE_UNSC", "OPTRE UNSCDF (Marines)", "OPTRE_UNSC_MAR"],
["OPTRE_UNSC_Army_Soldier_Rifleman_BR_OLI", "OPTRE_UNSC", "OPTRE UNSCDF (Olive)", "OPTRE_UNSC_OLI"],
["OPTRE_Ins_URF_Rifleman_BR", "OPTRE_Ins", "OPTRE Insurrectionists", "OPTRE_INSUR"],
["OPTRE_UNSC_Army_Soldier_Rifleman_BR_WDL","OPTRE_UNSC", "OPTRE UNSCDF (Woodland)", "OPTRE_UNSC_WDL"],
["OPTRE_FC_Elite_Minor2","OPTRE_FC_Covenant", "OPTRE Covenant","OPTRE_COVNT"],
["TIOW_Cad_GM667th", "TIOW_CADIAN_667", "Cadian 667th (White)", "TIOW_CADIAN_667"],
["TIOW_Cad_GM700th", "TIOW_CADIAN_700", "Cadian 700th (White-Brown)", "TIOW_CADIAN_700"],
["TIOW_Cad_GM776th", "TIOW_CADIAN_776", "Cadian 776th (Green)", "TIOW_CADIAN_776"],
["TIOW_Cad_GM836th", "TIOW_CADIAN_836", "Cadian 836th (Brown)", "TIOW_CADIAN_836"],
["DKoK_GM_1489th", "TIOW_DKOK_1489", "Death Korps of Krieg 1489th (Black)", "TIOW_DKOK_1489"],
["DKoK_GM_1490th", "TIOW_DKOK_1490", "Death Korps of Krieg 1490th (Feldgrau)", "TIOW_DKOK_1490"],
["DKoK_GM_1491st", "TIOW_DKOK_1491", "Death Korps of Krieg 1491st (Steingrau)", "TIOW_DKOK_1491"],
["DKoK_GM_82nd", "TIOW_DKOK_82", "Death Korps of Krieg 82nd (Blue)", "TIOW_DKOK_82"],
["TIOW_Mordian_Trooper_1_Blu", "TIOW_MORDIAN_blue", "TIOW Mordian Iron Guard (blue)", "TIOW_MORDIAN_blue"],
["TIOW_Valhallan_Trooper_1_brown_Blu", "TIOW_VALHALLAN_brown", "TIOW Valhallans (brown)", "TIOW_VALHALLAN_brown"],
["TIOW_Valhallan_Trooper_1_white_Blu", "TIOW_VALHALLAN_white", "TIOW Valhallans (white)", "TIOW_VALHALLAN_white"],
["TIOW_Valhallan_Trooper_1_camo_Blu", "TIOW_VALHALLAN_camo", "TIOW Valhallans (camo)", "TIOW_VALHALLAN_camo"],
["TIOW_Valhallan_Trooper_1_Blu", "TIOW_VALHALLAN_grey", "TIOW Valhallans (grey)", "TIOW_VALHALLAN_grey"],
["TIOW_B_Ren_BL_Rifleman", "TIOW_REN_BL", "TIOW Chaos Renegades (Black)", "TIOW_REN_BL"],
["TIOW_B_Ren_B_Rifleman", "TIOW_REN_B", "TIOW Chaos Renegades (Brown)", "TIOW_REN_B"],
["TIOW_B_Ren_GR_Rifleman", "TIOW_REN_GR", "TIOW Chaos Renegades (Grey)", "TIOW_REN_GR"],
["TIOW_B_Ren_G_Rifleman", "TIOW_REN_G", "TIOW Chaos Renegades (Green)", "TIOW_REN_G"],
["Naked1_Blu", "TIOW_Orks", "TIOW ORKZ", "TIOW_Orks"],
["gm_ge_army_rifleman_g36a1_90_flk", "gm_fc_ge", "GM German Bundeswehr 90s (Wood) + USA (3CB)","GM_BW90_WDL"],
["gm_ge_army_rifleman_g36a1_90_win", "gm_fc_ge", "GM German Bundeswehr 90s (Winter) + USA (3CB)","GM_BW90_WIN"],
["gm_ge_army_rifleman_g3a3_80_ols", "gm_fc_ge", "GM German Bundeswehr 80s (Wood) + USA (3CB)","GM_BW80_WDL"],
["gm_ge_army_rifleman_g3a3_parka_80_win", "gm_fc_ge", "GM German Bundeswehr 80s (Winter) + USA (3CB)","GM_BW80_WIN"],
["gm_gc_army_rifleman_mpiak74n_80_str", "gm_fc_gc", "GM East German NVA (Wood) + USSR (3CB)","GM_NVA_WDL"],
["gm_gc_army_rifleman_mpiak74n_80_win", "gm_fc_gc", "GM East German NVA (Winter) + USSR (3CB)","GM_NVA_WIN"],
["gm_pl_army_rifleman_akm_80_moro", "gm_fc_pl", "GM Poland (Wood) + USSR (3CB)","GM_POLAND_WDL"],
["gm_pl_army_rifleman_akm_80_win", "gm_fc_pl", "GM Poland (Winter) + USSR (3CB)","GM_POLAND_WIN"],
["gmx_chdkz_army_rifleman_akm_mix", "gmx_fc_chdkz", "GM ChDKZ + USSR (3CB)","GMX_CHDKZ_WDL"],
["I_E_soldier_F", "I_E_F", "LDF Livonian Defense Force (Woodland)", "LDF_E_F_WDL"]

];

_faction_files_BLUFOR = _faction_files_BLUFOR + [["B_Soldier_F", "CUSTOM", "CUSTOM BLUFOR Faction", "CUSTOM"]];
_faction_files_OPFOR = _faction_files_OPFOR + [["O_Soldier_F", "CUSTOM", "CUSTOM OPFOR Faction", "CUSTOM"]];

Factions_Available_BLUFOR_X = [];
Factions_Available_BLUFOR_X pushback ["BLU_F", "Default = NATO (Arid)","BLU_F_ARID"];

{
	if (isClass(configFile >> "CfgVehicles" >> (_x select 0))) then {
		Factions_Available_BLUFOR_X pushback [(_x select 1), (_x select 2), (_x select 3)];
	};

} foreach _faction_files_BLUFOR;

Factions_Available_OPFOR_X = [];
Factions_Available_OPFOR_X pushback ["OPF_F", "Default = CSAT (Arid)","OPF_F_ARID"];

{
	if (isClass(configFile >> "CfgVehicles" >> (_x select 0))) then {
		Factions_Available_OPFOR_X pushback [(_x select 1), (_x select 2), (_x select 3)];
	};

} foreach _faction_files_OPFOR;

publicVariable "Factions_Available_OPFOR_X";
publicVariable "Factions_Available_BLUFOR_X";
 
civ_mod = "vanilla";
if (isClass(configFile >> "CfgVehicles" >> "CUP_C_C_Citizen_01")) then {
    civ_mod = "cup";
} else {    
    if (isClass(configFile >> "CfgVehicles" >> "LOP_UKR_Infantry_Rifleman")) then {
        civ_mod = "propfor";
    } else {
        if (isClass(configFile >> "CfgVehicles" >> "CFP_O_CFRebels_Rifleman_01")) then {
            civ_mod = "cfp";
        };
    };
};
publicVariable "civ_mod";