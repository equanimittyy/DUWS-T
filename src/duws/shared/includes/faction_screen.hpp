// The faction setup screen's confirm button, in a dialog of its own. Two things force that, and
// either alone would be enough. The screen is an RscDisplayEmpty built by ctrlCreate
// (client/dialog/fnc_HQ_faction_dialog.sqf), and a display made that way takes no mouse cursor --
// having a dialog open beside it is what makes the screen clickable at all. And a control created on
// it resolves its class against that display's config rather than the mission's, so it comes up as
// the engine's RscButton: no green hover, no focus colour, different shadow, border, press offsets
// and click sounds, and only some of that has a runtime setter
// (docs/info/architecture/arma_engine_gotchas.md). Declared here, this is an ordinary menu button.
//
// It sits above every combo on the screen, which is what keeps it clickable rather than clicked
// through. A dropdown belongs to the other display and draws over this dialog without taking its
// clicks, so a list row opened over this button would put a pick straight through it and end the
// screen. Dropdowns only ever expand downwards, so being above the topmost one is the whole fix --
// no greying, no focus tracking. Anything lower would only be safe by arithmetic about how many
// rows a list holds, and the faction lists grow with every mod loaded.
//
// The panel continues the screen's green rather than opening a second box: the display draws over
// this dialog, so the screen's own panel is split around this strip and the three meet edge to edge
// at the same x and width. No frame here -- the screen's frame spans all of it and draws over the
// joins, an RscFrame being transparent inside.
class startup_faction_next_dialog
{
	idd = -1;
	movingenable = false;
	// Stashed so fnc_HQ_faction_dialog.sqf can hide the debug button below unless the DUWS_Debug
	// mission param is on -- config cannot read a mission param, so the gate has to be in SQF.
	onLoad = "uiNamespace setVariable ['duws_faction_next_display', _this select 0];";

	class controls
	{
		class faction_next_panel: RscText
		{
			idc = 1443;
			x = 3 * GUI_GRID_W + GUI_GRID_X;
			y = 4.3 * GUI_GRID_H + GUI_GRID_Y;
			w = 34 * GUI_GRID_W;
			h = 4.9 * GUI_GRID_H;
			colorBackground[] = {0.2, 0.4, 0.2, 1};
		};
		class faction_next_button: RscButton
		{
			idc = 1600;
			text = "$STR_DUWS_T_faction_screen_resolve";
			x = 13 * GUI_GRID_W + GUI_GRID_X;
			y = 4.6 * GUI_GRID_H + GUI_GRID_Y;
			w = 14 * GUI_GRID_W;
			h = 2 * GUI_GRID_H;
			sizeEx = 0.05;
			colorBackground[] = {1, 0, 0, 0.5};
			tooltip = "$STR_DUWS_T_callsign_next_tt";
			action = "duws_faction_screen_next = true;";
		};
		// Dev-only shortcut past the whole setup flow. Hidden unless the DUWS_Debug param is on
		// (ctrlShow from fnc_HQ_faction_dialog.sqf). Sits in the panel's left gap, clear of the
		// BUILD FACTIONS button, and shares the same tear-down as that button -- the flow reads
		// duws_debug_quickstart and diverts (client/dialog/fnc_startup_faction_flow.sqf).
		class faction_debug_button: RscButton
		{
			idc = 1601;
			text = "$STR_DUWS_T_faction_debug_quickstart";
			x = 3.75 * GUI_GRID_W + GUI_GRID_X;
			y = 4.6 * GUI_GRID_H + GUI_GRID_Y;
			w = 6.5 * GUI_GRID_W;
			h = 2 * GUI_GRID_H;
			sizeEx = 0.04;
			colorBackground[] = {0.2, 0.3, 0.6, 0.8};
			tooltip = "$STR_DUWS_T_faction_debug_quickstart_tt";
			action = "duws_debug_quickstart = true; duws_faction_screen_next = true;";
		};
		// Ends the screen the way BUILD FACTIONS does; the flow reads duws_faction_screen_back and returns to the load screen.
		class faction_back_button: RscButton
		{
			idc = 1602;
			text = "$STR_DUWS_T_faction_screen_back";
			x = 13 * GUI_GRID_W + GUI_GRID_X;
			y = 6.9 * GUI_GRID_H + GUI_GRID_Y;
			w = 14 * GUI_GRID_W;
			h = 2 * GUI_GRID_H;
			sizeEx = 0.03;
			colorBackground[] = {0.35, 0.35, 0.35, 0.5};
			tooltip = "$STR_DUWS_T_faction_screen_back_tt";
			action = "duws_faction_screen_back = true; duws_faction_screen_next = true;";
		};
	};
};
