// ESC is eaten like every setup screen's: escaping this one would leave the server waiting on a question nobody
// can answer. idc block 9800-9811, above the FOB manager's 9745.
class duws_campaign_fork
{
    idd = -1;
    movingenable = false;
    onLoad = "uiNamespace setVariable ['DUWS_forkDisplay', _this select 0]; (_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";

    class ControlsBackground
    {
        class fork_background: RscText
        {
            idc = -1;
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 24.5 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
    };

    class controls
    {
        class fork_shade: RscText
        {
            idc = -1;
            x = -0.6 * GUI_GRID_W + GUI_GRID_X;
            y = 0 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 25.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class fork_frame: RscFrame
        {
            idc = 9800;
            text = "$STR_DUWS_T_fork_frame";
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 24.5 * GUI_GRID_H;
        };
        class fork_intro: RscText
        {
            idc = 9801;
            text = "$STR_DUWS_T_fork_intro";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class fork_list: RscListBox
        {
            idc = 9802;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 24 * GUI_GRID_W;
            h = 12.5 * GUI_GRID_H;
            onLBSelChanged = "[] call fnc_campaign_fork_select;";
        };
        class fork_detail: RscStructuredText
        {
            idc = 9803;
            x = 25.5 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 13.5 * GUI_GRID_W;
            h = 12.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class fork_paste_label: RscText
        {
            idc = 9804;
            text = "$STR_DUWS_T_fork_paste";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 16 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class fork_paste: RscEditMulti
        {
            idc = 9805;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 17 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 3.5 * GUI_GRID_H;
        };
        class fork_status: RscText
        {
            idc = 9806;
            text = "";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 20.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            colorText[] = {1, 0.6, 0.2, 1};
        };
        class fork_new: RscButton
        {
            idc = 9807;
            text = "$STR_DUWS_T_fork_new";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 22.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 7 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0, 0.5};
            tooltip = "$STR_DUWS_T_fork_new_tip";
            action = "['new'] spawn fnc_campaign_fork_action;";
        };
        class fork_load: fork_new
        {
            idc = 9808;
            text = "$STR_DUWS_T_fork_load";
            x = 8.75 * GUI_GRID_W + GUI_GRID_X;
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_fork_load_tip";
            action = "['load'] spawn fnc_campaign_fork_action;";
        };
        class fork_delete: fork_new
        {
            idc = 9809;
            text = "$STR_DUWS_T_fork_delete";
            x = 16.5 * GUI_GRID_W + GUI_GRID_X;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.3};
            tooltip = "$STR_DUWS_T_fork_delete_tip";
            action = "['delete'] spawn fnc_campaign_fork_action;";
        };
        class fork_import: fork_delete
        {
            idc = 9810;
            text = "$STR_DUWS_T_fork_import";
            x = 24.25 * GUI_GRID_W + GUI_GRID_X;
            tooltip = "$STR_DUWS_T_fork_import_tip";
            action = "['import'] spawn fnc_campaign_fork_action;";
        };
        class fork_export: fork_delete
        {
            idc = 9811;
            text = "$STR_DUWS_T_fork_export";
            x = 32 * GUI_GRID_W + GUI_GRID_X;
            tooltip = "$STR_DUWS_T_fork_export_tip";
            action = "['export'] spawn fnc_campaign_fork_action;";
        };
    };
};
