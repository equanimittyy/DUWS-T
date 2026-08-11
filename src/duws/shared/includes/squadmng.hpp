class squad_mng_dialog
{
	idd = -1;
	movingenable = true;
    //  onLoad = "_this call FRAME_01_Load";

    class controls
    {
        // GUI EDITOR OUTPUT START
        class background_request: RscText
        {
            idc = 1445;
            x = -0.46 * GUI_GRID_W + GUI_GRID_X;
            y = 7.52 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 18 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class squadmng_mainframe: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_akva0l14"; //--- ToDo: Localize;
            x = 0.04 * GUI_GRID_W + GUI_GRID_X;
            y = 8.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 17 * GUI_GRID_H;
            moving = 1;
        };
        class dismiss_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_svkyfjme"; //--- ToDo: Localize;
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 9 * GUI_GRID_H + GUI_GRID_Y;
            w = 39 * GUI_GRID_W;
            h = 5.5 * GUI_GRID_H;
        };
        class dismissbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_zp8b22h7"; //--- ToDo: Localize;
            x = 8.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 24.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ogmbeb1"; //--- ToDo: Localize;
            action = "[] spawn fnc_dismiss_playerAI; closeDialog 0";
        };
        class dismiss_txt_info: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_12zqt3fk"; //--- ToDo: Localize;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 10 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
            sizeEx = 0.03;
        };
        class HCdismiss_frame: RscFrame
        {
            idc = 1802;
            text = "High Command squads"; //--- ToDo: Localize;
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 15 * GUI_GRID_H + GUI_GRID_Y;
            w = 39 * GUI_GRID_W;
            h = 5.5 * GUI_GRID_H;
        };
        class dismissHC_txt: RscText
        {
            idc = 1001;
            text = "$STR_DUWS_T_u4t2durf"; //--- ToDo: Localize;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 16 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
            sizeEx = 0.03;
        };
        class dismissHC_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_qe3lrwmf"; //--- ToDo: Localize;
            x = 12.5 * GUI_GRID_W + GUI_GRID_X;
            y = 19 * GUI_GRID_H + GUI_GRID_Y;
            w = 24.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_qe3lrwmf"; //--- ToDo: Localize;
            action = "[] spawn fnc_dismissHC; closeDialog 0";
        };
        class renameHC_button: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_r4qmnp8o"; //--- ToDo: Localize;
            x = 2 * GUI_GRID_W + GUI_GRID_X;
            y = 19 * GUI_GRID_H + GUI_GRID_Y;
            w = 10 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_r4qmnp8o"; //--- ToDo: Localize;
            action = "closeDialog 0; _handle = createDialog 'squad_rename_dialog'";
        };
        class leave_button: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_n66cx0eh"; //--- ToDo: Localize;
            x = 25 * GUI_GRID_W + GUI_GRID_X;
            y = 22.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_bhlgx74f"; //--- ToDo: Localize;
            action = "closeDialog 0";
        };
        // GUI EDITOR OUTPUT END
    };
};