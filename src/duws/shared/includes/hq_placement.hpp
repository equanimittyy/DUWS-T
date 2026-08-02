class startup_hq_placement_dialog
{
	idd = -1;
	movingenable = false;

    class controls
    {
    // GUI EDITOR OUTPUT START
        // The same green every other setup screen's background carries, so the placement box reads
        // as part of the sequence rather than as a translucent panel dropped on the map.
        class background_request: RscText
        {
            idc = 1445;
            x = 9.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 21 * GUI_GRID_W;
            h = 9.5 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
        class hq_placement_frame: RscFrame
        {
            idc = 1800;
            text = "$STR_DUWS_T_7tr969mm"; //--- ToDo: Localize;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 8.5 * GUI_GRID_H;
        };
        class hq_placement_random_button: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_2f55ngq1"; //--- ToDo: Localize;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 12.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_50n9sdxk"; //--- ToDo: Localize;
            action = "[20, 0.015] remoteExec ['fnc_HQ_random_place',player1]; closedialog 0;";
            //action = "[20, 0.015] spawn fnc_HQ_random_place; closedialog 0;";
        };
        class hq_placement_manual_button: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_x0cq7o5y"; //--- ToDo: Localize;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 16 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_qwfdr33k"; //--- ToDo: Localize;
            action = "[] spawn fnc_HQ_manual_place; closedialog 0;";
        };
        // GUI EDITOR OUTPUT END
    };
};