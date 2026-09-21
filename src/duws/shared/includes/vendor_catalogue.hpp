// The shop catalogue: what a vendor has for sale, filtered and previewed. Shape follows the faction
// class browser (faction_confirm.hpp, startup_faction_key_edit) because it is the same job -- pick one
// class out of thousands -- and fnc_class_rows_fill fills both. Its faction combo becomes a stock
// picker here; the pair of buy buttons and the price line are what this adds.
//
// idc block 8900-8914; the nearest neighbours are the faction browser's 8620-8655 and rest_menu's
// 8700-8721. DUWS_vendor_target is set by fnc_vendor_catalogue before the dialog opens -- a dialog
// control has no access to the addAction's _target.
class vendor_catalogue
{
    idd = -1;
    movingenable = false;
    // Stashed rather than found: displayCtrl has to be asked of this display specifically, and the
    // browser helpers this shares with the faction screen all work that way.
    onLoad = "uiNamespace setVariable ['duws_vendor_display', _this select 0];";

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
        class vendor_inner: RscText
        {
            idc = 8900;
            x = 9.4 * GUI_GRID_W + GUI_GRID_X;
            y = 3.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 21.2 * GUI_GRID_W;
            h = 21.2 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class vendor_frame: RscFrame
        {
            idc = 8901;
            text = "";  // set to the vendor's name by fnc_vendor_catalogue
            x = 9 * GUI_GRID_W + GUI_GRID_X;
            y = 3 * GUI_GRID_H + GUI_GRID_Y;
            w = 22 * GUI_GRID_W;
            h = 22 * GUI_GRID_H;
        };
        class vendor_stock_label: RscText
        {
            idc = 8902;
            text = "$STR_DUWS_T_VENDOR_STOCK";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 4.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class vendor_stock_combo: RscCombo
        {
            idc = 8903;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 4.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class vendor_filter_label: RscText
        {
            idc = 8904;
            text = "$STR_DUWS_T_faction_edit_filter";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 6 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class vendor_filter_box: RscEdit
        {
            idc = 8905;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 6 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            tooltip = "$STR_DUWS_T_faction_edit_filter_tt";
        };
        class vendor_class_label: RscText
        {
            idc = 8906;
            text = "$STR_DUWS_T_faction_edit_class";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 4 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
            sizeEx = 0.03;
        };
        class vendor_class_combo: RscCombo
        {
            idc = 8907;
            x = 14 * GUI_GRID_W + GUI_GRID_X;
            y = 7 * GUI_GRID_H + GUI_GRID_Y;
            w = 16 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class vendor_preview: RscPicture
        {
            idc = 8908;
            text = "#(argb,8,8,3)color(0,0,0,0.5)";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 8.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 9.4 * GUI_GRID_H;
        };
        // Transparent overlay for the "no preview" caption, so it reads over the picture rather than
        // replacing it.
        class vendor_preview_caption: RscStructuredText
        {
            idc = 8909;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 12.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0};
        };
        class vendor_info: RscStructuredText
        {
            idc = 8910;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 17.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 2.2 * GUI_GRID_H;
        };
        class vendor_price: RscText
        {
            idc = 8911;
            text = "";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 20.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            style = ST_CENTER;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };
        class vendor_close: RscButton
        {
            idc = 8912;
            text = "$STR_DUWS_T_MENU_CLOSE";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 4.5 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.035;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
        class vendor_take: RscButton
        {
            idc = 8913;
            text = "$STR_DUWS_T_VENDOR_TAKE";
            tooltip = "$STR_DUWS_T_VENDOR_TAKE_TT";
            x = 15 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.5 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.035;
            colorBackground[] = {1, 0, 0, 0.5};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
        };
        class vendor_store: RscButton
        {
            idc = 8914;
            text = "$STR_DUWS_T_VENDOR_STORE";
            tooltip = "$STR_DUWS_T_VENDOR_STORE_TT";
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 9 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            sizeEx = 0.035;
            colorBackground[] = {1, 0, 0, 0.5};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
        };
    };
};
