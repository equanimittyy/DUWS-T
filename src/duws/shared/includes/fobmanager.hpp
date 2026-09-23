class fob_mng_dialog
{
	idd = -1;
	movingenable = true;
    //  onLoad = "_this call FRAME_01_Load";

    class controls
    {
        // GUI EDITOR OUTPUT START
        class background_request: RscText
        {
            idc = 9745;
            x = 4.5 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 30 * GUI_GRID_W;
            h = 7.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class mainframe_fobmanager: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_iggpsdqo"; //--- ToDo: Localize;
            x = 5 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 29 * GUI_GRID_W;
            h = 6.5 * GUI_GRID_H;
            moving = 1;
        };
        class fob_remove_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_naaz6hhb"; //--- ToDo: Localize;
            x = 5.5 * GUI_GRID_W + GUI_GRID_X;
            y = 9.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 28 * GUI_GRID_W;
            h = 3 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8w9xysfz"; //--- ToDo: Localize;
        };
        class remove_combo: RscCombo
        {
            idc = 2101;
            x = 19.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 13.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_ldug2wqc"; //--- ToDo: Localize;
        };
        class remove_button: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_bu7p5i48"; //--- ToDo: Localize;
            x = 6.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_cu8z4upb"; //--- ToDo: Localize;
            action = "[] spawn fnc_FOB_remove";
        };
        class exit_button: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_n66cx0eh"; //--- ToDo: Localize;
            x = 13.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_hq4mvl3z"; //--- ToDo: Localize;
            action = "closeDialog 0";
        };
        // GUI EDITOR OUTPUT END
    };
};