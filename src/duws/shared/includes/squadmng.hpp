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
            w = 29 * GUI_GRID_W;
            h = 16 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class squadmng_mainframe: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_akva0l14"; //--- ToDo: Localize;
            x = 0.04 * GUI_GRID_W + GUI_GRID_X;
            y = 8.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 28 * GUI_GRID_W;
            h = 15 * GUI_GRID_H;
            moving = 1;
        };
        class dismiss_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_svkyfjme"; //--- ToDo: Localize;
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 9 * GUI_GRID_H + GUI_GRID_Y;
            w = 27 * GUI_GRID_W;
            h = 5.5 * GUI_GRID_H;
        };
        class dismissbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_zp8b22h7"; //--- ToDo: Localize;
            sizeEx = 0.025;
            x = 8 * GUI_GRID_W + GUI_GRID_X;
            y = 12.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ogmbeb1"; //--- ToDo: Localize;
            action = "[] spawn fnc_dismiss_playerAI; closeDialog 0";
        };
        class dismiss_txt_info: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_12zqt3fk"; //--- ToDo: Localize;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 9.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 26 * GUI_GRID_W;
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
            w = 27 * GUI_GRID_W;
            h = 5.5 * GUI_GRID_H;
        };
        class dismissHC_txt: RscText
        {
            idc = 1001;
            text = "$STR_DUWS_T_u4t2durf"; //--- ToDo: Localize;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 15.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 26 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
            sizeEx = 0.03;
        };
        class dismissHC_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_qe3lrwmf"; //--- ToDo: Localize;
            sizeEx = 0.025;
            x = 14.5 * GUI_GRID_W + GUI_GRID_X;
            y = 18.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_qe3lrwmf"; //--- ToDo: Localize;
            action = "[] spawn fnc_dismissHC; closeDialog 0";
        };
        class renameHC_button: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_r4qmnp8o"; //--- ToDo: Localize;
            sizeEx = 0.025;
            x = 1.5 * GUI_GRID_W + GUI_GRID_X;
            y = 18.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_r4qmnp8o"; //--- ToDo: Localize;
            action = "closeDialog 0; _handle = createDialog 'squad_rename_dialog'";
        };
        class leave_button: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_n66cx0eh"; //--- ToDo: Localize;
            sizeEx = 0.025;
            x = 8 * GUI_GRID_W + GUI_GRID_X;
            y = 21.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_bhlgx74f"; //--- ToDo: Localize;
            action = "closeDialog 0";
        };
        // GUI EDITOR OUTPUT END
    };
};
