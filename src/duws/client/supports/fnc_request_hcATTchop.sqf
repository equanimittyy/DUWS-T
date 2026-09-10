// Invoked from the comm menu, shared/includes/supports_radio_modern.hpp:187. Attack gunship sortie:
// flies straight to HQ, is handed to the player, then leashes back off the map. Shared flow lives in
// fnc_hcair_sortie; only the gunship-specific config differs from the CAS jet.

private _grouptype = [];
switch (VERSION_X) do {
	case "MODERN": {
		_grouptype = [blufor_ATTACK_HELI_X];
	};
};

[[
	"hcAttChop", "hc_ATTchop", "STR_DUWS_T_hcair_busy_gunship", "STR_DUWS_T_hcair_cooldown_gunship",
	"STR_DUWS_T_hcattrequest", "STR_DUWS_T_hcattack",
	200, _grouptype, "HC_ATTchop", "STR_DUWS_T_casdownlb",
	false, 0, 0, 0,
	"MOVE", 0, 600,
	"DUWS_number_attackchopa", "STR_DUWS_T_hc_gunship_squad",
	"STR_DUWS_T_longbowpilot", "STR_DUWS_T_longbowin", "STR_DUWS_T_rjuehu36", "STR_DUWS_T_hc_attchop_rtb"
]] call fnc_hcair_sortie;
