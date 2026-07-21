// TODO: Localize text in this file.
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
            y = 9 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 16.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class mainframebackground: RscFrame
        {
            idc = 1800;
            moving = 1;
            text = "$STR_DUWS_T_ii4q52bc";
            x = 0 * GUI_GRID_W + GUI_GRID_X;
            y = 9.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 15.5 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };
        class requestsquadframe: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_kyrhidgf";
            x = 13.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class emptyvehicleframe: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_uskdohql";
            x = 26.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
        };
        class supportunlockframe: RscFrame
        {
            idc = 1804;
            text = "$STR_DUWS_T_x0l67g37";
            x = 26.5 * GUI_GRID_W + GUI_GRID_X;
            y = 17.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 5.5 * GUI_GRID_H;
        };
        class requestunitframe: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_m8wc394w";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.5 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
        };
        class requestunitsbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_wulhhx81";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 15.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_request_unit";
            tooltip = "$STR_DUWS_T_1tik0eaw";
        };
        class requestsquadbutton: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_wulhhx81";
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 15.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_request_squad";
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class requestvehiclebutton: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_wulhhx81";
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 15.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_hf8ph7ss";
            action = "[] spawn fnc_request_vehicle";
        };
        class supportunlockbutton: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_bp73qs16";
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 21.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_request_support";
            tooltip = "$STR_DUWS_T_dsl9rr00";
        };
        class exitbutton: RscButton
        {
            idc = 1604;
            text = "EXIT";
            x = 16 * GUI_GRID_W + GUI_GRID_X;
            y = 23.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "closeDialog 0";
        };
        class RscText_1000: RscText
        {
            idc = 1000;
            text = "CP: XXX";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class RscText_1001: RscText
        {
            idc = 1001;
            text = "ZUC:XXX";
            x = 10.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class RscFrame_1805: RscFrame
        {
            idc = 1805;
            text = "$STR_DUWS_T_rqfuzzt0";
            x = 0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 9 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_zsv1b4zp";
        };
        class RscFrame_1806: RscFrame
        {
            idc = 1806;
            text = "$STR_DUWS_T_dvt8byhj";
            x = 10.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.5 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ibx2y3c";
        };
        class RscButton_1605: RscButton
        {
            idc = 1605;
            text = "$STR_DUWS_T_rplkhwfu";
            x = 28.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.5 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_stratmap; closeDialog 0";
            tooltip = "$STR_DUWS_T_k9t3ub5d";
        };
        class ap_mainframe: RscFrame
        {
            idc = 1807;
            text = "$STR_DUWS_T_01aj6v4j";
            x = 19.5 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.5 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
        };
        class ap_text: RscText
        {
            idc = 1002;
            text = "000";
            x = 19.5 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
            colorText[] = {1,1,1,1};
        };
        class unitlistbox: RscCombo
        {
            idc = 2100;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 14 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
                sizeEx = 0.025;
        };
        class squadlist: RscCombo
        {
            idc = 2101;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 14 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class emptyvehiclelist: RscCombo
        {
            idc = 2102;
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 14 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
                sizeEx = 0.025;
        };
        class supportunlocklist: RscListBox
        {
            idc = 2103;
            x = 27 * GUI_GRID_W + GUI_GRID_X;
            y = 18.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 2.5 * GUI_GRID_H;
                sizeEx = 0.025;
        };
        class convertCPbutton: RscButton
        {
            idc = 1627;
            text = "$STR_DUWS_T_f62mxt4i";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 20.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_convertAPtoCP";
            tooltip = "$STR_DUWS_T_a72vvbgp";
        };
        class recruit_operative_button: RscButton
        {
            idc = 1347;
            text = "$STR_DUWS_T_0dlbonpc";
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 18 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.5 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            action = "[] spawn fnc_operator_open";
            tooltip = "$STR_DUWS_T_a2si05g7";
        };
    };
};