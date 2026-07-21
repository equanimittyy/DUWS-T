// TODO: Localize text in source/dialog/startup/startup.hpp
class startup_dialog2
{
    idd = -1;
    movingenable = false;
	// Disable ESC key
	onLoad = "(_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";
    onUnload = "[] spawn fnc_startup_closed"; // UI event handler

	class ControlsBackground
	{
		class background2: RscText
		{
			idc = -1;

			x = 0.1 * GUI_GRID_W + GUI_GRID_X;
			y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
			w = 40 * GUI_GRID_W;
			h = 28 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};

		};
 
	};
    class controls
    {
        class background_request2: RscText
        {
            idc = 1469;
            x = -0.6 * GUI_GRID_W + GUI_GRID_X;
            y = -0.48 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 29 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class campaign_definer_mainframe2: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_i565mofh";
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 28 * GUI_GRID_H;
        };
        class zone_max_radius_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_2gf389k1";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_6x0c0ho3";
        };
        class zone_max_radius_combo: RscCombo
        {
            idc = 2100;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_6x0c0ho3";
        };
        class zone_min_radius_frame: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_mijl4ykv";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_1yxblh7g";
        };
        class zone_min_radius_combo: RscCombo
        {
            idc = 2101;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_1yxblh7g";
        };
        class zone_number_frame: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_byc79mjg";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_uj9yb3v8";
        };
        class zone_number_combo: RscCombo
        {
            idc = 2102;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_uj9yb3v8";
        };
        class max_dist_from_hq_frame: RscFrame
        {
            idc = 1804;
            text = "$STR_DUWS_T_mh2r420p";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_4ybnb5ku";
        };
        class max_dist_from_hq_combo: RscCombo
        {
            idc = 2103;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_4ybnb5ku";
        };
        class cp_start_frame: RscFrame
        {
            idc = 1805;
            text = "$STR_DUWS_T_xouz1ovr";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_lwq336is";
        };
        class cp_start_combo: RscCombo
        {
            idc = 2104;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_lwq336is";
        };
        class more_urban_frame: RscFrame
        {
            idc = 1806;
            text = "$STR_DUWS_T_enmvtlks";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_cr4pww43";
        };
        class more_urban_combo: RscCombo
        {
            idc = 2105;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_cr4pww43";
        };
        class cp_reward_multiplier_frame: RscFrame
        {
            idc = 1807;
            text = "$STR_DUWS_T_twbmsd5i";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_4jqlply9";
        };
        class cp_reward_multiplier_combo: RscCombo
        {
            idc = 2106;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_4jqlply9";
        };
        class cp_death_penalty_frame: RscFrame
        {
            idc = 1808;
            text = "$STR_DUWS_T_ngtt96xa";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_a84c45ax";
        };
        class cp_death_penalty_combo: RscCombo
        {
            idc = 2107;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_a84c45ax";
        };
        class bap_start_frame: RscFrame
        {
            idc = 1809;
            text = "$STR_DUWS_T_jcl7xwoc";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 13.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_7znv4kjl";
        };
        class bap_start_combo: RscCombo
        {
            idc = 2108;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_7znv4kjl";
        };
        class oap_start_frame: RscFrame
        {
            idc = 1810;
            text = "$STR_DUWS_T_xs0vv40j";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_586o8589";
        };
        class oap_start_combo: RscCombo
        {
            idc = 2109;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_586o8589";
        };
        class blufor_ai_skill_frame: RscFrame
        {
            idc = 1811;
            text = "$STR_DUWS_T_80baoqlf";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 16.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_mi2u6xqg";
        };
        class blufor_ai_skill_combo: RscCombo
        {
            idc = 2110;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_mi2u6xqg";
        };
        class opfor_ai_skill_frame: RscFrame
        {
            idc = 1812;
            text = "$STR_DUWS_T_x47k308l";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 16.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_f69mtwtg";
        };
        class opfor_ai_skill_combo: RscCombo
        {
            idc = 2111;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_f69mtwtg";
        };
        class opfor_air_frame: RscFrame
        {
            idc = 1813;
            text = "$STR_DUWS_T_5jbcoh7i";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 19.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_ovqhayce";
        };
        class opfor_air_combo: RscCombo
        {
            idc = 2112;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 20.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_ovqhayce";
        };
		class opfor_multiplier_frame: RscFrame
		{
			idc = 1814;

			text = "$STR_DUWS_T_7ymqziim"; 
			x = 20.5 * GUI_GRID_W + GUI_GRID_X;
			y = 19.5 * GUI_GRID_H + GUI_GRID_Y;
			w = 18.5 * GUI_GRID_W;
			h = 2.5 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_qsicj6l0";
		};
		class opfor_multiplier_combo: RscCombo
		{
			idc = 2113;

			x = 21 * GUI_GRID_W + GUI_GRID_X;
			y = 20.5 * GUI_GRID_H + GUI_GRID_Y;
			w = 17.5 * GUI_GRID_W;
			h = 1 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_qsicj6l0";
		};

        class text_information2: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_5cb1bbvi";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 22.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 39 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
        };
        class start_button1: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_aphcxbq2";
            x = 12 * GUI_GRID_W + GUI_GRID_X;
            y = 26 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0,0.5};
            tooltip = "$STR_DUWS_T_ytu0ovg2";
            action = "[] spawn fnc_startup_random_zones;";
        };
        class start_button2: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_yvdmalcu";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 26 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0,0.5};
            tooltip = "$STR_DUWS_T_7zexk7d5";
            action = "[] spawn fnc_startup_manual_zones;";
        };
    };
};