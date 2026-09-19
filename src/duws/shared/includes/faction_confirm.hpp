// Faction confirmation screen and its key editor. The rows are built from script
// (client/dialog/fnc_faction_confirm.sqf) because both sides' key lists come from fnc_faction_schema
// at runtime; what is declared here is the chrome they sit in.
//
// The two prompts are overlay controls on this dialog rather than dialogs of their own: stacking a
// second dialog over this one to ask a yes/no would put the row buttons behind a modal still live
// to the mouse. They are declared last so they draw over the table, and start hidden.

class startup_faction_confirm
{
    idd = -1;
    movingenable = false;
    // Stashed for the row builder, which needs the display handle to create controls into the
    // group. ESC is disabled the way every other setup screen disables it.
    onLoad = "uiNamespace setVariable ['duws_faction_confirm_display', _this select 0]; (_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";

    class ControlsBackground
    {
        class background: RscText
        {
            idc = -1;
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 28 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
    };

    class controls
    {
        class background_request: RscText
        {
            idc = 8601;
            x = -0.6 * GUI_GRID_W + GUI_GRID_X;
            y = -0.48 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 29 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class confirm_mainframe: RscFrame
        {
            idc = 8602;
            text = "$STR_DUWS_T_faction_confirm_title";
            x = 0.1 * GUI_GRID_W + GUI_GRID_X;
            y = 0.02 * GUI_GRID_H + GUI_GRID_Y;
            w = 40 * GUI_GRID_W;
            h = 28 * GUI_GRID_H;
        };
        // Structured rather than plain: the standing advice runs past one line at this width and a
        // plain control cuts the tail off instead of wrapping.
        class confirm_intro: RscStructuredText
        {
            idc = 8603;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            // Taller and higher than the standing advice alone needed: it now also carries the
            // yellow/red colour legend, and runs to the caption row below it at y = 4.
            y = 0.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 3.2 * GUI_GRID_H;
        };
        // The side captions sit outside the group so they hold still while the rows scroll under
        // them. Coloured the way the faction dropdowns colour their two lists.
        class confirm_blufor_caption: RscStructuredText
        {
            idc = 8604;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.2 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
        };
        class confirm_opfor_caption: RscStructuredText
        {
            idc = 8605;
            x = 19.9 * GUI_GRID_W + GUI_GRID_X;
            y = 4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.2 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
        };
        // Both columns live in this one group so its single scrollbar moves them together. Its w/h
        // is the viewport; the scroll extent comes from the rows the builder creates inside it.
        class confirm_table: RscControlsGroup
        {
            idc = 8606;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 5.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 19.4 * GUI_GRID_H;
        };
        class confirm_footer: RscStructuredText
        {
            idc = 8607;
            x = 1 * GUI_GRID_W + GUI_GRID_X;
            y = 24.85 * GUI_GRID_H + GUI_GRID_Y;
            w = 38 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
        };
        class confirm_back: RscButton
        {
            idc = 8610;
            text = "$STR_DUWS_T_startup_back";
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 26 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_faction_confirm_back_tt";
            action = "duws_faction_confirm_back = true;";
        };
        class confirm_continue: RscButton
        {
            idc = 8611;
            text = "$STR_DUWS_T_faction_confirm_continue";
            x = 16 * GUI_GRID_W + GUI_GRID_X;
            y = 26 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0, 0.5};
            tooltip = "$STR_DUWS_T_faction_confirm_continue_tt";
            action = "[] call fnc_faction_prompt_lock;";
        };

        // --- Prompts. Hidden until raised; the sheet under each one is what stops a click
        //     reaching the table behind it.
        class clear_sheet: RscText
        {
            idc = 8640;
            x = -0.6 * GUI_GRID_W + GUI_GRID_X;
            y = -0.48 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 29 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.6};
        };
        class clear_background: RscText
        {
            idc = 8641;
            x = 12 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 6.5 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
        class clear_frame: RscFrame
        {
            idc = 8642;
            text = "$STR_DUWS_T_faction_clear_title";
            x = 12 * GUI_GRID_W + GUI_GRID_X;
            y = 11 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 6.5 * GUI_GRID_H;
        };
        class clear_text: RscStructuredText
        {
            idc = 8643;
            x = 12.6 * GUI_GRID_W + GUI_GRID_X;
            y = 12.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 14.8 * GUI_GRID_W;
            h = 3 * GUI_GRID_H;
        };
        class clear_cancel: RscButton
        {
            idc = 8644;
            text = "$STR_DUWS_T_faction_cancel";
            x = 12.8 * GUI_GRID_W + GUI_GRID_X;
            y = 15.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "[] call fnc_faction_prompt_hide;";
        };
        class clear_confirm: RscButton
        {
            idc = 8645;
            text = "$STR_DUWS_T_faction_confirm_clear";
            x = 20.6 * GUI_GRID_W + GUI_GRID_X;
            y = 15.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {1, 0, 0, 0.5};
            action = "[] call fnc_faction_key_clear;";
        };

        class lock_sheet: RscText
        {
            idc = 8650;
            x = -0.6 * GUI_GRID_W + GUI_GRID_X;
            y = -0.48 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 29 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.6};
        };
        class lock_background: RscText
        {
            idc = 8651;
            x = 12 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 11.5 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
        class lock_frame: RscFrame
        {
            idc = 8652;
            text = "$STR_DUWS_T_faction_lock_title";
            x = 12 * GUI_GRID_W + GUI_GRID_X;
            y = 10.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 11.5 * GUI_GRID_H;
        };
        // One structured control carries both the question and the missing-key warning: the warning
        // is conditional, and a second control would leave a gap on the screens that omit it.
        class lock_text: RscStructuredText
        {
            idc = 8653;
            x = 12.6 * GUI_GRID_W + GUI_GRID_X;
            y = 11.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 14.8 * GUI_GRID_W;
            h = 8 * GUI_GRID_H;
        };
        class lock_cancel: RscButton
        {
            idc = 8654;
            text = "$STR_DUWS_T_faction_cancel";
            x = 12.8 * GUI_GRID_W + GUI_GRID_X;
            y = 20 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "[] call fnc_faction_prompt_hide;";
        };
        class lock_confirm: RscButton
        {
            idc = 8655;
            text = "$STR_DUWS_T_faction_confirm_continue";
            x = 20.6 * GUI_GRID_W + GUI_GRID_X;
            y = 20 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {1, 0, 0, 0.5};
            action = "duws_faction_confirm_done = true;";
        };
    };
};

// Sits on top of the confirmation screen, which stays open behind it -- the same arrangement the
// HQ placement dialog uses over the faction screen. Shape follows the AutoDetect picker: two
// dropdowns over a preview, with the action button in red.
class startup_faction_key_edit
{
    idd = -1;
    movingenable = false;
    // Stashed because the confirmation screen is still open underneath: displayCtrl has to be
    // asked of this display specifically, not of whatever findDisplay would return.
    onLoad = "uiNamespace setVariable ['duws_faction_edit_display', _this select 0]; (_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";

    class ControlsBackground
    {
        class background: RscText
        {
            idc = -1;
            x = 9 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 22 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
    };

    class controls
    {
        class edit_inner: RscText
        {
            idc = 8620;
            x = 9.4 * GUI_GRID_W + GUI_GRID_X;
            y = 3.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 21.2 * GUI_GRID_W;
            h = 21.2 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class edit_frame: RscFrame
        {
            idc = 8621;
            text = "";  // set per row (side + role) by fnc_faction_key_edit
            x = 9 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 22 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
        };
        class edit_faction_label: RscText
        {
            idc = 8622;
            text = "$STR_DUWS_T_faction_edit_faction";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 4.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class edit_faction_combo: RscCombo
        {
            idc = 8623;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 4.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class edit_filter_label: RscText
        {
            idc = 8631;
            text = "$STR_DUWS_T_faction_edit_filter";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 6 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class edit_filter_box: RscEdit
        {
            idc = 8632;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 6 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_faction_edit_filter_tt";
        };
        class edit_class_label: RscText
        {
            idc = 8624;
            text = "$STR_DUWS_T_faction_edit_class";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class edit_class_combo: RscCombo
        {
            idc = 8625;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class edit_preview: RscPicture
        {
            idc = 8626;
            text = "#(argb,8,8,3)color(0,0,0,0.5)";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 8.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 10.4 * GUI_GRID_H;
        };
        // Transparent overlay for the "no preview" caption, so it reads over the picture rather
        // than replacing it.
        class edit_preview_caption: RscStructuredText
        {
            idc = 8627;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 12.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0};
        };
        class edit_info: RscStructuredText
        {
            idc = 8628;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 19 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 2.6 * GUI_GRID_H;
        };
        class edit_cancel: RscButton
        {
            idc = 8629;
            text = "$STR_DUWS_T_faction_cancel";
            x = 10.5 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
        class edit_confirm: RscButton
        {
            idc = 8630;
            text = "$STR_DUWS_T_faction_edit_confirm";
            x = 21.5 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0, 0.5};
            action = "[] call fnc_faction_key_apply;";
        };
    };
};

// The vehicle keys' editor: startup_faction_key_edit's browser on the left, the role's list on the
// right. Not inherited from it: every browser control moves, so a derived class would override each
// one anyway, and the browser keeps its IDCs so fnc_faction_key_edit drives both dialogs. The list's
// buttons and CONFIRM get their handlers from fnc_faction_key_list.
class startup_faction_key_list
{
    idd = -1;
    movingenable = false;
    onLoad = "uiNamespace setVariable ['duws_faction_edit_display', _this select 0]; (_this select 0) displayAddEventhandler ['KeyDown', {(_this select 1) isEqualTo 1}];";

    class ControlsBackground
    {
        class background: RscText
        {
            idc = -1;
            x = 2 * GUI_GRID_W + GUI_GRID_X;
            y = 0.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 36 * GUI_GRID_W;
            h = 24.5 * GUI_GRID_H;
            colorBackground[] = {0.2, 0.4, 0.2, 1};
        };
    };

    class controls
    {
        class edit_inner: RscText
        {
            idc = 8620;
            x = 2.4 * GUI_GRID_W + GUI_GRID_X;
            y = 0.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 35.2 * GUI_GRID_W;
            h = 23.7 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class edit_frame: RscFrame
        {
            idc = 8621;
            text = "";
            x = 2 * GUI_GRID_W + GUI_GRID_X;
            y = 0.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 36 * GUI_GRID_W;
            h = 24.5 * GUI_GRID_H;
        };
        class edit_faction_label: RscText
        {
            idc = 8622;
            text = "$STR_DUWS_T_faction_edit_faction";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 2.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class edit_faction_combo: RscCombo
        {
            idc = 8623;
            x = 7 * GUI_GRID_W + GUI_GRID_X;
            y = 2.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class edit_filter_label: RscText
        {
            idc = 8631;
            text = "$STR_DUWS_T_faction_edit_filter";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 3.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class edit_filter_box: RscEdit
        {
            idc = 8632;
            x = 7 * GUI_GRID_W + GUI_GRID_X;
            y = 3.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_faction_edit_filter_tt";
        };
        class edit_class_label: RscText
        {
            idc = 8624;
            text = "$STR_DUWS_T_faction_edit_class";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class edit_class_combo: RscCombo
        {
            idc = 8625;
            x = 7 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 12.6 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class list_add: RscButton
        {
            idc = 8634;
            text = "$STR_DUWS_T_faction_edit_add";
            x = 19.8 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 3.2 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class edit_preview: RscPicture
        {
            idc = 8626;
            text = "#(argb,8,8,3)color(0,0,0,0.5)";
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 5.7 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 9 * GUI_GRID_H;
        };
        class edit_preview_caption: RscStructuredText
        {
            idc = 8627;
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 9.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0};
        };
        class edit_info: RscStructuredText
        {
            idc = 8628;
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 14.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 1.8 * GUI_GRID_H;
        };
        class list_label: RscText
        {
            idc = -1;
            text = "$STR_DUWS_T_faction_edit_list";
            x = 24 * GUI_GRID_W + GUI_GRID_X;
            y = 2.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class list_box: RscListBox
        {
            idc = 8633;
            x = 24 * GUI_GRID_W + GUI_GRID_X;
            y = 3.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 13 * GUI_GRID_W;
            h = 11.8 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class list_remove: RscButton
        {
            idc = 8635;
            text = "$STR_DUWS_T_faction_edit_remove";
            x = 24 * GUI_GRID_W + GUI_GRID_X;
            y = 15.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4.2 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class list_main: RscButton
        {
            idc = 8636;
            text = "$STR_DUWS_T_faction_edit_main";
            x = 28.4 * GUI_GRID_W + GUI_GRID_X;
            y = 15.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4.2 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class list_reset: RscButton
        {
            idc = 8637;
            text = "$STR_DUWS_T_faction_edit_reset";
            x = 32.8 * GUI_GRID_W + GUI_GRID_X;
            y = 15.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 4.2 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
        };
        class list_help: RscStructuredText
        {
            idc = 8638;
            x = 3 * GUI_GRID_W + GUI_GRID_X;
            y = 17.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 34 * GUI_GRID_W;
            h = 5.6 * GUI_GRID_H;
        };
        class edit_cancel: RscButton
        {
            idc = 8629;
            text = "$STR_DUWS_T_faction_cancel";
            x = 3.5 * GUI_GRID_W + GUI_GRID_X;
            y = 22.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
        class edit_confirm: RscButton
        {
            idc = 8630;
            text = "$STR_DUWS_T_faction_edit_confirm";
            x = 28.5 * GUI_GRID_W + GUI_GRID_X;
            y = 22.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.05;
            colorBackground[] = {1, 0, 0, 0.5};
        };
    };
};
