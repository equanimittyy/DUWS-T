class squad_mng_dialog
{
	idd = -1;
	movingenable = true;
    onLoad = "_this call fnc_taskforce_list";

    class controls
    {
        // GUI EDITOR OUTPUT START
        class background_request: RscText
        {
            idc = 1445;
            x = -0.46 * GUI_GRID_W + GUI_GRID_X;
            y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 29 * GUI_GRID_W;
            h = 24.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class squadmng_mainframe: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_akva0l14"; //--- ToDo: Localize;
            x = 0.04 * GUI_GRID_W + GUI_GRID_X;
            y = 0.52 * GUI_GRID_H + GUI_GRID_Y;
            w = 28 * GUI_GRID_W;
            h = 23.5 * GUI_GRID_H;
            moving = 1;
        };
        class dismiss_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_svkyfjme"; //--- ToDo: Localize;
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 27 * GUI_GRID_W;
            h = 5.5 * GUI_GRID_H;
        };
        class dismissbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_zp8b22h7"; //--- ToDo: Localize;
            sizeEx = 0.025;
            x = 8 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
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
            y = 2.2 * GUI_GRID_H + GUI_GRID_Y;
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
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 27 * GUI_GRID_W;
            h = 7.3 * GUI_GRID_H;
        };
        class dismissHC_txt: RscText
        {
            idc = 1001;
            text = "$STR_DUWS_T_u4t2durf"; //--- ToDo: Localize;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 8.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 26 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
            sizeEx = 0.03;
        };
        class dismissHC_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_HC_DISBAND";
            sizeEx = 0.025;
            x = 14.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
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
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_r4qmnp8o"; //--- ToDo: Localize;
            action = "closeDialog 0; _handle = createDialog 'squad_rename_dialog'";
        };
        class giveHC_button: RscButton
        {
            idc = 1604;
            text = "$STR_DUWS_T_TASKFORCE_GIVE";
            sizeEx = 0.025;
            x = 8 * GUI_GRID_W + GUI_GRID_X;
            y = 12.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_TASKFORCE_GIVE_TIP";
            action = "[] spawn fnc_giveHC; closeDialog 0";
        };
        class taskforce_frame: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_TASKFORCE_BOX";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 15.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 27 * GUI_GRID_W;
            h = 6.2 * GUI_GRID_H;
        };
        class taskforce_col_name: RscText
        {
            text = "$STR_DUWS_T_TASKFORCE_COL_NAME";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 16 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.026;
        };
        class taskforce_col_status: RscText
        {
            text = "$STR_DUWS_T_TASKFORCE_COL_STATUS";
            x = 7.5 * GUI_GRID_W + GUI_GRID_X;
            y = 16 * GUI_GRID_H + GUI_GRID_Y;
            w = 9 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.026;
        };
        class taskforce_col_orders: RscText
        {
            text = "$STR_DUWS_T_TASKFORCE_COL_ORDERS";
            x = 16.5 * GUI_GRID_W + GUI_GRID_X;
            y = 16 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.026;
        };
        class taskforce_list: RscControlsGroup
        {
            idc = 1700;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 17 * GUI_GRID_H + GUI_GRID_Y;
            w = 26 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
        };
        class leave_button: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_n66cx0eh"; //--- ToDo: Localize;
            sizeEx = 0.025;
            x = 8 * GUI_GRID_W + GUI_GRID_X;
            y = 22.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_bhlgx74f"; //--- ToDo: Localize;
            action = "closeDialog 0";
        };
        // GUI EDITOR OUTPUT END
    };
};
