// The unified vehicle depot dialog: one window with three panels -- Modification, Storage garage,
// Recycle -- filled imperatively by client/dialog/fnc_vehicle_depot_menu.sqf and refreshed by
// fnc_depot_menu_fill.sqf, on the model of the REQUESTS menu (request_menu.hpp / fnc_request_menu).
//
// Laid out on the 40x25 GUI grid from defines.hpp. Header readouts: CP (idc 1000) and AP (idc 1002)
// reuse the request menu's idcs so client_init's publicVariableEventHandlers update them live; the
// three garage pool readouts (2003/2004/2005) are set by the fill. Row identity rides in lbData -- a
// pad vehicle's netId, a stored vehicle's index -- so a button action reads the selection rather than
// a position. Capacity levels are bought from the REQUESTS menu, not here (fnc_supports_init.sqf).
// Button actions carry literal control idcs because the preprocessor does not expand #defines inside
// string literals.
class vehicledepotmenu
{
    idd = -1;
    movingenable = true;

    class controls
    {
        // The REQUESTS-menu layering: a faint outer panel with darker filled boxes on top (the header
        // strip and the three panels below), so the boxes read as raised over the ground rather than
        // the dialog being one flat black rectangle. Colours match request_menu.hpp -- 0.3 outer, 0.5
        // boxes -- so the two dialogs sit in the same visual family.
        class background_depot: RscText
        {
            idc = 2199;
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 0.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 39 * GUI_GRID_W;
            h = 23.4 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class titletext: RscText
        {
            idc = 2000;
            text = "$STR_DUWS_T_DEPOT_MENU";
            style = ST_CENTER;
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 1 * GUI_GRID_H + GUI_GRID_Y;
            w = 39 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
        };

        // --- Header readouts: CP, AP, and the three garage pools as used / total ---
        class headerFrame: RscFrame
        {
            x = 0.6 * GUI_GRID_W + GUI_GRID_X;
            y = 2.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 38.8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class cpLabel: RscText
        {
            text = "CP";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 2.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 1.6 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
        };
        class cpValue: RscText
        {
            idc = 1000;
            text = "--";
            x = 2.7 * GUI_GRID_W + GUI_GRID_X;
            y = 2.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
        };
        class apLabel: cpLabel
        {
            text = "AP";
            x = 7 * GUI_GRID_W + GUI_GRID_X;
        };
        class apValue: cpValue
        {
            idc = 1002;
            x = 8.7 * GUI_GRID_W + GUI_GRID_X;
        };
        class poolLand: RscText
        {
            idc = 2003;
            text = "";
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 2.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
        };
        class poolAir: poolLand
        {
            idc = 2004;
            x = 22.3 * GUI_GRID_W + GUI_GRID_X;
            w = 7 * GUI_GRID_W;
        };
        class poolBoat: poolLand
        {
            idc = 2005;
            x = 30 * GUI_GRID_W + GUI_GRID_X;
            w = 8.5 * GUI_GRID_W;
        };

        // --- Panel 1: Modification (the empty pad vehicles) ---
        class modFrame: RscFrame
        {
            idc = 2010;
            text = "$STR_DUWS_T_VEHICLE_CUSTOMIZATION";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 3.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 17.3 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class modList: RscListBox
        {
            idc = 2011;
            x = 1.3 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.4 * GUI_GRID_W;
            h = 11.5 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class modRepair: RscButton
        {
            idc = 2012;
            sizeEx = 0.025;
            x = 1.3 * GUI_GRID_W + GUI_GRID_X;
            y = 16.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.5 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _n = lbData [2011, _i]; if (_n != '') then { [player, _n] remoteExec ['fnc_veh_repair_action', 2] } }";
        };
        class modStatus: modRepair
        {
            idc = 2013;
            x = 7.2 * GUI_GRID_W + GUI_GRID_X;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _n = lbData [2011, _i]; if (_n != '') then { [player, _n] remoteExec ['fnc_veh_repair_check_status', 2] } }";
        };
        class modAppearance: modRepair
        {
            idc = 2014;
            y = 18.4 * GUI_GRID_H + GUI_GRID_Y;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _v = objectFromNetId (lbData [2011, _i]); if (!isNull _v) then { closeDialog 0; [_v] call fnc_veh_appearance_dialog } }";
        };
        class modPylons: modRepair
        {
            idc = 2015;
            x = 7.2 * GUI_GRID_W + GUI_GRID_X;
            y = 18.4 * GUI_GRID_H + GUI_GRID_Y;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _v = objectFromNetId (lbData [2011, _i]); if (!isNull _v) then { closeDialog 0; [_v] call fnc_veh_pylons_dialog } }";
        };

        // --- Panel 2: Storage garage (the stored vehicles; capacity is bought in the REQUESTS menu) ---
        class garFrame: RscFrame
        {
            idc = 2020;
            text = "$STR_DUWS_T_DEPOT_GARAGE";
            x = 13.7 * GUI_GRID_W + GUI_GRID_X;
            y = 3.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.6 * GUI_GRID_W;
            h = 17.3 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class garStoredList: RscListBox
        {
            idc = 2021;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12 * GUI_GRID_W;
            h = 11.5 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class garStore: RscButton
        {
            idc = 2023;
            sizeEx = 0.025;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 16.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.9 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_GARAGE_STORE_TIP";
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _n = lbData [2011, _i]; if (_n != '') then { [player, _n] remoteExec ['fnc_garage_store', 2] } }";
        };
        class garRetrieve: garStore
        {
            idc = 2024;
            x = 20.4 * GUI_GRID_W + GUI_GRID_X;
            tooltip = "";
            action = "private _i = lbCurSel 2021; if (_i >= 0) then { private _d = lbData [2021, _i]; if (_d != '') then { [player, parseNumber _d, uiNamespace getVariable ['DUWS_depotMenu_ctx','']] remoteExec ['fnc_garage_retrieve', 2] } }";
        };

        // --- Panel 3: Recycle (the empty pad vehicles and their reward) ---
        class recFrame: RscFrame
        {
            idc = 2030;
            text = "$STR_DUWS_T_VEHICLE_RECYCLING";
            x = 26.7 * GUI_GRID_W + GUI_GRID_X;
            y = 3.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.3 * GUI_GRID_W;
            h = 17.3 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class recList: RscListBox
        {
            idc = 2031;
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.7 * GUI_GRID_W;
            h = 11.5 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class recRecycle: RscButton
        {
            idc = 2032;
            sizeEx = 0.025;
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 16.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.7 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            action = "[] spawn fnc_depot_recycle_confirm";
        };

        class exitbutton: RscButton
        {
            idc = 2099;
            text = "EXIT";
            sizeEx = 0.025;
            x = 33 * GUI_GRID_W + GUI_GRID_X;
            y = 21.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "closeDialog 0";
        };
    };
};
