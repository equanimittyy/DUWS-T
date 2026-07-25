// Third setup screen (after enviro + campaign params): name the player squad.
// Confirm commits the campaign; Back returns to the campaign screen. ESC is
// disabled like the other startup screens so setup must be seen through.
class startup_dialog3
{
    idd = -1;
    movingenable = false;
    onLoad = "(_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";

    class ControlsBackground
    {
        class background3: RscText
        {
            idc = -1;
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 34 * GUI_GRID_W;
            h = 12 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
    };

    class controls
    {
        class background_request3: RscText
        {
            idc = 1469;
            x = 2.4 * GUI_GRID_W + GUI_GRID_X;
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 35 * GUI_GRID_W;
            h = 13 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class callsign_mainframe: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_callsign_frame";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 34 * GUI_GRID_W;
            h = 12 * GUI_GRID_H;
        };
        class callsign_prompt: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_callsign_prompt";
            x = 4 * GUI_GRID_W + GUI_GRID_X;
            y = 9.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 32 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
        };
        class callsign_edit: RscEdit
        {
            idc = 1400;
            x = 4 * GUI_GRID_W + GUI_GRID_X;
            y = 14 * GUI_GRID_H + GUI_GRID_Y;
            w = 32 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_callsign_prompt";
        };
        class startR_button: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_aphcxbq2";
            x = 16 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0, 0.5};
            tooltip = "$STR_DUWS_T_ytu0ovg2";
            action = "[false] spawn fnc_callsign_confirm;";
        };
        class startM_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_yvdmalcu";
            x = 26 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0, 0.5};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};  // grey when hardcore disables it (matches Back)
            tooltip = "$STR_DUWS_T_7zexk7d5";
            action = "[true] spawn fnc_callsign_confirm;";
        };
        class back_button: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_startup_back";
            x = 5 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_startup_back";
            action = "[] spawn fnc_callsign_back;";
        };
    };
};
