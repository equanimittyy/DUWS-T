// Vehicle drop requisition picker. One listbox of the motorised-or-lower hulls the faction's
// request list carries, filled by client/supports/fnc_veh_drop.sqf after the dialog opens (idd = -1,
// so the fill and the confirm reach the controls by idc). The confirm button stashes the selected
// class and a flag in globals the spawning script reads once the dialog closes -- an action string
// runs outside that script's scope and cannot hand a value back any other way. Escape or Close
// leaves the flag false, which the script treats as a cancel and hands the comm item back.
//
// idc block 8500-8599; nearest neighbours are civ_menu's 8300-8499 and fobmanager's 9745.
class veh_drop_dialog
{
    idd = -1;
    movingenable = true;

    class controls
    {
        class vd_background: RscText
        {
            idc = 8500;
            x = 9 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 22 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.7};
        };
        class vd_mainframe: RscFrame
        {
            idc = 8501;
            text = "$STR_DUWS_T_veh_drop_title";
            x = 9 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 22 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
            moving = 1;
        };
        class vd_list: RscListBox
        {
            idc = 8510;
            x = 9.6 * GUI_GRID_W + GUI_GRID_X;
            y = 4.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20.8 * GUI_GRID_W;
            h = 18 * GUI_GRID_H;
            sizeEx = 0.028;
        };
        class vd_confirm: RscButton
        {
            idc = 8520;
            text = "$STR_DUWS_T_veh_drop_confirm";
            x = 9.6 * GUI_GRID_W + GUI_GRID_X;
            y = 22.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            action = "private _s = lbCurSel 8510; if (_s < 0) exitWith { hint localize 'STR_DUWS_T_veh_drop_nosel' }; DUWS_vehdrop_pick = lbData [8510, _s]; DUWS_vehdrop_confirmed = true; closeDialog 0;";
        };
        class vd_close: RscButton
        {
            idc = 8521;
            text = "$STR_DUWS_T_MENU_CLOSE";
            x = 23 * GUI_GRID_W + GUI_GRID_X;
            y = 22.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 7.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
    };
};
