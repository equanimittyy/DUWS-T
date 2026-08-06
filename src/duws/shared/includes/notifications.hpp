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

    class CPadded
    {
        title = "$STR_DUWS_T_k1glh3eb";
        iconText = "+%1";
        description = "$STR_DUWS_T_2x9bb19m";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    // A destroyed standalone enemy hardpoint, carded like the rest of the CP-gain family: iconText the
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

    class CPaddedmission
    {
        title = "$STR_DUWS_T_elszwwpc";
        iconText = "+%1";
        description = "$STR_DUWS_T_zcxhmft5";
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

    class infosearch
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Flares_CA.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0.2,0.5,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    // Title comes from the call site: this class carries four different losses -- a FOB, the MHQ,
    // an informant, a rise in escalation -- and a fixed title titled every one of them "FOB Lost".
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
    // One class per permanent unlock, inheriting everything but the icon and the sentence. The five
    // that announced themselves used to wear three different classes between them -- two of them the
    // shared warning triangle, over an unlock -- and each named the facility in a title the player
    // had just read on the row they clicked. The class name is derived from the catalogue key
    // (server/supports/fnc_support_perm_grant.sqf), so a new permanent row needs a class here under
    // the matching name or its card draws the engine's empty default.
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

    // The two depot stations share the engine's repair action icon: they are one pair of vehicle
    // services at the base, and no stock glyph depicts recycling to tell them apart with.
    class unlock_repair : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_REPAIR";
    };

    class unlock_recycle : SupportUnlock
    {
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa";
        description = "$STR_DUWS_T_UNLOCK_RECYCLE";
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

};