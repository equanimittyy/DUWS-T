// The shop catalogue. Laid out on the request dialog's geometry (request_menu.hpp) so the two read as
// one family: the item window where the main window sits, the stock list as the strip on the right,
// and the close button on its own row beneath, where EXIT is.
//
// idc block 8901-8916; the nearest neighbours are the faction browser's 8620-8655 and rest_menu's
// 8700-8721. DUWS_vendor_target is set by fnc_vendor_catalogue before the dialog opens -- a dialog
// control has no access to the addAction's _target.
class vendor_catalogue
{
    idd = -1;
    movingenable = true;
    // Stashed rather than found: displayCtrl has to be asked of this display specifically.
    onLoad = "uiNamespace setVariable ['duws_vendor_display', _this select 0];";

    class controls
    {
        class vendor_background: RscText
        {
            x = -0.5 * GUI_GRID_W + GUI_GRID_X;
            y = 0.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 41 * GUI_GRID_W;
            h = 23.4 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0.3};
        };
        class vendor_pane: RscText
        {
            x = 0 * GUI_GRID_W + GUI_GRID_X;
            y = 1.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 21.5 * GUI_GRID_W;
            h = 20.9 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
        };
        class vendor_frame: RscFrame
        {
            idc = 8901;
            moving = 1;
            text = "";  // set to the vendor's name by fnc_vendor_catalogue
            x = 0 * GUI_GRID_W + GUI_GRID_X;
            y = 1.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 21.5 * GUI_GRID_W;
            h = 20.9 * GUI_GRID_H;
        };

        class vendor_money_box: RscFrame
        {
            text = "$STR_DUWS_T_VENDOR_BOX_MONEY";
            sizeEx = 0.025;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 1.9 * GUI_GRID_H + GUI_GRID_Y;
            w = 6.4 * GUI_GRID_W;
            h = 1.9 * GUI_GRID_H;
        };
        class vendor_money: RscText
        {
            idc = 8911;
            text = "--";
            x = 1.2 * GUI_GRID_W + GUI_GRID_X;
            y = 2.35 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.6 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
            colorText[] = {1,1,1,1};
        };
        class vendor_price_box: vendor_money_box
        {
            text = "$STR_DUWS_T_VENDOR_BOX_PRICE";
            x = 7.55 * GUI_GRID_W + GUI_GRID_X;
        };
        class vendor_price: vendor_money
        {
            idc = 8915;
            x = 7.95 * GUI_GRID_W + GUI_GRID_X;
        };
        class vendor_discount_box: vendor_money_box
        {
            text = "$STR_DUWS_T_VENDOR_BOX_DISCOUNT";
            x = 14.3 * GUI_GRID_W + GUI_GRID_X;
        };
        class vendor_discount: vendor_money
        {
            idc = 8916;
            x = 14.7 * GUI_GRID_W + GUI_GRID_X;
        };
        class vendor_divider: RscText
        {
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 4.15 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 0.06 * GUI_GRID_H;
            colorBackground[] = {1,1,1,0.25};
        };
        // 16:9 on the 4:3 grid, the shape of an editorPreview render.
        class vendor_preview: RscPicture
        {
            idc = 8908;
            text = "#(argb,8,8,3)color(0,0,0,0.5)";
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 9.3 * GUI_GRID_H;
        };
        // Transparent overlay for the "no preview" caption, so it reads over the picture rather than
        // replacing it.
        class vendor_preview_caption: RscStructuredText
        {
            idc = 8909;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 8.15 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            colorBackground[] = {0,0,0,0};
        };
        class vendor_info: RscStructuredText
        {
            idc = 8910;
            x = 0.8 * GUI_GRID_W + GUI_GRID_X;
            y = 14.1 * GUI_GRID_H + GUI_GRID_Y;
            w = 19.9 * GUI_GRID_W;
            h = 7.7 * GUI_GRID_H;
            size = 0.025;
        };

        class vendor_stock_frame: RscFrame
        {
            text = "$STR_DUWS_T_VENDOR_STOCK";
            x = 22 * GUI_GRID_W + GUI_GRID_X;
            y = 1.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.7 * GUI_GRID_W;
            h = 20.9 * GUI_GRID_H;
        };
        class vendor_stock_combo: RscCombo
        {
            idc = 8903;
            x = 22.2 * GUI_GRID_W + GUI_GRID_X;
            y = 2.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.5 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class vendor_category_combo: vendor_stock_combo
        {
            idc = 8906;
            x = 31 * GUI_GRID_W + GUI_GRID_X;
        };
        class vendor_filter_label: RscText
        {
            text = "$STR_DUWS_T_faction_edit_filter";
            x = 22.2 * GUI_GRID_W + GUI_GRID_X;
            y = 3.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 3 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class vendor_filter_box: RscEdit
        {
            idc = 8905;
            x = 25.2 * GUI_GRID_W + GUI_GRID_X;
            y = 3.6 * GUI_GRID_H + GUI_GRID_Y;
            w = 14.3 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            sizeEx = 0.025;
            tooltip = "$STR_DUWS_T_faction_edit_filter_tt";
        };
        class vendor_class_list: RscListBox
        {
            idc = 8907;
            x = 22.2 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 17.3 * GUI_GRID_W;
            h = 15.1 * GUI_GRID_H;
            sizeEx = 0.025;
        };
        class vendor_take: RscButton
        {
            idc = 8913;
            text = "$STR_DUWS_T_VENDOR_TAKE";
            tooltip = "$STR_DUWS_T_VENDOR_TAKE_TT";
            sizeEx = 0.025;
            x = 22.2 * GUI_GRID_W + GUI_GRID_X;
            y = 20.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.5 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
        };
        class vendor_store: vendor_take
        {
            idc = 8914;
            text = "$STR_DUWS_T_VENDOR_STORE";
            tooltip = "$STR_DUWS_T_VENDOR_STORE_TT";
            x = 31 * GUI_GRID_W + GUI_GRID_X;
        };

        class vendor_close: RscButton
        {
            idc = 8912;
            text = "$STR_DUWS_T_MENU_CLOSE";
            sizeEx = 0.025;
            x = 34.1 * GUI_GRID_W + GUI_GRID_X;
            y = 22.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 5.6 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            action = "closeDialog 0;";
        };
    };
};
