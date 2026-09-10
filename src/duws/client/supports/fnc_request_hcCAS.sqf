// Invoked from the comm menu, shared/includes/supports_radio_modern.hpp:198. CAS jet sortie:
// ferries in high, loiters over HQ until handed to the player, then leashes back off the map.
// Shared flow lives in fnc_hcair_sortie; only the jet-specific config differs from the gunship.

[[
	"hcCAS", "hc_CAS", "STR_DUWS_T_hcair_busy_jet", "STR_DUWS_T_hcair_cooldown_jet",
	"STR_DUWS_T_hccasrequest", "STR_DUWS_T_hccasack",
	600, [blufor_MISC_AIR_X], "HC_CAS", "STR_DUWS_T_casdownkoi",
	true, 1000, 150, 1000,
	"LOITER", 800, 1200,
	"DUWS_number_CAS", "STR_DUWS_T_hc_cas_squad",
	"STR_DUWS_T_koipilot", "STR_DUWS_T_koiin", "STR_DUWS_T_gu6cbc5f", "STR_DUWS_T_hc_cas_rtb"
]] call fnc_hcair_sortie;
