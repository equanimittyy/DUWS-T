// TODO: Localize text in source/dialog/startup/startup.hpp
class startup_faction
{
    idd = -1;
    movingenable = false;
	// Disable ESC key
	onLoad = "(_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";

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
            text = "$STR_DUWS_T_w25pfxjk";
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 28 * GUI_GRID_H;
			
        };
        class blufor_faction_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_rqdziaei";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 20 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_y3jv4fm6";
        };
        class blufor_faction_window: RscEditMulti
        {
            idc = 2100;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 18 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_y3jv4fm6";
        };
        class opfor_faction_frame: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_1m1bl9nd";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 20 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_13p2iheb";
        };
        class opfor_faction_window: RscEditMulti
        {
            idc = 2101;
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.5 * GUI_GRID_W;
            h = 18 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_13p2iheb";
        };
        class text_information: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_vho23y9e";
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
            tooltip = "$STR_DUWS_T_g6bmrxtn";
            action = "[] spawn fnc_custom_faction_capture";
		};
    };
};



