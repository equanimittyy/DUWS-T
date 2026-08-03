// The bottom of the faction setup screen, in a dialog of its own. Two things force that, and either
// alone would be enough. The screen is an RscDisplayEmpty built by ctrlCreate
// (client/dialog/fnc_HQ_faction_dialog.sqf), and a display made that way takes no mouse cursor --
// having a dialog open beside it is what makes the screen clickable at all. And a control created on
// it resolves its class against that display's config rather than the mission's, so it comes up as
// the engine's RscButton: no green hover, no focus colour, different shadow, border, press offsets
// and click sounds, and only some of that has a runtime setter
// (docs/info/arma_engine_gotchas.md). Declared here, these are ordinary menu buttons.
//
// The panel continues the screen's green rather than opening a second box. It has to be this way
// round: the display draws over this dialog, so the screen's own panel stops just above this strip
// and the two meet edge to edge at the same x and width. No frame here -- the screen's frame spans
// both and draws over the join, an RscFrame being transparent inside.
class startup_hq_placement_dialog
{
	idd = -1;
	movingenable = false;

	class controls
	{
		class hq_placement_panel: RscText
		{
			idc = 1443;
			x = 3 * GUI_GRID_W + GUI_GRID_X;
			y = 11.9 * GUI_GRID_H + GUI_GRID_Y;
			w = 34 * GUI_GRID_W;
			h = 5.9 * GUI_GRID_H;
			colorBackground[] = {0.2, 0.4, 0.2, 1};
		};
		class hq_placement_random_button: RscButton
		{
			idc = 1600;
			text = "$STR_DUWS_T_2f55ngq1";
			x = 11 * GUI_GRID_W + GUI_GRID_X;
			y = 12 * GUI_GRID_H + GUI_GRID_Y;
			w = 18 * GUI_GRID_W;
			h = 2.5 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_50n9sdxk";
			action = "[20, 0.015] remoteExec ['fnc_HQ_random_place',player1]; closedialog 0;";
		};
		class hq_placement_manual_button: RscButton
		{
			idc = 1601;
			text = "$STR_DUWS_T_x0cq7o5y";
			x = 11 * GUI_GRID_W + GUI_GRID_X;
			y = 14.8 * GUI_GRID_H + GUI_GRID_Y;
			w = 18 * GUI_GRID_W;
			h = 2.5 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_qwfdr33k";
			action = "[] spawn fnc_HQ_manual_place; closedialog 0;";
		};
	};
};
