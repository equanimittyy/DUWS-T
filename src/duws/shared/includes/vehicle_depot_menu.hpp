// The unified vehicle depot dialog, filled by client/dialog/fnc_vehicle_depot_menu.sqf and refreshed
// by fnc_depot_menu_fill.sqf on the model of the REQUESTS menu (request_menu.hpp).
//
// A pad vehicle's netId and a stored vehicle's FLAT DUWS_garage_stored index ride in lbData, so an
// action reads the selection rather than a row position -- and Retrieve stays domain-agnostic though
// the stored rows are split across three lists. Capacity is bought in the REQUESTS menu, so no buy
// button lives here. CP (1000) and AP (1002) reuse the request menu's idcs so client_init's
// publicVariableEventHandlers update them live. Button actions carry literal idcs because the
// preprocessor does not expand #defines inside string literals.
class vehicledepotmenu
{
    idd = -1;
    movingenable = true;

    class controls
    {
        // Layered like the REQUESTS menu: faint outer panel under darker filled boxes, colours from
        // request_menu.hpp.
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

        class cpFrame: RscFrame
        {
            text = "$STR_DUWS_T_rqfuzzt0";
            sizeEx = 0.025;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 2.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.9 * GUI_GRID_H;
        };
        class cpValue: RscText
        {
            idc = 1000;
            text = "--";
            x = 1.4 * GUI_GRID_W + GUI_GRID_X;
            y = 2.85 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.2 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class apFrame: cpFrame
        {
            text = "$STR_DUWS_T_01aj6v4j";
            x = 7.3 * GUI_GRID_W + GUI_GRID_X;
        };
        class apValue: cpValue
        {
            idc = 1002;
            x = 7.7 * GUI_GRID_W + GUI_GRID_X;
        };

        // Left half: the Landing Pad box. Its modification toolbar sits inside, above the list; every
        // toolbar button acts on the selected Landing Pad row.
        class padFrame: RscFrame
        {
            idc = 2010;
            text = "$STR_DUWS_T_DEPOT_LANDING_PAD";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 16.9 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class toolRepair: RscButton
        {
            idc = 2012;
            sizeEx = 0.025;
            x = 1.3 * GUI_GRID_W + GUI_GRID_X;
            y = 5.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.8 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _n = lbData [2011, _i]; if (_n != '') then { [player, _n] remoteExec ['fnc_veh_repair_action', 2] } }";
        };
        class toolPylons: toolRepair
        {
            idc = 2015;
            x = 7.3 * GUI_GRID_W + GUI_GRID_X;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _v = objectFromNetId (lbData [2011, _i]); if (!isNull _v) then { closeDialog 0; [_v] call fnc_veh_pylons_dialog } }";
        };
        class toolAppearance: toolRepair
        {
            idc = 2014;
            x = 13.3 * GUI_GRID_W + GUI_GRID_X;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _v = objectFromNetId (lbData [2011, _i]); if (!isNull _v) then { closeDialog 0; [_v] call fnc_veh_appearance_dialog } }";
        };
        class padList: RscListBox
        {
            idc = 2011;
            x = 1.3 * GUI_GRID_W + GUI_GRID_X;
            y = 6.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.9 * GUI_GRID_W;
            h = 12.6 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class padCheckStatus: RscButton
        {
            idc = 2013;
            sizeEx = 0.025;
            x = 1.3 * GUI_GRID_W + GUI_GRID_X;
            y = 19.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _n = lbData [2011, _i]; if (_n != '') then { [player, _n] remoteExec ['fnc_veh_repair_check_status', 2] } }";
        };
        class padRecycle: padCheckStatus
        {
            idc = 2032;
            x = 10.3 * GUI_GRID_W + GUI_GRID_X;
            w = 8.9 * GUI_GRID_W;
            action = "[] spawn fnc_depot_recycle_confirm";
        };

        // Right half: the Garage box, mirroring the Landing Pad box. Three domain lists stack inside one
        // frame, one selection between them: each onLBSelChanged clears the other two and records its idc
        // as the active list for Retrieve. The -1 writes re-fire the handler, but the sel>=0 guard drops
        // them, so there is no recursion.
        class garageFrame: RscFrame
        {
            idc = 2020;
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 16.9 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class landHeader: RscText
        {
            idc = 2003;
            text = "";
            sizeEx = 0.025;
            x = 20.8 * GUI_GRID_W + GUI_GRID_X;
            y = 5.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.9 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class landList: RscListBox
        {
            idc = 2021;
            x = 20.8 * GUI_GRID_W + GUI_GRID_X;
            y = 6.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.9 * GUI_GRID_W;
            h = 3.4 * GUI_GRID_H;
            sizeEx = 0.025;
            onLBSelChanged = "params ['_c','_s']; if (_s >= 0) then { uiNamespace setVariable ['DUWS_depotMenu_activeGarage', ctrlIDC _c]; { if (_x != ctrlIDC _c) then { lbSetCurSel [_x, -1] } } forEach [2021,2022,2025] }";
        };
        class airHeader: landHeader
        {
            idc = 2004;
            y = 9.9 * GUI_GRID_H + GUI_GRID_Y;
        };
        class airList: landList
        {
            idc = 2022;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
        };
        class boatHeader: landHeader
        {
            idc = 2005;
            y = 14.7 * GUI_GRID_H + GUI_GRID_Y;
        };
        class boatList: landList
        {
            idc = 2025;
            y = 15.8 * GUI_GRID_H + GUI_GRID_Y;
        };

        // Store reads the selected Landing Pad row; the server routes it to its domain pool. Retrieve
        // reads whichever garage list is active.
        class garStore: RscButton
        {
            idc = 2023;
            sizeEx = 0.025;
            x = 20.8 * GUI_GRID_W + GUI_GRID_X;
            y = 19.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_GARAGE_STORE_TIP";
            action = "private _i = lbCurSel 2011; if (_i >= 0) then { private _n = lbData [2011, _i]; if (_n != '') then { [player, _n] remoteExec ['fnc_garage_store', 2] } }";
        };
        class garRetrieve: garStore
        {
            idc = 2024;
            x = 29.8 * GUI_GRID_W + GUI_GRID_X;
            w = 8.9 * GUI_GRID_W;
            tooltip = "";
            action = "private _g = uiNamespace getVariable ['DUWS_depotMenu_activeGarage', -1]; if (_g < 0) exitWith { hint localize 'STR_DUWS_T_GARAGE_NONE_SELECTED' }; private _i = lbCurSel _g; if (_i < 0) exitWith { hint localize 'STR_DUWS_T_GARAGE_NONE_SELECTED' }; private _d = lbData [_g, _i]; if (_d != '') then { [player, parseNumber _d, uiNamespace getVariable ['DUWS_depotMenu_ctx','']] remoteExec ['fnc_garage_retrieve', 2] }";
        };

        class exitbutton: RscButton
        {
            idc = 2099;
            text = "EXIT";
            sizeEx = 0.025;
            x = 33 * GUI_GRID_W + GUI_GRID_X;
            y = 22 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            action = "closeDialog 0";
        };
    };
};
