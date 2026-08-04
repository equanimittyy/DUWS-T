// HQ placement, opened on its own over the map once the faction confirmation screen is done with
// (client/dialog/fnc_hq_placement.sqf). It used to be the bottom strip of the faction setup screen
// and borrowed that screen's panel, title and caption; standing alone it carries its own, in the
// shape every other setup screen uses -- a filled panel, a titled frame just inside it, and the
// standing advice above the answers.
//
// Sized to leave the map either side of it rather than filling the screen: the manual answer is a
// map click, and a full-width box would hide the ground the player is about to judge.
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
	// Stashed so fnc_hq_placement can fill the structured-text controls below: their markup is set
	// from script, the same way every other screen in this flow sets its captions.
	onLoad = "uiNamespace setVariable ['duws_hq_placement_display', _this select 0];";

	class ControlsBackground
	{
		class hq_placement_panel: RscText
		{
			idc = -1;
			x = 8 * GUI_GRID_W + GUI_GRID_X;
			y = 7 * GUI_GRID_H + GUI_GRID_Y;
			w = 24 * GUI_GRID_W;
			h = 11 * GUI_GRID_H;
			colorBackground[] = {0.2, 0.4, 0.2, 1};
		};
	};

	class controls
	{
		class hq_placement_inner: RscText
		{
			idc = -1;
			x = 8.3 * GUI_GRID_W + GUI_GRID_X;
			y = 7.3 * GUI_GRID_H + GUI_GRID_Y;
			w = 23.4 * GUI_GRID_W;
			h = 10.4 * GUI_GRID_H;
			colorBackground[] = {0,0,0,0.3};
		};
		class hq_placement_frame: RscFrame
		{
			idc = 1440;
			text = "$STR_DUWS_T_hq_place_title";
			x = 8 * GUI_GRID_W + GUI_GRID_X;
			y = 7 * GUI_GRID_H + GUI_GRID_Y;
			w = 24 * GUI_GRID_W;
			h = 11 * GUI_GRID_H;
		};
		// Structured rather than plain: the advice runs to several lines at this width and a plain
		// control cuts the tail off instead of wrapping. It names both answers and what each costs,
		// so neither button needs a caption of its own repeating it.
		class hq_placement_intro: RscStructuredText
		{
			idc = 1441;
			x = 8.8 * GUI_GRID_W + GUI_GRID_X;
			y = 8.4 * GUI_GRID_H + GUI_GRID_Y;
			w = 22.4 * GUI_GRID_W;
			h = 4.4 * GUI_GRID_H;
		};

		class hq_placement_random_button: RscButton
		{
			idc = 1600;
			text = "$STR_DUWS_T_2f55ngq1";
			x = 12.5 * GUI_GRID_W + GUI_GRID_X;
			y = 13.1 * GUI_GRID_H + GUI_GRID_Y;
			w = 15 * GUI_GRID_W;
			h = 2 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_50n9sdxk";
			action = "[20, 0.015] remoteExec ['fnc_HQ_random_place',player1]; closedialog 0;";
		};
		class hq_placement_manual_button: RscButton
		{
			idc = 1601;
			text = "$STR_DUWS_T_x0cq7o5y";
			x = 12.5 * GUI_GRID_W + GUI_GRID_X;
			y = 15.4 * GUI_GRID_H + GUI_GRID_Y;
			w = 15 * GUI_GRID_W;
			h = 2 * GUI_GRID_H;
			tooltip = "$STR_DUWS_T_qwfdr33k";
			action = "[] spawn fnc_HQ_manual_place; closedialog 0;";
		};
	};
};
