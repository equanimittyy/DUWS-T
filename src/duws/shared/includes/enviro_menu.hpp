// TODO: Localize text in source/dialog/startup/startup.hpp
class startup_dialog
{
    idd = -1;
    movingenable = false;
    // Disable ESC key
    onLoad = "(_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";
    onUnload = "[] spawn fnc_startup_enviro_closed"; // Back button routes to faction re-pick

    class ControlsBackground
    {
        class background: RscText
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
        class background_request: RscText
        {
            idc = 1469;
            x = -0.6 * GUI_GRID_W + GUI_GRID_X;
            y = -0.48 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 29 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class campaign_definer_mainframe: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_ref5pt72";
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 28 * GUI_GRID_H;
        };
        class weather_type_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_dd7k7nvb";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_d3pm4snm";
        };
        class weather_type_combo: RscCombo
        {
            idc = 2100;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_d3pm4snm";
        };
        class timeofday_frame: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_o5pwyqqg";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_kie5t25c";
        };
        class timeofday_combo: RscCombo
        {
            idc = 2101;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_kie5t25c";
        };
        class civamount_frame: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_civamount";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_civamount2";
        };
        class civamount_combo: RscCombo
        {
            idc = 2102;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_civamount2";
        };
        class fast_travel_frame: RscFrame
        {
            idc = 1804;
            text = "$STR_DUWS_T_hxmfg4zk";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_1s29j337";
        };
        class fast_travel_combo: RscCombo
        {
            idc = 2103;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_1s29j337";
        };
        class zeus_params_frame: RscFrame
        {
            idc = 1805;
            text = "$STR_DUWS_T_wypkoiz4";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_g18ovd4o";
        };
        class zeus_params_combo: RscCombo
        {
            idc = 2104;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_g18ovd4o";
        };
        class stamina_frame: RscFrame
        {
            idc = 1806;
            text = "$STR_DUWS_T_APOCALYPSE_TITLE";
            tooltip = "$STR_DUWS_T_APOCALYPSE_TOOLTIP";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
        };
        class stamina_combo: RscCombo
        {
            idc = 2105;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_APOCALYPSE_TOOLTIP";
        };
        // ========== 焦土模式（原 VCOM 控件） ==========
        class SE_frame: RscFrame
        {
            idc = 1807;
            text = "$STR_DUWS_T_scorched_earth_title";
            tooltip = "$STR_DUWS_T_scorched_earth_tooltip";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
        };
        class SE_combo: RscCombo
        {
            idc = 2106;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_scorched_earth_tooltip";
        };
        // ============================================
        class time_multiplier_frame: RscFrame
        {
            idc = 1808;
            text = "$STR_DUWS_T_9f7m3bn3";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_6kdpe8ew";
        };
        class time_multiplier_combo: RscCombo
        {
            idc = 2107;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_6kdpe8ew";
        };
        class simple_zones_frame: RscFrame
        {
            idc = 1809;
            text = "$STR_DUWS_T_bm4k1vwo";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 13.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_34g1rdwe";
        };
        class simple_zones_combo: RscCombo
        {
            idc = 2108;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_r69kq1g1";
        };
        class civ_type_frame: RscFrame
        {
            idc = 1810;
            text = "$STR_DUWS_T_psaz6ueo";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_5qklarv1";
        };
        class civ_type_combo: RscCombo
        {
            idc = 2109;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_5qklarv1";
        };
        class hardcore_mode_frame: RscFrame
        {
            idc = 1811;
            text = "$STR_DUWS_T_uxvi77tr";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 16.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8vvbwo7p";
        };
        class hardcore_mode_combo: RscCombo
        {
            idc = 2110;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8vvbwo7p";
        };
        class insurgent_mode_frame: RscFrame
        {
            idc = 1812;
            text = "$STR_DUWS_T_e8ius2zx";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 16.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_inswarning";
            colorText[] = {1,0,0,1};
        };
        class insurgent_mode_combo: RscCombo
        {
            idc = 2111;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_inswarning";
        };
        class text_information: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_rkf6smez";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 22.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 39 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
        };
        class next_button: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_xxci6q7d";
            x = 16 * GUI_GRID_W + GUI_GRID_X;
            y = 26 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0,0.5};
            tooltip = "$STR_DUWS_T_iumlwewp";
            action = "[] spawn fnc_process_enviro_menu;";
        };
        class back_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_startup_back";
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 26 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_startup_back_faction";
            action = "[] spawn fnc_enviro_back;";
        };
    };
};