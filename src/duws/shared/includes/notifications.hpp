class CfgNotifications
{
    class Default
    {
        title = ""; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = ""; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = ""; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    // Examples

    class US_takencontrol
    {
        title = "$STR_DUWS_T_drq88qxs"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\markers\military\flag_CA.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "$STR_DUWS_T_4qpf7a88"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0.2,0.5,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class US_lostcontrol
    {
        title = "$STR_DUWS_T_q0seuzgl"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\markers\military\warning_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "$STR_DUWS_T_ztgsrx05"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,0.2,0.2,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    // The town's own map glyph, so the card points at the marker that just changed colour.
    class TownFlip
    {
        iconPicture = "\A3\ui_f\data\map\mapcontrol\Tourism_CA.paa";
        iconText = "";
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    class town_blufor : TownFlip
    {
        title = "$STR_DUWS_T_TOWN_FLIP_BLUFOR_TITLE";
        description = "$STR_DUWS_T_TOWN_FLIP_BLUFOR_MSG";
        color[] = {0.2,0.5,1,1};
    };

    class town_opfor : TownFlip
    {
        title = "$STR_DUWS_T_TOWN_FLIP_OPFOR_TITLE";
        description = "$STR_DUWS_T_TOWN_FLIP_OPFOR_MSG";
        color[] = {1,0.2,0.2,1};
    };

    class town_neutral : TownFlip
    {
        title = "$STR_DUWS_T_TOWN_FLIP_NEUTRAL_TITLE";
        description = "$STR_DUWS_T_TOWN_FLIP_NEUTRAL_MSG";
        color[] = {1,1,1,1};
    };

    class town_discovered : TownFlip
    {
        title = "$STR_DUWS_T_INTEL_REVEAL_TOWN_TITLE";
        description = "%1";
        color[] = {0.2,0.5,1,1};
    };

    // The zone marker's own glyph and colour.
    class zone_discovered
    {
        title = "$STR_DUWS_T_INTEL_REVEAL_ZONE_TITLE";
        iconPicture = "\A3\ui_f\data\map\markers\nato\o_inf.paa";
        iconText = "";
        description = "%1";
        color[] = {1,0.2,0.2,1};
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    class CPadded
    {
        title = "$STR_DUWS_T_k1glh3eb";
        iconText = "+%1";
        description = "$STR_DUWS_T_2x9bb19m";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    // Loss twin of the CP-gain family: red instead of cyan, "-%1" badge. The %1 (cost) feeds
    // both the badge and the description sentence.
    class CPlost
    {
        title = "$STR_DUWS_T_DEATH_CP_TITLE";
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Death_ca.paa";
        iconText = "-%1";
        description = "$STR_DUWS_T_DEATH_CP_MSG";
        color[] = {1,0.2,0.2,1};
        priority = 0;
        difficulty[] = {};
    };

    // A destroyed enemy hardpoint, carded like the rest of the CP-gain family: iconText the
    // bounty (%1), description the type (%2) and the place (%3) -- see DUWS_fnc_hardpointClear.
    class HPdestroyed
    {
        title = "$STR_DUWS_T_HP_destroyed_title";
        iconText = "+%1";
        description = "$STR_DUWS_T_HP_destroyed";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    // The Army Power half of an AP-paying strongpoint's bounty (the radio tower, the batteries),
    // posted as its own card beside the CP one so each currency reads on its own line rather than
    // sharing a badge: iconText the AP gained (%1), description the type (%2) and the place (%3),
    // reusing the CP card's body key. Raised only when the type pays AP.
    class HPdestroyedAP
    {
        title = "$STR_DUWS_T_HP_destroyed_ap_title";
        iconText = "+%1";
        description = "$STR_DUWS_T_HP_destroyed";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    // No bounty badge: a minefield pays nothing. %1 goes unused so the args match the shared body key.
    class HPcleared
    {
        title = "$STR_DUWS_T_HP_cleared_title";
        description = "$STR_DUWS_T_HP_destroyed";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    class CPaddedmission
    {
        title = "$STR_DUWS_T_elszwwpc";
        iconText = "+%1";
        description = "$STR_DUWS_T_zcxhmft5";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    // A bonus map reveal announces itself, so this one only ever reports the CP.
    class intel_analysis
    {
        title = "$STR_DUWS_T_INTEL_ANALYSIS_TITLE";
        iconText = "+%1";
        description = "$STR_DUWS_T_INTEL_ANALYSIS_AWARD";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    class CPaddedattrition
    {
        title = "$STR_DUWS_T_CPATTRITION_TITLE";
        iconText = "+%1";
        description = "$STR_DUWS_T_CPATTRITION_MSG";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    class APaddedmission
    {
        title = "$STR_DUWS_T_elszwwpc2";
        iconText = "+%1";
        description = "$STR_DUWS_T_zcxhmft52";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    // BLUFOR's force reached a new capability tier (WARCOM_blufor_tier, fnc_economy_init). Team news
    // like a zone capture, so a card, not a hint. Blue = something gained. The rank chevron is the
    // grayscale (_gs) glyph, tinted by the class colour; %1 is the new tier's capability name
    // (DUWS_fnc_tierName -- Infantry/Motorised/.../Air), filled from the call site.
    class tier_up
    {
        title = "$STR_DUWS_T_TIER_UP_TITLE";
        iconPicture = "\A3\Ui_f\data\GUI\Cfg\Ranks\sergeant_gs.paa";
        iconText = "";
        description = "$STR_DUWS_T_TIER_UP_MSG";
        color[] = {0.2,0.5,1,1};
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    // OPFOR reached a new capability tier (WARCOM_opfor_tier, fnc_economy_init). Same card as tier_up
    // but red -- enemy escalation, a warning not a gain -- and the call site fires no accompanying sound.
    class tier_up_opfor
    {
        title = "$STR_DUWS_T_TIER_UP_OPFOR_TITLE";
        iconPicture = "\A3\Ui_f\data\GUI\Cfg\Ranks\sergeant_gs.paa";
        iconText = "";
        description = "$STR_DUWS_T_TIER_UP_OPFOR_MSG";
        color[] = {1,0.2,0.2,1};
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    class info
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\markers\military\warning_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    // Title comes from the call site: this class carries four different losses -- a FOB, the MHQ,
    // the commanding officer, a rise in escalation -- and a fixed title titled every one of them "FOB Lost".
    class alert
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\markers\military\warning_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,0.2,0.2,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    // Red like the loss family, but a distinct category: the failure/critical card the player is
    // told about because they have to act, not because a thing is already gone. Carries the campaign
    // defeat card and the enemy-contact card (HQ, FOBs, held zones). Kept off white info deliberately
    // -- these must not read as neutral chatter. Title and body both come from the call site.
    class critical
    {
        title = "%1";
        iconPicture = "\A3\ui_f\data\map\markers\military\warning_ca.paa";
        iconText = "";
        description = "%2";
        color[] = {1,0.2,0.2,1};
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    // A rigged decoy laptop's fuse warning. The one card in the mission set that carries an
    // exclamation, because it is an act-now alarm and not a report. Bomb glyph (the IED hint icon,
    // the same one the laptop mission wears on the map), red like the loss family, and held well past
    // the 6 s fuse so it cannot clear before the blast.
    class rigged_decoy
    {
        title = "$STR_DUWS_T_RIGGED_DECOY_TITLE";
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa";
        iconText = "";
        description = "$STR_DUWS_T_RIGGED_DECOY_MSG";
        color[] = {1,0.2,0.2,1};
        duration = 8;
        priority = 10;
        difficulty[] = {};
    };

    class sitrepinfo
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\call_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

	
	

    class biohazard
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Death_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,0.2,0.2,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };	

    class repup
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\igui\cfg\simpleTasks\types\meet_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0.2,0.5,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };
    class repdown
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\igui\cfg\simpleTasks\types\meet_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,0.2,0.2,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };	

    class missionclean
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Chemlights_CA.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };
    // One class per permanent unlock, inheriting everything but the icon and the sentence. Not spread
    // across shared classes: the shared warning triangle over an unlock reads wrong, and a title
    // naming the facility only repeats the row the player just clicked. The class name is derived from
    // the catalogue key (server/supports/fnc_support_perm_grant.sqf), so a new permanent row needs a
    // class here under the matching name or its card draws the engine's empty default.
    class rally_placed
    {
        title = "$STR_DUWS_T_RALLY_PLACED_TITLE";
        iconPicture = "\A3\ui_f\data\map\markers\military\flag_CA.paa";
        iconText = "";
        description = "$STR_DUWS_T_RALLY_PLACED_MSG";
        color[] = {0.2,0.5,1,1};
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    class SupportUnlock
    {
        title = "$STR_DUWS_T_SUPPORT_UNLOCK_TITLE";
        iconText = "";
        color[] = {1,1,1,1};
        duration = 4;
        priority = 0;
        difficulty[] = {};
    };

    class unlock_armory : SupportUnlock
    {
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Sniper_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_ARMORY";
    };

    class unlock_halo : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\Map\VehicleIcons\iconParachute_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_HALO";
    };

    class unlock_mobile_HQ : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\map\markers\military\flag_CA.paa";
        description = "$STR_DUWS_T_UNLOCK_MOBILE_HQ";
    };

    // The FOB wears the icon its own comm-menu item wears
    // (shared/includes/supports_radio_modern.hpp), so the card and the 0-8 entry it grants match.
    class unlock_fob : SupportUnlock
    {
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Commanding_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_FOB";
    };

    class unlock_logistics : SupportUnlock
    {
        iconPicture = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\supplydrop_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_LOGISTICS";
    };

    // The combined vehicle depot (repair + recycle) wears the engine's repair action icon: no stock
    // glyph depicts recycling, and repair is the closer of the pair. Class name matches the "repair"
    // support key's successor -- the perm-grant card is raised as unlock_<key>.
    class unlock_vehicle_depot : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_REPAIR";
    };

    // The three radio tiers wear the recon-radar glyph the uav_recon comm item wears -- the closest
    // stock icon to a transmitter, and the amplifier they buy is an information-age effect on the map.
    class unlock_radio1 : SupportUnlock
    {
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Radar_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_RADIO1";
    };

    class unlock_radio2 : SupportUnlock
    {
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Radar_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_RADIO2";
    };

    class unlock_radio3 : SupportUnlock
    {
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Radar_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_RADIO3";
    };

    // The four garage expansions wear the depot's own repair glyph: they are the depot growing, and no
    // stock icon depicts a motor pool any closer. Class name is unlock_<key> like every perm-grant card.
    class unlock_garage1 : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_GARAGE1";
    };

    class unlock_garage2 : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_GARAGE2";
    };

    class unlock_garage3 : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_GARAGE3";
    };

    class unlock_garage4 : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_GARAGE4";
    };

    class arsenal
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Firemode_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    // Raised once by the server when the Game Master slot (player1) is empty after setup begins:
    // only that slot drives faction/HQ placement, so with it empty the setup gates never clear and
    // the campaign hangs with no on-screen cause. Held far longer than the 4s default -- it asks for
    // a restart and fires a single time, so it must survive being glanced past.
    class no_gamemaster
    {
        title = "$STR_DUWS_T_NO_GM_TITLE";
        iconPicture = "\A3\ui_f\data\map\markers\military\warning_ca.paa";
        iconText = "";
        description = "$STR_DUWS_T_NO_GM_MSG";
        color[] = {1,0.2,0.2,1};
        duration = 20;
        priority = 10;
        difficulty[] = {};
    };

};