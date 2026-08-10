
//  AMMO TYPES:  Arty (Sh_155mm_AMOS) / Laser (Bo_Mk82) / Mortar(Sh_82mm_AMOS) / JDAM (Bo_Mk82) / Cluster(R_60mm_HE)
//  SUPPORT TYPE: 1 = arty, 2 = mortar, 3 = jdam, 4 = laser, 5 = cluster, 6 = napalm

class CfgCommunicationMenu
{
    class artillery
    {
        text = "$STR_DUWS_T_q3roy1kl"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
		//_null = [salvos, radius, interval between salvos(in seconds), rounds per salvo, support type, CP cost, ammotype]
        expression = "['artillery'] call fnc_support_comm_used; [6, 100, 8, 3, 1, 0, 'Sh_155mm_AMOS'] spawn fnc_mapclickarty"; // cost 0: one-time use, paid at purchase, not per fire
        icon = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\artillery_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = "\a3\Ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa"; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class mortar
    {
        text = "$STR_DUWS_T_d0x7zj1h"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
		//_null = [salvos, radius, interval between salvos(in seconds), rounds per salvo, support type, CP cost, ammotype]
        expression = "['mortar'] call fnc_support_comm_used; [8, 50, 5, 3, 2, 0, 'Sh_82mm_AMOS'] spawn fnc_mapclickarty"; // cost 0: one-time use, paid at purchase
        icon = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\mortar_ca.paa";
        cursor = "\a3\Ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa"; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class jdam
    {
        text = "$STR_DUWS_T_wcohwh4p"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
		//_null = [salvos, radius, interval between salvos(in seconds), rounds per salvo, support type, CP cost, ammotype]
        expression = "['jdam'] call fnc_support_comm_used; [1, 2, 1, 1, 3, 0, 'Bo_Mk82'] spawn fnc_mapclickarty"; // cost 0: one-time use, paid at purchase
        icon = "\a3\ui_f\data\gui\cfg\CommunicationMenu\cas_ca.paa";
        cursor = "\a3\Ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa"; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class laser
    {
        text = "$STR_DUWS_T_ifnnl0j7"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
		//_null = [salvos, radius, interval between salvos(in seconds), rounds per salvo, support type, CP cost, ammotype]
        expression = "['laser'] call fnc_support_comm_used; [1, 50, 1, 1, 4, 0, 'Laser'] spawn fnc_mapclickarty"; // cost 0: one-time use, paid at purchase
        icon = "\a3\ui_f\data\gui\cfg\hints\Head_ca.paa";
        cursor = "\a3\Ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa"; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class cluster
    {
        text = "$STR_DUWS_T_jznptb3c"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
		//_null = [salvos, radius, interval between salvos(in seconds), rounds per salvo, support type, CP cost, ammotype]
        expression = "['cluster'] call fnc_support_comm_used; [1, 175, 1, 90, 5, 0, 'Cluster'] spawn fnc_mapclickarty"; // cost 0: one-time use, paid at purchase
        icon = "\a3\ui_f\data\gui\cfg\hints\Death_ca.paa";
        cursor = "\a3\Ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa"; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class napalm
    {
        text = "$STR_DUWS_T_bhmydfkv"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
		//_null = [salvos, radius, interval between salvos(in seconds), rounds per salvo, support type, CP cost, ammotype]
        expression = "['napalm'] call fnc_support_comm_used; [1, 50, 1, 8, 6, 0, 'Napalm'] spawn fnc_mapclickarty"; // cost 0: one-time use, paid at purchase
        icon = "\a3\ui_f\data\gui\cfg\hints\Death_ca.paa";
        cursor = "\a3\Ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa"; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class SITREP
    {
        text = "$STR_DUWS_T_puy8tdeb"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "[] spawn fnc_sitrep_support"; // Code executed upon activation (ignored when the submenu is not empty)
        icon = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\call_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 0; // 1 to remove the item after calling
    };
    class ammo
    {
        text = "$STR_DUWS_T_32rh9x5x"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['ammo'] call fnc_support_comm_used; [player, 0] spawn fnc_ammobox"; // cost 0: one-time use, paid at purchase
        icon = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\supplydrop_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // one-time use: removed on use, consumed by fnc_support_comm_used
    };
    class veh_drop
    {
        text = "$STR_DUWS_T_cwflheuj"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['veh_drop'] call fnc_support_comm_used; [player, 0] spawn fnc_veh_drop"; // cost 0: one-time use, paid at purchase
        icon = "\A3\ui_f\data\Map\VehicleIcons\iconParachute_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // one-time use: removed on use, consumed by fnc_support_comm_used
    };
    class siva_drop
    {
        text = "$STR_DUWS_T_jjzzkt02"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['siva_drop'] call fnc_support_comm_used; [player, 0] spawn fnc_siva_drop"; // cost 0: one-time use, paid at purchase
        icon = "\A3\ui_f\data\Map\VehicleIcons\iconParachute_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // one-time use: removed on use, consumed by fnc_support_comm_used
    };
    class sawp_drop
    {
        text = "$STR_DUWS_T_sawp4321"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['sawp_drop'] call fnc_support_comm_used; [player, 0] spawn fnc_sawp_drop"; // cost 0: one-time use, paid at purchase
        icon = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\supplydrop_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // one-time use: removed on use, consumed by fnc_support_comm_used
    };
    class paradrop
    {
        text = "$STR_DUWS_T_nafdmcoy"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['paradrop'] call fnc_support_comm_used; [player, 0] spawn fnc_paradrop"; // cost 0: one-time use, paid at purchase
        icon = "\a3\ui_f\data\gui\cfg\hints\BasicStances_ca.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // one-time use: removed on use, consumed by fnc_support_comm_used
    };
    class uav_recon
    {
        text = "$STR_DUWS_T_n17vw60y"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['uav_recon'] call fnc_support_comm_used; [0] spawn fnc_mapclickuav"; // cost 0: one-time use, paid at purchase
        icon = "\a3\ui_f\data\gui\cfg\hints\Radar_ca.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class fob_support
    {
        text = "$STR_DUWS_T_h3uo0102"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['fob_support'] call fnc_support_comm_used; [getpos player, 500, 10] spawn fnc_request_fob"; 
        icon = "\a3\ui_f\data\gui\cfg\hints\Commanding_ca.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class helo_taxi
    {
        text = "$STR_DUWS_T_1ptvv5b1"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['helo_taxi'] call fnc_support_comm_used; [getpos player,100, 0] spawn fnc_helotaxi"; 
        icon = "\A3\ui_f\data\Map\VehicleIcons\iconHelicopter_ca.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class helo_lift
    {
        text = "$STR_DUWS_T_helolift"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['helo_lift'] call fnc_support_comm_used; [getpos player,100, 0] spawn fnc_helolift"; 
        icon = "\A3\ui_f\data\Map\VehicleIcons\iconHelicopter_ca.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
    class boat_taxi
    {
        text = "$STR_DUWS_T_evqwlyhz"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['boat_taxi'] call fnc_support_comm_used; [getpos player,10, 0] spawn fnc_boattaxi"; 
        icon = "\A3\ui_f\data\Map\VehicleIcons\iconShip_ca.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
	class hc_ATTchop
    {
        text = "$STR_DUWS_T_9bxjbidl"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['hc_ATTchop'] call fnc_support_comm_used; [0] spawn fnc_request_hcATTchop"; 
        icon = "\A3\ui_f\data\Map\Markers\NATO\b_air.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };

	class hc_CAS
    {
        text = "$STR_DUWS_T_f5y7ue87"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "['hc_CAS'] call fnc_support_comm_used; [0] spawn fnc_request_hcCAS"; 
        icon = "\A3\ui_f\data\Map\Markers\NATO\b_plane.paa";
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        removeAfterExpressionCall = 1; // 1 to remove the item after calling
    };
	
	class mobile_HQ
    {
        text = "$STR_DUWS_T_ooi6w4yh"; // Text displayed in the menu and in a notification
        submenu = ""; // Submenu opened upon activation
        expression = "[0] spawn fnc_MHQ_select"; 
        icon = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa"; // Icon displayed permanently next to the command menu
        cursor = ""; // Custom cursor displayed when the item is selected
        enable = "1"; // Simple expression condition for enabling the item
        // Kept, not consumed. Every other outcome of designating is a refusal the player has to be
        // able to act on -- wrong vehicle, nothing under the cursor, one already assigned -- and an
        // entry that vanishes on each of them made the permanent unlock feel like a spent charge.
        removeAfterExpressionCall = 0;
    };

};                             



