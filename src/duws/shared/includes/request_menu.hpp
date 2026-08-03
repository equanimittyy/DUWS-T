// The request dialog, shared by the HQ and every FOB. fnc_request_menu fills it and hides the
// SUPPORTS strip at a FOB, where supports cannot be bought -- the FOB used to have a dialog of
// its own that was this one with three listbox IDCs renamed and a dead supports box.
//
// Laid out on the 40x25 GUI grid as a main window with the supports strip appended right, and one
// blank row under both carrying the exit. The window holds MISSIONS over COMMAND AND CONTROL; the
// strip is the supports catalogue, two dozen rows needing the full height rather than being
// scrolled blind.
//
// The grid is absolute -- 40 cells is the whole screen width -- so the strip's width comes out of
// the main window rather than being added on the right, where there is nothing left. At this split
// the window's floor is its COMMAND AND CONTROL row, a request frame beside a command button that
// cannot stack. A strip wider than this one means dropping labels, so past here supports leave the
// dialog for a screen of their own.
//
// Every button, combo, caption and list row carries sizeEx 0.025, and a control is as wide as its
// own label needs rather than an even share of its row. The two go together: one text size across
// the dialog is only affordable because nothing has to shrink to fit a share it never earned.
// Sizes set per row drifted apart by whichever pass last touched the row, and the dialog read as
// three different menus stacked together.
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
            y = 0.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 23.4 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class mainframebackground: RscFrame
        {
            idc = 1800;
            moving = 1;
            text = "$STR_DUWS_T_ii4q52bc";
            x = 0 * GUI_GRID_W + GUI_GRID_X;
            y = 1.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 21.5 * GUI_GRID_W;
            h = 20.9 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.5};
        };

        // --- MISSIONS: the three pools, what converts between them, and where work comes from ---
        class missionsheader: RscText
        {
            idc = 1808;
            text = "$STR_DUWS_T_REQ_MISSIONS";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 1.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        // Three unequal frames rather than three sixths of the row. "Zones under control" is
        // nineteen characters against "Army Power"'s ten, so an even split sets the dialog's text
        // size from the longest caption in it and shrinks the other two to suit -- which is how
        // this row came to be the one place carrying smaller text than everything around it.
        class RscFrame_1805: RscFrame
        {
            idc = 1805;
            text = "$STR_DUWS_T_rqfuzzt0";
            sizeEx = 0.025;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 2.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.9 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_zsv1b4zp";
        };
        class RscText_1000: RscText
        {
            idc = 1000;
            text = "CP: XXX";
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 3.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.2 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class ap_mainframe: RscFrame
        {
            idc = 1807;
            text = "$STR_DUWS_T_01aj6v4j";
            sizeEx = 0.025;
            x = 7.15 * GUI_GRID_W + GUI_GRID_X;
            y = 2.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 4.6 * GUI_GRID_W;
            h = 1.9 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
        };
        class ap_text: RscText
        {
            idc = 1002;
            text = "000";
            x = 7.55 * GUI_GRID_W + GUI_GRID_X;
            y = 3.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 3.8 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_23shv5yr";
            colorText[] = {1,1,1,1};
        };
        class RscFrame_1806: RscFrame
        {
            idc = 1806;
            text = "$STR_DUWS_T_dvt8byhj";
            sizeEx = 0.025;
            x = 12.1 * GUI_GRID_W + GUI_GRID_X;
            y = 2.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.6 * GUI_GRID_W;
            h = 1.9 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_8ibx2y3c";
        };
        class RscText_1001: RscText
        {
            idc = 1001;
            text = "ZUC:XXX";
            x = 12.5 * GUI_GRID_W + GUI_GRID_X;
            y = 3.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 7.8 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        // Four across a 19.9-cell row, each sized to its own label rather than to a quarter share:
        // evenly divided, "Mission Timers" alone overruns its share. The conversion rate moved off
        // the convert button and into the confirmation it now raises, because the label carrying it
        // was 24 characters and the row cannot seat a fourth button beside it. Mission Timers is
        // Game Master only and is hidden rather than written in from a list, so a player without
        // the gate sees a gap here.
        class sidemissionbutton: RscButton
        {
            idc = 1605;
            text = "$STR_DUWS_T_rplkhwfu";
            sizeEx = 0.025;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.4 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            // The one entry that still closes the menu: it hands the screen to the strategic map,
            // which a dialog would draw straight over.
            action = "closeDialog 0; [] spawn fnc_stratmap";
            tooltip = "$STR_DUWS_T_k9t3ub5d";
        };
        class missiontimersbutton: RscButton
        {
            idc = 1609;
            text = "$STR_DUWS_T_SHOW_MISSION_COOLDOWNS";
            sizeEx = 0.025;
            x = 6.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.7 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_mission_cooldowns_show";
            tooltip = "$STR_DUWS_T_SHOW_MISSION_COOLDOWNS";
        };
        class viewmapbutton: RscButton
        {
            idc = 1608;
            text = "$STR_DUWS_T_civ_mapview_action";
            sizeEx = 0.025;
            x = 12.5 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 3.6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_map_view";
            tooltip = "$STR_DUWS_T_civ_mapview_action";
        };
        class convertCPbutton: RscButton
        {
            idc = 1627;
            text = "$STR_DUWS_T_convert_ap";
            sizeEx = 0.025;
            x = 16.4 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4.3 * GUI_GRID_W;
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
            y = 6.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 0.06 * GUI_GRID_H;
            colorBackground[] = {1,1,1,0.25};
        };
        class commandheader: RscText
        {
            idc = 1809;
            text = "$STR_DUWS_T_REQ_COMMAND";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 7.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class requestunitframe: RscFrame
        {
            idc = 1801;
            text = "$STR_DUWS_T_m8wc394w";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 8.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.6 * GUI_GRID_W;
            h = 4.1 * GUI_GRID_H;
        };
        class unitlistbox: RscCombo
        {
            idc = 2100;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 9.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestunitsbutton: RscButton
        {
            idc = 1600;
            text = "$STR_DUWS_T_wulhhx81";
            sizeEx = 0.025;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 10.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_unit";
            tooltip = "$STR_DUWS_T_1tik0eaw";
        };
        class requestsquadframe: RscFrame
        {
            idc = 1802;
            text = "$STR_DUWS_T_kyrhidgf";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 12.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.6 * GUI_GRID_W;
            h = 4.1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class squadlist: RscCombo
        {
            idc = 2101;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 13.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestsquadbutton: RscButton
        {
            idc = 1601;
            text = "$STR_DUWS_T_wulhhx81";
            sizeEx = 0.025;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 15.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_squad";
            tooltip = "$STR_DUWS_T_3fvc6hv1";
        };
        class emptyvehicleframe: RscFrame
        {
            idc = 1803;
            text = "$STR_DUWS_T_uskdohql";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 17.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.6 * GUI_GRID_W;
            h = 4.1 * GUI_GRID_H;
        };
        class emptyvehiclelist: RscCombo
        {
            idc = 2102;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 18.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class requestvehiclebutton: RscButton
        {
            idc = 1602;
            text = "$STR_DUWS_T_wulhhx81";
            sizeEx = 0.025;
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 19.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_hf8ph7ss";
            action = "[] spawn fnc_request_vehicle";
        };

        // Seven slots, which is what the applicable entries come to at the HQ for a squad lead.
        class commandslot0: RscButton
        {
            idc = 1610;
            text = "";
            sizeEx = 0.025;
            x = 10.8 * GUI_GRID_W + GUI_GRID_X;
            y = 8.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 9.9 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[0] spawn fnc_command_select";
        };
        class commandslot1: commandslot0
        {
            idc = 1611;
            y = 10.05 * GUI_GRID_H + GUI_GRID_Y;
            action = "[1] spawn fnc_command_select";
        };
        class commandslot2: commandslot0
        {
            idc = 1612;
            y = 11.9 * GUI_GRID_H + GUI_GRID_Y;
            action = "[2] spawn fnc_command_select";
        };
        class commandslot3: commandslot0
        {
            idc = 1613;
            y = 13.75 * GUI_GRID_H + GUI_GRID_Y;
            action = "[3] spawn fnc_command_select";
        };
        class commandslot4: commandslot0
        {
            idc = 1614;
            y = 15.6 * GUI_GRID_H + GUI_GRID_Y;
            action = "[4] spawn fnc_command_select";
        };
        class commandslot5: commandslot0
        {
            idc = 1615;
            y = 17.45 * GUI_GRID_H + GUI_GRID_Y;
            action = "[5] spawn fnc_command_select";
        };
        class commandslot6: commandslot0
        {
            idc = 1616;
            y = 19.3 * GUI_GRID_H + GUI_GRID_Y;
            action = "[6] spawn fnc_command_select";
        };

        // Its own row under both boxes, at the right-hand end of the dialog rather than inside
        // either of them: neither the window nor the strip owns leaving the dialog.
        class exitbutton: RscButton
        {
            idc = 1604;
            text = "EXIT";
            sizeEx = 0.025;
            x = 34.1 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "closeDialog 0";
        };

        // --- SUPPORTS: the catalogue, appended down the right-hand side ---
        // The listbox is as wide as its widest line, on the rule the rest of the dialog follows.
        // That line is the permanent category heading rather than any support, and a line over the
        // width is silently cut rather than wrapped: its 42 characters at sizeEx 0.025 want the
        // 17.3 cells below, which is the whole inside of the frame. Anything longer added to
        // `fnc_support_list_fill` has nowhere left to go here.
        class supportunlockframe: RscFrame
        {
            idc = 1804;
            text = "$STR_DUWS_T_x0l67g37";
            x = 22 * GUI_GRID_W + GUI_GRID_X;
            y = 1.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.7 * GUI_GRID_W;
            h = 20.9 * GUI_GRID_H;
        };
        class supportunlocklist: RscListBox
        {
            idc = 2103;
            x = 22.2 * GUI_GRID_W + GUI_GRID_X;
            y = 2.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.3 * GUI_GRID_W;
            h = 18 * GUI_GRID_H;
            sizeEx = 0.025;
            // The button below both buys and refunds, so its label follows the selection.
            onLBSelChanged = "_this call fnc_support_sel_changed";
        };
        class supportunlockbutton: RscButton
        {
            idc = 1603;
            text = "$STR_DUWS_T_bp73qs16";
            sizeEx = 0.025;
            x = 22.2 * GUI_GRID_W + GUI_GRID_X;
            y = 20.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.3 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "[] spawn fnc_request_support";
            tooltip = "$STR_DUWS_T_dsl9rr00";
        };
    };
};
