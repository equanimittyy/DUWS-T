class squad_mng_dialog
{
	idd = -1;
	movingenable = true;
    onLoad = "_this call fnc_taskforce_list";

    class controls
    {
        class background_request: RscText
        {
            idc = 1445;
            x = 2 * GUI_GRID_W + GUI_GRID_X;
            y = 2.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 36 * GUI_GRID_W;
            h = 20.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class squadmng_mainframe: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_akva0l14";
            x = 2.5 * GUI_GRID_W + GUI_GRID_X;
            y = 2.75 * GUI_GRID_H + GUI_GRID_Y;
            w = 35 * GUI_GRID_W;
            h = 19.5 * GUI_GRID_H;
            moving = 1;
        };
        class dismiss_frame: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_svkyfjme";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 3.75 * GUI_GRID_H + GUI_GRID_Y;
            w = 34 * GUI_GRID_W;
            h = 3.9 * GUI_GRID_H;
        };
        class dismissbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_zp8b22h7";
            sizeEx = 0.026;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 6.05 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ogmbeb1";
            action = "[] spawn fnc_dismiss_playerAI; closeDialog 0";
        };
        class dismiss_txt_info: RscText
        {
            idc = 1000;
            text = "$STR_DUWS_T_12zqt3fk";
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 4.45 * GUI_GRID_H + GUI_GRID_Y;
            w = 33 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
            sizeEx = 0.026;
        };
        class HCdismiss_frame: RscFrame
        {
            idc = 1802;
            text = "High Command squads";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 8.15 * GUI_GRID_H + GUI_GRID_Y;
            w = 34 * GUI_GRID_W;
            h = 3.9 * GUI_GRID_H;
        };
        class dismissHC_txt: RscText
        {
            idc = 1001;
            text = "$STR_DUWS_T_u4t2durf";
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 8.85 * GUI_GRID_H + GUI_GRID_Y;
            w = 33 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
            style = ST_MULTI;
            sizeEx = 0.026;
        };
        class dismissHC_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_HC_DISBAND";
            sizeEx = 0.026;
            x = 13.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.45 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.5 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_qe3lrwmf";
            action = "[] spawn fnc_dismissHC; closeDialog 0";
        };
        class renameHC_button: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_r4qmnp8o";
            sizeEx = 0.026;
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.45 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.5 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_r4qmnp8o";
            action = "closeDialog 0; _handle = createDialog 'squad_rename_dialog'";
        };
        class giveHC_button: RscButton
        {
            idc = 1604;
            text = "$STR_DUWS_T_TASKFORCE_GIVE";
            sizeEx = 0.026;
            x = 23.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.45 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_TASKFORCE_GIVE_TIP";
            action = "[] spawn fnc_giveHC; closeDialog 0";
        };
        class taskforce_frame: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_TASKFORCE_BOX";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 12.55 * GUI_GRID_H + GUI_GRID_Y;
            w = 34 * GUI_GRID_W;
            h = 7.5 * GUI_GRID_H;
        };
        class taskforce_col_name: RscText
        {
            text = "$STR_DUWS_T_TASKFORCE_COL_NAME";
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 7 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.026;
        };
        class taskforce_col_status: RscText
        {
            text = "$STR_DUWS_T_TASKFORCE_COL_STATUS";
            x = 10.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.026;
        };
        class taskforce_col_orders: RscText
        {
            text = "$STR_DUWS_T_TASKFORCE_COL_ORDERS";
            x = 23.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.026;
        };
        class taskforce_list_bg: RscText
        {
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 14.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 33 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
            colorBackground[] = {0,0,0,1};
        };
        class taskforce_list: RscControlsGroup
        {
            idc = 1700;
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 14.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 33 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
        };
        class taskforce_stance_button: RscButton
        {
            idc = 1605;
            sizeEx = 0.026;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 18.45 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_TASKFORCE_STANCE_TIP";
        };
        class leave_button: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_n66cx0eh";
            sizeEx = 0.026;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 20.55 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_bhlgx74f";
            action = "closeDialog 0";
        };
    };
};
