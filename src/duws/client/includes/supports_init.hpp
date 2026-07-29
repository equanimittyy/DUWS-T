
// Most support flags are player-local and need no publicVariable. The five that are broadcast
// on unlock are team state, and must default behind isNil: a joining client is sent the team's
// value before this runs, so an unconditional assignment overwrites it locally and then pushes
// the wrong state back out the next time that client broadcasts.

support_supplydrop_available = false;
support_veh_drop_available = false;
support_siva_drop_available = false;
support_sawp_drop_available = false;
if (isNil "support_veh_recycle_available") then {
    support_veh_recycle_available = false;
};
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
// Defaults true: this flag reads "still unclaimed", unlike every other flag here.
if (isNil "support_mobile_HQ_available") then {
    support_mobile_HQ_available = true;
};
if (isNil "support_veh_repair_available") then {
    support_veh_repair_available = false;
};
if (isNil "support_armory_available") then {
    support_armory_available = false;
};

if (isNil "support_halo_available") then {
	support_halo_available = false;
};

if (isNil "support_FOB_available") then {
	support_FOB_available = false;
};
