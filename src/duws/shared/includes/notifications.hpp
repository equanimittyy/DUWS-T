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
    // These two exist for their icon alone: a support unlock is white like every other one, and the
    // shared white card would put a warning triangle over "VA Arsenal / Unlocked".
    class armory
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Sniper_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class halo
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\Map\VehicleIcons\iconParachute_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
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