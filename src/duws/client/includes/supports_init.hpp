
// Support flags, one per catalogue row (client/supports/fnc_supports_init.sqf).
//
// A consumable flag is the buyer's own and is reset unconditionally: it is lost on death and does
// not survive a reconnect either, so a fresh copy is always the truth. A permanent flag is team
// state and must default behind isNil -- a joining client is sent the team's value before this
// runs, so an unconditional assignment overwrites it locally and then pushes the wrong state back
// out the next time that client broadcasts.

support_supplydrop_available = false;
support_veh_drop_available = false;
support_siva_drop_available = false;
support_sawp_drop_available = false;
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

// How many consumable supports this player is holding, against server_var_init's support_max_slots.
// Per-player and never broadcast, because the slate is. Initialised for everyone rather than for
// squad leads alone: it is now the refund's bookkeeping as well as the purchase gate, and a slot
// counter that is undefined on some machines makes both throw there.
support_count = 0;

// What each held consumable actually charged, keyed by catalogue key, and which comm-menu items
// the player is currently holding, keyed by class. Both are per-player, so neither is broadcast;
// both are plain strings and numbers, so neither is the kind of value the mission namespace
// refuses to serialise.
DUWS_support_paid = createHashMap;
DUWS_support_comm = createHashMap;

if (isNil "support_veh_recycle_available") then {
    support_veh_recycle_available = false;
};
if (isNil "support_mobile_HQ_available") then {
    support_mobile_HQ_available = false;
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

// The two permanent supports whose effect is a comm-menu item hand it to every player, not just
// the buyer, because they are bought for the team. The publicVariableEventHandler is the hook
// rather than a broadcast from the buyer: it fires only once the flag has actually landed here,
// so the ownership test inside fnc_support_comm_add cannot lose a race with it.
"support_mobile_HQ_available" addPublicVariableEventHandler { ["mobile_HQ"] call fnc_support_comm_add };
"support_FOB_available" addPublicVariableEventHandler { ["fob_support"] call fnc_support_comm_add };
