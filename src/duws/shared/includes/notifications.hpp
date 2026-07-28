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

    class ScoreAdded
    {
        title = "$STR_DUWS_T_668shcf1";
        iconText = "+%2";
        description = "%1";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {"netStats"};
    };

    class Location_enter
    {
        title = "$STR_DUWS_T_zjxh0fh4"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\mapcontrol\tourism_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "$STR_DUWS_T_l843uwpu"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class Location_leave
    {
        title = "$STR_DUWS_T_zjxh0fh4"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\mapcontrol\tourism_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "$STR_DUWS_T_aibgwt2g"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class US_takencontrol
    {
        title = "$STR_DUWS_T_drq88qxs"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\markers\military\flag_CA.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "$STR_DUWS_T_4qpf7a88"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0,1,0,1}; // Icon and text color
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
        color[] = {1,0,0,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class task_echec
    {
        title = "$STR_DUWS_T_1efzglbh"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\mapcontrol\taskIconFailed_ca.paa";
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%1"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,0.3,0.2,1};
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

    class CPloot
    {
        title = "$STR_DUWS_T_k1glh3eb2";
        iconText = "+%1";
        description = "$STR_DUWS_T_2x9bb19m2";
        color[] = {0.5,1,1,1};
        priority = 0;
        difficulty[] = {};
    };

    class CPadded_retaken
    {
        title = "$STR_DUWS_T_arxufadx";
        iconText = "+%1";
        description = "$STR_DUWS_T_ey0lpqcb";
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

    class CPaddedciv
    {
        title = "$STR_DUWS_T_elszwwpc3";
        iconText = "+%1";
        description = "$STR_DUWS_T_zcxhmft53";
        color[] = {0.5,1,1,1};
        duration = 4;
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
        color[] = {0,1,0,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class info2
    {
        title = "$STR_DUWS_T_gwn85uxh"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\A3\ui_f\data\map\markers\military\warning_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%1 %2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class artyicon
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\artillery_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
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

    class pflir
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Thermal_imaging_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class new_ability
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Commanding_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0.67,0.87,0,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class inf_training
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Miss_icon_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };	

    class operator_healed
    {
        title = "$STR_DUWS_T_55g6poab"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\BasicStances_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "$STR_DUWS_T_ze9vuqvj"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0.39,0.82,0.96,1}; // Icon and text color
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
        color[] = {1,0,0,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };	

    class repup
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Flares_CA.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0,1,0,1}; // Icon and text color
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
    class dakaijunhuoku
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

    class weizhuang
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\Adjust_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {0.5,1,1,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };

    class weizhuangdapo
    {
        title = "%1"; // Tile displayed as text on black background. Filled by arguments.
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\BasicWalk_ca.paa"; // Small icon displayed in left part. Colored by "color", filled by arguments.
        iconText = ""; // Short text displayed over the icon. Colored by "color", filled by arguments.
        description = "%2 %3"; // Brief description displayed as structured text. Colored by "color", filled by arguments.
        color[] = {1,0,0,1}; // Icon and text color
        duration = 4; // How many seconds will the notification be displayed
        priority = 0; // Priority; higher number = more important; tasks in queue are selected by priority
        difficulty[] = {}; // Required difficulty settings. All listed difficulties has to be enabled
    };
    class arsenal_warning
    {
        title = "%1";                       // 标题，由调用时传入
        iconPicture = "\a3\ui_f\data\gui\cfg\hints\NormalDamage_ca.paa";  // 可选：金钱图标
        iconText = "";
        description = "%2";                 // 描述，由调用时传入
        color[] = {1,0,0,1};           // 金黄色
        duration = 4;
        priority = 5;
        difficulty[] = {};
    };
};