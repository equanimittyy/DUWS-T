// Disguise panel: a single entry point in front of the two disguise modes.
// Squad-Manager idiom (framed cards + buttons), not the listbox "action menu":
// the two modes each carry distinct state, so two cards read better than two rows.
// Activate buttons remoteExec the unchanged fnc_disguiseAsCivilian / fnc_disguiseAsEnemy;
// the status line (idc 8100) and the civ-card gating are filled on open by fnc_disguise_menu.
class disguise_dialog
{
    idd = -1;
    movingenable = true;

    class controls
    {
        class disguise_background: RscText
        {
            idc = 8000;
            x = 5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 30 * GUI_GRID_W;
            h = 15 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.7};
        };
        class disguise_mainframe: RscFrame
        {
            idc = 8001;
            text = "$STR_DUWS_T_DISGUISE_MENU_TITLE";
            x = 5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 30 * GUI_GRID_W;
            h = 15 * GUI_GRID_H;
            moving = 1;
        };
        class disguise_status: RscText
        {
            idc = 8100;
            text = "$STR_DUWS_T_DISGUISE_MENU_STATUS_NONE";
            x = 6 * GUI_GRID_W + GUI_GRID_X;
            y = 6.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 28 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            style = ST_CENTER;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };

        class disguise_civ_frame: RscFrame
        {
            idc = 8002;
            text = "$STR_DUWS_T_DISGUISE_MENU_CIV_TITLE";
            x = 6 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 9 * GUI_GRID_H;
        };
        class disguise_civ_desc: RscText
        {
            idc = 8101;
            text = "$STR_DUWS_T_DISGUISE_MENU_CIV_DESC";
            x = 6.6 * GUI_GRID_W + GUI_GRID_X;
            y = 9 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.8 * GUI_GRID_W;
            h = 4.6 * GUI_GRID_H;
            style = ST_MULTI;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.032;
        };
        class disguise_civ_cooldown: RscText
        {
            idc = 8102;
            x = 6.6 * GUI_GRID_W + GUI_GRID_X;
            y = 13.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.8 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            style = ST_CENTER;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.033;
        };
        class disguise_civ_activate: RscButton
        {
            idc = 8201;
            text = "$STR_DUWS_T_DISGUISE_MENU_ACTIVATE";
            x = 7 * GUI_GRID_W + GUI_GRID_X;
            y = 15.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 11 * GUI_GRID_W;
            h = 1.3 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_DISGUISE_MENU_CIV_DESC";
            action = "closeDialog 0; [player] remoteExec ['fnc_disguiseAsCivilian', 2];";
        };

        class disguise_enemy_frame: RscFrame
        {
            idc = 8003;
            text = "$STR_DUWS_T_DISGUISE_MENU_ENEMY_TITLE";
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 9 * GUI_GRID_H;
        };
        class disguise_enemy_desc: RscText
        {
            idc = 8104;
            text = "$STR_DUWS_T_DISGUISE_MENU_ENEMY_DESC";
            x = 21.6 * GUI_GRID_W + GUI_GRID_X;
            y = 9 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.8 * GUI_GRID_W;
            h = 4.6 * GUI_GRID_H;
            style = ST_MULTI;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.032;
        };
        class disguise_enemy_cooldown: RscText
        {
            idc = 8105;
            x = 21.6 * GUI_GRID_W + GUI_GRID_X;
            y = 13.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.8 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            style = ST_CENTER;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.033;
        };
        class disguise_enemy_activate: RscButton
        {
            idc = 8202;
            text = "$STR_DUWS_T_DISGUISE_MENU_ACTIVATE";
            x = 22 * GUI_GRID_W + GUI_GRID_X;
            y = 15.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 11 * GUI_GRID_W;
            h = 1.3 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_DISGUISE_MENU_ENEMY_DESC";
            action = "closeDialog 0; [player] remoteExec ['fnc_disguiseAsEnemy', 2];";
        };

        class disguise_close: RscButton
        {
            idc = 8203;
            text = "$STR_DUWS_T_MENU_CLOSE";
            x = 13 * GUI_GRID_W + GUI_GRID_X;
            y = 18 * GUI_GRID_H + GUI_GRID_Y;
            w = 14 * GUI_GRID_W;
            h = 1.3 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
    };
};
