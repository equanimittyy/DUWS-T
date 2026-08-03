// The bottom of the faction screen, in a dialog of its own: client/dialog/fnc_HQ_faction_dialog.sqf
// builds that screen on an RscDisplayEmpty, which takes no keyboard focus, and the two buttons here
// are what the flow waits on.
//
// It carries no panel and no frame. The green box is the faction screen's and runs down past its own
// controls to enclose these; a second filled box stacked on the first read as two menus for one
// decision. A rule and a plain caption separate the placement question from the answers above it,
// which is the same header-and-rule the request menu uses instead of nesting boxes.
class startup_hq_placement_dialog
{
	idd = -1;
	movingenable = false;

    class controls
    {
        class hq_placement_divider: RscText
        {
            idc = 1444;
            x = 4 * GUI_GRID_W + GUI_GRID_X;
            y = 10.45 * GUI_GRID_H + GUI_GRID_Y;
            w = 32 * GUI_GRID_W;
            h = 0.0625 * GUI_GRID_H;
            colorBackground[] = {1,1,1,0.25};
        };
        class hq_placement_caption: RscText
        {
            idc = 1801;
            text = "$STR_DUWS_T_7tr969mm";
            style = ST_CENTER;
            sizeEx = 0.03;
            x = 4 * GUI_GRID_W + GUI_GRID_X;
            y = 10.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 32 * GUI_GRID_W;
            h = 0.85 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class hq_placement_random_button: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_2f55ngq1";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 11.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1.25 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_50n9sdxk";
            action = "[20, 0.015] remoteExec ['fnc_HQ_random_place',player1]; closedialog 0;";
        };
        class hq_placement_manual_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_x0cq7o5y";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1.25 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_qwfdr33k";
            action = "[] spawn fnc_HQ_manual_place; closedialog 0;";
        };
    };
};
