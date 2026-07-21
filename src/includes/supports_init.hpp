
// Supports are local to players.  No need for publicVariable

support_supplydrop_available = false;
support_veh_drop_available = false;
support_siva_drop_available = false;
support_sawp_drop_available = false;
support_veh_recycle_available = false;
support_uav_recon_available = false;
support_helotaxi_available = false;
support_helolift_available = false;
support_boattaxi_available = false;
support_jdam_available = false;
support_mortar_available = false;
support_arty_available = false;
support_laser_available = false;
support_cluster_available = false;
support_napalm_available = false;
support_hcAttChop_available = false;
AttChopInUse = false;
support_hcCAS_available = false;
CASInUse = false;
support_paradrop_available = false;
support_mobile_HQ_available = true;
support_hcCAP_available = false;
support_veh_repair_available = false;
if (isNil "support_armory_available") then {
    support_armory_available = false;
};

if (isNil "support_halo_available") then {
	support_halo_available = false;
};

if (isNil "support_FOB_available") then {
	support_FOB_available = false;
};
