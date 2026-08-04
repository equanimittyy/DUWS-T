// The HQ placement buttons, opened on their own over the map once the faction confirmation screen
// is done with (client/dialog/fnc_hq_placement.sqf). They used to be the bottom strip of the
// faction setup screen, which is why the geometry below still lands where that screen's panel
// ended; nothing draws behind them now, so the strip reads as a floating panel until it is
// repositioned.
//
// A dialog rather than controls on a display, which is what it has to be in either arrangement: a
// control created on an RscDisplayEmpty resolves its class against that display's config rather
// than the mission's, so it comes up as the engine's RscButton -- no green hover, no focus colour,
// different shadow, border, press offsets and click sounds, and only some of that has a runtime
// setter (docs/info/arma_engine_gotchas.md). Declared here, these are ordinary menu buttons.
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
			y = 12.7 * GUI_GRID_H + GUI_GRID_Y;
			w = 34 * GUI_GRID_W;
			h = 5.9 * GUI_GRID_H;
			colorBackground[] = {0.2, 0.4, 0.2, 1};
		};
		class hq_placement_random_button: RscButton
		{
			idc = 1600;
			text = "$STR_DUWS_T_2f55ngq1";
			x = 11 * GUI_GRID_W + GUI_GRID_X;
			y = 12.8 * GUI_GRID_H + GUI_GRID_Y;
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
			y = 15.6 * GUI_GRID_H + GUI_GRID_Y;
			w = 18 * GUI_GRID_W;
			h = 2.5 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_qwfdr33k";
			action = "[] spawn fnc_HQ_manual_place; closedialog 0;";
		};
	};
};
