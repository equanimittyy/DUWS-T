// Rest/Heal dialog, opened via client/dialog/fnc_rest_menu.sqf. The confirm stashes the picks in
// globals the opener reads after the dialog closes -- an action string runs outside the opener's
// scope and cannot return a value any other way.
//
// idc block 8700-8799; nearest neighbours are veh_drop's 8500-8599 and the 8600-8655 range.

class rest_dialog
{
    idd = -1;
    movingenable = true;
    // idd is -1, so script reaches the labels through this stashed display rather than findDisplay.
    onLoad = "uiNamespace setVariable ['DUWS_rest_disp', _this select 0];";

    class controls
    {
        class rm_background: RscText
        {
            idc = 8700;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 3.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 19.5 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.7};
        };

        class rm_rest_frame: RscFrame
        {
            idc = 8701;
            text = "$STR_DUWS_T_rest_title";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 3.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 5 * GUI_GRID_H;
        };
        class rm_rest_label: RscText
        {
            idc = 8702;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 5 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
        };
        class rm_rest_slider: RscSlider
        {
            idc = 8703;
            onSliderPosChanged = "call fnc_rest_labels";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 6.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 0.8 * GUI_GRID_H;
        };

        class rm_weather_frame: RscFrame
        {
            idc = 8710;
            text = "$STR_DUWS_T_rest_weather_title";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 9 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 11.5 * GUI_GRID_H;
        };
        class rm_overcast_label: RscText
        {
            idc = 8711;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 10.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class rm_overcast_slider: RscSlider
        {
            idc = 8712;
            onSliderPosChanged = "_this call fnc_rest_couple";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 11.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 0.8 * GUI_GRID_H;
        };
        class rm_rain_label: RscText
        {
            idc = 8713;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class rm_rain_slider: RscSlider
        {
            idc = 8714;
            onSliderPosChanged = "_this call fnc_rest_couple";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 14 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 0.8 * GUI_GRID_H;
        };
        class rm_fog_label: RscText
        {
            idc = 8715;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 15.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class rm_fog_slider: RscSlider
        {
            idc = 8716;
            onSliderPosChanged = "call fnc_rest_labels";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 16.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 0.8 * GUI_GRID_H;
        };
        class rm_lightning_label: RscText
        {
            idc = 8717;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 17.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class rm_lightning_slider: RscSlider
        {
            idc = 8718;
            onSliderPosChanged = "call fnc_rest_labels";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 18.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 0.8 * GUI_GRID_H;
        };
        // Shown in place of the sliders when the Rest Weather Config parameter is Off; fnc_rest_menu
        // toggles it against the eight slider/label controls.
        class rm_weather_off: RscStructuredText
        {
            idc = 8719;
            text = "$STR_DUWS_T_rest_weather_off";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 13 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 4 * GUI_GRID_H;
        };

        class rm_confirm: RscButton
        {
            idc = 8720;
            text = "$STR_DUWS_T_rest_confirm";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 21 * GUI_GRID_H + GUI_GRID_Y;
            w = 11 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            action = "DUWS_rest_hours = sliderPosition 8703; DUWS_rest_overcast = sliderPosition 8712; DUWS_rest_rain = sliderPosition 8714; DUWS_rest_fog = sliderPosition 8716; DUWS_rest_lightning = sliderPosition 8718; DUWS_rest_confirmed = true; closeDialog 0;";
        };
        class rm_close: RscButton
        {
            idc = 8721;
            text = "$STR_DUWS_T_MENU_CLOSE";
            x = 23 * GUI_GRID_W + GUI_GRID_X;
            y = 21 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
    };
};
