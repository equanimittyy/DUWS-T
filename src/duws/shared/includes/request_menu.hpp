// The request dialog, shared by the HQ and every FOB. fnc_request_menu fills it and hides the
// SUPPORTS strip at a FOB, where supports cannot be bought -- the FOB used to have a dialog of
// its own that was this one with three listbox IDCs renamed and a dead supports box.
//
// Laid out on the 40x25 GUI grid as a main window with a strip appended right. The window holds
// MISSIONS over COMMAND AND CONTROL, with the exit inside it. The strip is the supports catalogue,
// two dozen rows needing the full height rather than being scrolled blind.
//
// The grid is absolute -- 40 cells is the whole screen width -- so widening the strip is taken out
// of the main window rather than added on the right, where there is nothing left.
//
// The two categories are a header and a rule rather than boxes. A box around each drew three nested
// frames on the same content (window, category, group) and spent the vertical room the left column
// needed; the header still names the category and the rule still separates them.
//
// Every button is 1.5 grid cells tall; sizes used to run 1 or 1.5 by whichever pass added them.
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
            w = 24.5 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };

        // --- MISSIONS: the three pools, what converts between them, and where work comes from ---
        class missionsheader: RscText
        {
            idc = 1808;
            text = "$STR_DUWS_T_REQ_MISSIONS";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 2.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 23 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        // The three pool captions are the longest text in the dialog and the frames carrying them
        // are the narrowest controls, so they set their own size rather than inheriting RscFrame's.
        // "Zones under control" is what forced it: at the default it was clipped to nothing and
        // read as a figure with no label at all.
        class RscFrame_1805: RscFrame
        {
            idc = 1805;
            text = "$STR_DUWS_T_rqfuzzt0";
            sizeEx = 0.024;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 3.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 7.4 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_zsv1b4zp";
        };
        class RscText_1000: RscText
        {
            idc = 1000;
            text = "CP: XXX";
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 3.65 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class ap_mainframe: RscFrame
        {
            idc = 1807;
            text = "$STR_DUWS_T_01aj6v4j";
            sizeEx = 0.024;
            x = 8.6 * GUI_GRID_W + GUI_GRID_X;
            y = 3.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 7.4 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
        };
        class ap_text: RscText
        {
            idc = 1002;
            text = "000";
            x = 9 * GUI_GRID_W + GUI_GRID_X;
            y = 3.65 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
            colorText[] = {1,1,1,1};
        };
        class RscFrame_1806: RscFrame
        {
            idc = 1806;
            text = "$STR_DUWS_T_dvt8byhj";
            sizeEx = 0.024;
            x = 16.4 * GUI_GRID_W + GUI_GRID_X;
            y = 3.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 7.4 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ibx2y3c";
        };
        class RscText_1001: RscText
        {
            idc = 1001;
            text = "ZUC:XXX";
            x = 16.8 * GUI_GRID_W + GUI_GRID_X;
            y = 3.65 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        // Four across the second row: the convert button belongs beside what it converts, and View
        // Map came off the HQ board to sit beside the other two things that answer "what now".
        class sidemissionbutton: RscButton
        {
            idc = 1605;
            text = "$STR_DUWS_T_rplkhwfu";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            // The one entry that still closes the menu: it hands the screen to the strategic map,
            // which a dialog would draw straight over.
            action = "closeDialog 0; [] spawn fnc_stratmap";
            tooltip = "$STR_DUWS_T_k9t3ub5d";
        };
        // Game Master only; fnc_request_menu owns that test.
        class missiontimersbutton: RscButton
        {
            idc = 1607;
            text = "$STR_DUWS_T_SHOW_MISSION_COOLDOWNS";
            x = 6.6 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_mission_cooldowns_show";
            tooltip = "$STR_DUWS_T_SHOW_MISSION_COOLDOWNS";
        };
        class viewmapbutton: RscButton
        {
            idc = 1608;
            text = "$STR_DUWS_T_civ_mapview_action";
            x = 12.4 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_map_view";
            tooltip = "$STR_DUWS_T_civ_mapview_action";
        };
        class convertCPbutton: RscButton
        {
            idc = 1627;
            text = "$STR_DUWS_T_f62mxt4i";
            x = 18.2 * GUI_GRID_W + GUI_GRID_X;
            y = 5.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_convertAPtoCP";
            tooltip = "$STR_DUWS_T_a72vvbgp";
        };

        // --- COMMAND AND CONTROL: what command sends on the left, what it administers on the right
        // The right column is slots, not fixed entries: fnc_command_fill writes the applicable ones
        // in from the top and hides the rest, so an inapplicable entry leaves no gap.
        class categorydivider: RscText
        {
            idc = 1810;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 7.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 23 * GUI_GRID_W;
            h = 0.06 * GUI_GRID_H;
            colorBackground[] = {1,1,1,0.25};
        };
        class commandheader: RscText
        {
            idc = 1809;
            text = "$STR_DUWS_T_REQ_COMMAND";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 7.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 23 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class requestunitframe: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_m8wc394w";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 8.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.2 * GUI_GRID_W;
            h = 4.1 * GUI_GRID_H;
        };
        class unitlistbox: RscCombo
        {
            idc = 2100;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 9.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.4 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestunitsbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_wulhhx81";
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 11.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_unit";
            tooltip = "$STR_DUWS_T_1tik0eaw";
        };
        class requestsquadframe: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_kyrhidgf";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 13.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.2 * GUI_GRID_W;
            h = 4.1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class squadlist: RscCombo
        {
            idc = 2101;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 14.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.4 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestsquadbutton: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_wulhhx81";
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 15.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_squad";
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class emptyvehicleframe: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_uskdohql";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 17.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.2 * GUI_GRID_W;
            h = 4.1 * GUI_GRID_H;
        };
        class emptyvehiclelist: RscCombo
        {
            idc = 2102;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 18.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.4 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestvehiclebutton: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_wulhhx81";
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 20.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 10.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_hf8ph7ss";
            action = "[] spawn fnc_request_vehicle";
        };

        class commandslot0: RscButton
        {
            idc = 1610;
            text = "";
            x = 12.6 * GUI_GRID_W + GUI_GRID_X;
            y = 8.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 11.2 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[0] spawn fnc_command_select";
        };
        class commandslot1: commandslot0
        {
            idc = 1611;
            y = 10.8 * GUI_GRID_H + GUI_GRID_Y;
            action = "[1] spawn fnc_command_select";
        };
        class commandslot2: commandslot0
        {
            idc = 1612;
            y = 12.7 * GUI_GRID_H + GUI_GRID_Y;
            action = "[2] spawn fnc_command_select";
        };
        class commandslot3: commandslot0
        {
            idc = 1613;
            y = 14.6 * GUI_GRID_H + GUI_GRID_Y;
            action = "[3] spawn fnc_command_select";
        };
        class commandslot4: commandslot0
        {
            idc = 1614;
            y = 16.5 * GUI_GRID_H + GUI_GRID_Y;
            action = "[4] spawn fnc_command_select";
        };
        class commandslot5: commandslot0
        {
            idc = 1615;
            y = 18.4 * GUI_GRID_H + GUI_GRID_Y;
            action = "[5] spawn fnc_command_select";
        };
        class commandslot6: commandslot0
        {
            idc = 1616;
            y = 20.3 * GUI_GRID_H + GUI_GRID_Y;
            action = "[6] spawn fnc_command_select";
        };

        // Inside the main window, not under the strip, which owns none of the window's chrome.
        class exitbutton: RscButton
        {
            idc = 1604;
            text = "EXIT";
            x = 18.2 * GUI_GRID_W + GUI_GRID_X;
            y = 21.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "closeDialog 0";
        };

        // --- SUPPORTS: the catalogue, appended down the right-hand side ---
        // Widened out of the main window rather than rightward: a row reads "Supply Drop (5CP)
        // Radio" and gains an escalation surcharge on top of that, which the old width cut in half.
        class supportunlockframe: RscFrame
        {
            idc = 1804;
            text = "$STR_DUWS_T_x0l67g37";
            x = 25 * GUI_GRID_W + GUI_GRID_X;
            y = 1.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 14.7 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
        };
        class supportunlocklist: RscListBox
        {
            idc = 2103;
            x = 25.4 * GUI_GRID_W + GUI_GRID_X;
            y = 2.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 13.9 * GUI_GRID_W;
            h = 18.5 * GUI_GRID_H;
            sizeEx = 0.025;
            // The button below both buys and refunds, so its label follows the selection.
            onLBSelChanged = "_this call fnc_support_sel_changed";
        };
        class supportunlockbutton: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_bp73qs16";
            x = 25.4 * GUI_GRID_W + GUI_GRID_X;
            y = 21.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 13.9 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_support";
            tooltip = "$STR_DUWS_T_dsl9rr00";
        };
    };
};
