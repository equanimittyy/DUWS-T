// Civilian interaction panel: the single entry point in front of what a local will do for the
// player. Six framed rows in the Squad-Manager idiom, each with a description and a button that
// closeDialog 0 then remoteExecs the work to the server.
//
// Rows carry no price. The reaction is rolled on the server when a row is picked, so a price
// printed here would be a guess at a demand that only arrives some of the time -- if the roll
// comes back bribe, civ_bribe_dialog below states the amount and the player answers it.
//
// idc block 8300-8399 here and 8400-8499 for the prompts; the nearest neighbours are the disguise
// panel's 8000-8203 and fobmanager's 9745. DUWS_civ_target is set by fnc_civ_menu before the
// dialog opens -- a dialog action string has no access to the addAction's _target.
class civ_dialog
{
    idd = -1;
    movingenable = true;

    class controls
    {
        class civ_background: RscText
        {
            idc = 8300;
            x = 5 * GUI_GRID_W + GUI_GRID_X;
            y = 0.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 30 * GUI_GRID_W;
            h = 24.7 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.7};
        };
        class civ_mainframe: RscFrame
        {
            idc = 8301;
            text = "$STR_DUWS_T_CIV_MENU_TITLE";
            x = 5 * GUI_GRID_W + GUI_GRID_X;
            y = 0.3 * GUI_GRID_H + GUI_GRID_Y;
            w = 30 * GUI_GRID_W;
            h = 24.7 * GUI_GRID_H;
            moving = 1;
        };
        class civ_money: RscText
        {
            idc = 8310;
            text = "";
            x = 6 * GUI_GRID_W + GUI_GRID_X;
            y = 1.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 28 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            style = ST_CENTER;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };

        // Rows are pitched 3.4 apart on a 3.0 frame; at 3.5, six rows ran Close off the bottom of the
        // screen. The description is the row's tallest part and wraps to three lines at 0.030 on a
        // narrow window, so the frame has to clear three lines plus its own border -- at the 2.8
        // this was, the third line drew over the bottom edge.
        //
        // The description sits 0.65 below its frame, not the 0.35 it did: RscFrame centres its
        // title on the top border, so the title's lower half reaches about 0.44 into the frame and
        // the first line of description was drawing through it. Height came down by the same
        // amount to hold the bottom edge where it was, which is the margin the note above is
        // about -- so the box gained clearance at the top and spent it, rather than growing.
        class civ_intel_frame: RscFrame
        {
            idc = 8320;
            text = "$STR_DUWS_T_CIV_ROW_INTEL";
            x = 6 * GUI_GRID_W + GUI_GRID_X;
            y = 6.5 * GUI_GRID_H + GUI_GRID_Y;
            w = 28 * GUI_GRID_W;
            h = 3 * GUI_GRID_H;
        };
        class civ_intel_desc: RscText
        {
            idc = 8330;
            text = "$STR_DUWS_T_CIV_ROW_INTEL_DESC";
            x = 6.5 * GUI_GRID_W + GUI_GRID_X;
            y = 7.15 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.5 * GUI_GRID_W;
            h = 2 * GUI_GRID_H;
            style = ST_MULTI;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.030;
        };
        class civ_intel_button: RscButton
        {
            idc = 8340;
            text = "$STR_DUWS_T_CIV_ASK";
            x = 25.3 * GUI_GRID_W + GUI_GRID_X;
            y = 7.25 * GUI_GRID_H + GUI_GRID_Y;
            w = 8.2 * GUI_GRID_W;
            h = 1.5 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
            tooltip = "$STR_DUWS_T_CIV_ROW_INTEL_DESC";
            action = "closeDialog 0; [DUWS_civ_target, player, 'INTEL'] remoteExec ['fnc_civ_request', 2];";
        };

        // fnc_civ_menu relabels this Report on a mission's giver, and Give Money with its own action on a
        // Raise Funds giver; the server decides Work or Report from its own record, so the label decides nothing.
        class civ_work_frame: civ_intel_frame
        {
            idc = 8325;
            text = "$STR_DUWS_T_CIVMISSION_ROW_WORK";
            y = 3.1 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_work_desc: civ_intel_desc
        {
            idc = 8335;
            text = "$STR_DUWS_T_CIVMISSION_ROW_WORK_DESC";
            y = 3.75 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_work_button: civ_intel_button
        {
            idc = 8345;
            y = 3.85 * GUI_GRID_H + GUI_GRID_Y;
            tooltip = "";
            action = "closeDialog 0; [DUWS_civ_target, player, 'WORK'] remoteExec ['fnc_civ_mission_request', 2];";
        };
        class civ_cancel_button: civ_intel_button
        {
            idc = 8346;
            text = "$STR_DUWS_T_CIVMISSION_CANCEL";
            x = 17 * GUI_GRID_W + GUI_GRID_X;
            y = 3.85 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            colorBackground[] = {0.6, 0.13, 0.13, 0.85};
            tooltip = "";
            action = "closeDialog 0; [DUWS_civ_target, player, 'CANCEL'] remoteExec ['fnc_civ_mission_request', 2];";
        };

        class civ_aid_frame: civ_intel_frame
        {
            idc = 8321;
            text = "$STR_DUWS_T_CIV_ROW_AID";
            y = 9.9 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_aid_desc: civ_intel_desc
        {
            idc = 8331;
            text = "$STR_DUWS_T_CIV_ROW_AID_DESC";
            y = 10.55 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_aid_button: civ_intel_button
        {
            idc = 8341;
            y = 10.65 * GUI_GRID_H + GUI_GRID_Y;
            tooltip = "$STR_DUWS_T_CIV_ROW_AID_DESC";
            action = "closeDialog 0; [DUWS_civ_target, player, 'AID'] remoteExec ['fnc_civ_request', 2];";
        };

        class civ_toolkit_frame: civ_intel_frame
        {
            idc = 8322;
            text = "$STR_DUWS_T_CIV_ROW_TOOLKIT";
            y = 13.3 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_toolkit_desc: civ_intel_desc
        {
            idc = 8332;
            text = "$STR_DUWS_T_CIV_ROW_TOOLKIT_DESC";
            y = 13.95 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_toolkit_button: civ_intel_button
        {
            idc = 8342;
            y = 14.05 * GUI_GRID_H + GUI_GRID_Y;
            tooltip = "$STR_DUWS_T_CIV_ROW_TOOLKIT_DESC";
            action = "closeDialog 0; [DUWS_civ_target, player, 'TOOLKIT'] remoteExec ['fnc_civ_request', 2];";
        };

        class civ_recruit_frame: civ_intel_frame
        {
            idc = 8323;
            text = "$STR_DUWS_T_CIV_ROW_RECRUIT";
            y = 16.7 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_recruit_desc: civ_intel_desc
        {
            idc = 8333;
            text = "$STR_DUWS_T_CIV_ROW_RECRUIT_DESC";
            y = 17.35 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_recruit_button: civ_intel_button
        {
            idc = 8343;
            y = 17.45 * GUI_GRID_H + GUI_GRID_Y;
            tooltip = "$STR_DUWS_T_CIV_ROW_RECRUIT_DESC";
            action = "closeDialog 0; [DUWS_civ_target, player, 'RECRUIT'] remoteExec ['fnc_civ_request', 2];";
        };

        // Red, and named for what the player is doing. Arrest is coercion rather than
        // conversation, so it reaches its own server function: no reaction is rolled, no bribe is
        // asked, and a civilian who has refused to talk can still be detained.
        class civ_arrest_frame: civ_intel_frame
        {
            idc = 8324;
            text = "$STR_DUWS_T_CIV_ROW_ARREST";
            y = 20.1 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_arrest_desc: civ_intel_desc
        {
            idc = 8334;
            text = "$STR_DUWS_T_CIV_ROW_ARREST_DESC";
            y = 20.75 * GUI_GRID_H + GUI_GRID_Y;
        };
        class civ_arrest_button: civ_intel_button
        {
            idc = 8344;
            text = "$STR_DUWS_T_CIV_ROW_ARREST";
            y = 20.85 * GUI_GRID_H + GUI_GRID_Y;
            colorBackground[] = {0.6, 0.13, 0.13, 0.85};
            tooltip = "$STR_DUWS_T_CIV_ROW_ARREST_DESC";
            action = "closeDialog 0; [DUWS_civ_target, player] remoteExec ['fnc_civ_arrest', 2];";
        };

        class civ_close: RscButton
        {
            idc = 8350;
            text = "$STR_DUWS_T_MENU_CLOSE";
            x = 13 * GUI_GRID_W + GUI_GRID_X;
            y = 23.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 14 * GUI_GRID_W;
            h = 1.3 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
    };
};

// The bribe prompt, which also carries a civilian side mission's job offer (fnc_civ_bribe_prompt).
// onUnload rather than a send on each button, so closing with Escape answers
// too: an offer left hanging would block the civilian silently, and refusing is what Escape
// means here. Answering twice is harmless -- the server clears its record on the first answer
// and a second arrives to nothing.
class civ_bribe_dialog
{
    idd = -1;
    movingenable = true;
    onUnload = "[DUWS_civ_target, player, DUWS_civ_bribe_accepted] remoteExec ['fnc_civ_bribe_answer', 2];";

    class controls
    {
        class civb_background: RscText
        {
            idc = 8400;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 10.2 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.8};
        };
        class civb_mainframe: RscFrame
        {
            idc = 8401;
            text = "$STR_DUWS_T_CIV_BRIBE_TITLE";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 10.2 * GUI_GRID_H;
            moving = 1;
        };
        // Sized for a job brief, which wraps to five lines where a bribe demand takes two.
        class civb_demand: RscText
        {
            idc = 8410;
            text = "";
            x = 10.6 * GUI_GRID_W + GUI_GRID_X;
            y = 9.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.8 * GUI_GRID_W;
            h = 4.6 * GUI_GRID_H;
            style = ST_MULTI;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.033;
        };
        class civb_money: RscText
        {
            idc = 8411;
            text = "";
            x = 10.6 * GUI_GRID_W + GUI_GRID_X;
            y = 14 * GUI_GRID_H + GUI_GRID_Y;
            w = 18.8 * GUI_GRID_W;
            h = 1.2 * GUI_GRID_H;
            style = ST_CENTER;
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.033;
        };
        class civb_accept: RscButton
        {
            idc = 8420;
            text = "$STR_DUWS_T_CIV_BRIBE_ACCEPT";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 15.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            colorBackgroundDisabled[] = {0.35, 0.35, 0.35, 0.5};
            action = "DUWS_civ_bribe_accepted = true; closeDialog 0;";
        };
        class civb_refuse: RscButton
        {
            idc = 8421;
            text = "$STR_DUWS_T_CIV_BRIBE_REFUSE";
            x = 21 * GUI_GRID_W + GUI_GRID_X;
            y = 15.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 8 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
    };
};

// Raise Funds' gift, in the rest dialog's slider idiom; opened by fnc_civ_give_menu.
class civ_give_dialog
{
    idd = -1;
    movingenable = true;

    class controls
    {
        class civg_background: RscText
        {
            idc = 8430;
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 7.6 * GUI_GRID_H;
            colorBackground[] = {0, 0, 0, 0.7};
        };
        class civg_mainframe: RscFrame
        {
            idc = 8431;
            text = "$STR_DUWS_T_CIVMISSION_ROW_GIVE";
            x = 10 * GUI_GRID_W + GUI_GRID_X;
            y = 8 * GUI_GRID_H + GUI_GRID_Y;
            w = 20 * GUI_GRID_W;
            h = 7.6 * GUI_GRID_H;
            moving = 1;
        };
        class civg_raised: RscText
        {
            idc = 8432;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 9.2 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1 * GUI_GRID_H;
        };
        class civg_amount: RscText
        {
            idc = 8433;
            style = ST_CENTER;
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 10.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 1.1 * GUI_GRID_H;
        };
        class civg_slider: RscSlider
        {
            idc = 8434;
            onSliderPosChanged = "ctrlSetText [8433, format [localize 'STR_DUWS_T_CIVMISSION_GIVE_AMOUNT', round (_this select 1)]];";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 11.8 * GUI_GRID_H + GUI_GRID_Y;
            w = 18 * GUI_GRID_W;
            h = 0.8 * GUI_GRID_H;
        };
        class civg_confirm: RscButton
        {
            idc = 8435;
            text = "$STR_DUWS_T_CIVMISSION_GIVE";
            x = 11 * GUI_GRID_W + GUI_GRID_X;
            y = 13.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 11 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.16, 0.3, 0.55, 0.7};
            action = "[DUWS_civ_target, player, round (sliderPosition 8434)] remoteExecCall ['fnc_civ_mission_give', 2]; closeDialog 0;";
        };
        class civg_close: RscButton
        {
            idc = 8436;
            text = "$STR_DUWS_T_MENU_CLOSE";
            x = 23 * GUI_GRID_W + GUI_GRID_X;
            y = 13.4 * GUI_GRID_H + GUI_GRID_Y;
            w = 6 * GUI_GRID_W;
            h = 1.4 * GUI_GRID_H;
            colorBackground[] = {0.35, 0.35, 0.35, 0.5};
            action = "closeDialog 0;";
        };
    };
};
