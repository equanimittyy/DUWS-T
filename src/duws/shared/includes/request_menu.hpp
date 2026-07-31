// The request menu, shared by the HQ and every FOB. fnc_request_menu fills it and hides the
// supports half at a FOB, where supports cannot be bought -- the FOB used to have a dialog of
// its own that was this one with three listbox IDCs renamed and a dead supports box.
//
// Laid out on the 40x25 GUI grid, near full screen: the supports list holds two dozen rows and
// the base list a dozen, and both were previously 2.5 grid cells tall -- three visible rows,
// scrolled blind.
class ressourceheader
{
    idd = -1;
    movingenable = true;

    class controls
    {
        class background_request: RscText
        {
            idc = 1769;
            x = -0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 1 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 23 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class mainframebackground: RscFrame
        {
            idc = 1800;
            moving = 1;
            text = "$STR_DUWS_T_ii4q52bc";
            x = 0 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };

        // --- Header: the three pools the rest of the menu spends, plus the map ---
        class RscFrame_1805: RscFrame
        {
            idc = 1805;
            text = "$STR_DUWS_T_rqfuzzt0";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 9 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_zsv1b4zp";
        };
        class RscText_1000: RscText
        {
            idc = 1000;
            text = "CP: XXX";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class RscFrame_1806: RscFrame
        {
            idc = 1806;
            text = "$STR_DUWS_T_dvt8byhj";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 9 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ibx2y3c";
        };
        class RscText_1001: RscText
        {
            idc = 1001;
            text = "ZUC:XXX";
            x = 10.5 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class ap_mainframe: RscFrame
        {
            idc = 1807;
            text = "$STR_DUWS_T_01aj6v4j";
            x = 19.5 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 9 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
        };
        class ap_text: RscText
        {
            idc = 1002;
            text = "000";
            x = 20 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
            colorText[] = {1,1,1,1};
        };
        class RscButton_1605: RscButton
        {
            idc = 1605;
            text = "$STR_DUWS_T_rplkhwfu";
            x = 29 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.5 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_stratmap; closeDialog 0";
            tooltip = "$STR_DUWS_T_k9t3ub5d";
        };

        // --- What command sends: one column per kind, each a picker over its button ---
        class requestunitframe: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_m8wc394w";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 4.5 * GUI_GRID_H;
        };
        class unitlistbox: RscCombo
        {
            idc = 2100;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestunitsbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_wulhhx81";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_request_unit";
            tooltip = "$STR_DUWS_T_1tik0eaw";
        };
        class requestsquadframe: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_kyrhidgf";
            x = 13.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 4.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class squadlist: RscCombo
        {
            idc = 2101;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestsquadbutton: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_wulhhx81";
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_request_squad";
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class emptyvehicleframe: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_uskdohql";
            x = 26.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 4.5 * GUI_GRID_H;
        };
        class emptyvehiclelist: RscCombo
        {
            idc = 2102;
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestvehiclebutton: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_wulhhx81";
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_hf8ph7ss";
            action = "[] spawn fnc_request_vehicle";
        };

        // --- The two lists: what can be unlocked, and what the base itself does ---
        class supportunlockframe: RscFrame
        {
            idc = 1804;
            text = "$STR_DUWS_T_x0l67g37";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 19 * GUI_GRID_W;
            h = 10 * GUI_GRID_H;
        };
        class supportunlocklist: RscListBox
        {
            idc = 2103;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 7.5 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class supportunlockbutton: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_bp73qs16";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 19.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_request_support";
            tooltip = "$STR_DUWS_T_dsl9rr00";
        };
        class basemenuframe: RscFrame
        {
            idc = 1808;
            text = "$STR_DUWS_T_BASE_MENU_TITLE";
            x = 20 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 19 * GUI_GRID_W;
            h = 10 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_BASE_MENU_TOOLTIP";
        };
        class basemenulist: RscListBox
        {
            idc = 2104;
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 7.5 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class basemenubutton: RscButton
        {
            idc = 1606;
            text = "$STR_DUWS_T_MENU_SELECT";
            x = 20.5 * GUI_GRID_W + GUI_GRID_X;
            y = 19.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_base_menu_select";
            tooltip = "$STR_DUWS_T_BASE_MENU_TOOLTIP";
        };

        // --- The two economy actions, then out ---
        class convertCPbutton: RscButton
        {
            idc = 1627;
            text = "$STR_DUWS_T_f62mxt4i";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 21 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_convertAPtoCP";
            tooltip = "$STR_DUWS_T_a72vvbgp";
        };
        class recruit_operative_button: RscButton
        {
            idc = 1347;
            text = "$STR_DUWS_T_0dlbonpc";
            x = 13.5 * GUI_GRID_W + GUI_GRID_X;
            y = 21 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_operator_open";
            tooltip = "$STR_DUWS_T_a2si05g7";
        };
        class exitbutton: RscButton
        {
            idc = 1604;
            text = "EXIT";
            x = 26.5 * GUI_GRID_W + GUI_GRID_X;
            y = 21 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "closeDialog 0";
        };
    };
};
