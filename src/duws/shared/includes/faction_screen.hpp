// The bottom of the faction setup screen, in a dialog of its own. Two things force that, and either
// alone would be enough. The screen is an RscDisplayEmpty built by ctrlCreate
// (client/dialog/fnc_HQ_faction_dialog.sqf), and a display made that way takes no mouse cursor --
// having a dialog open beside it is what makes the screen clickable at all. And a control created on
// it resolves its class against that display's config rather than the mission's, so it comes up as
// the engine's RscButton: no green hover, no focus colour, different shadow, border, press offsets
// and click sounds, and only some of that has a runtime setter
// (docs/info/arma_engine_gotchas.md). Declared here, this is an ordinary menu button.
//
// The panel continues the screen's green rather than opening a second box. It has to be this way
// round: the display draws over this dialog, so the screen's own panel stops just above this strip
// and the two meet edge to edge at the same x and width. No frame here -- the screen's frame spans
// both and draws over the join, an RscFrame being transparent inside.
//
// This strip used to hold the two HQ placement buttons. Placement now runs after the faction
// confirmation screen (client/dialog/fnc_hq_placement.sqf), so the only thing this screen still
// has to do is say when the player is done answering it.
class startup_faction_next_dialog
{
	idd = -1;
	movingenable = false;

	class controls
	{
		class faction_next_panel: RscText
		{
			idc = 1443;
			x = 3 * GUI_GRID_W + GUI_GRID_X;
			y = 12.7 * GUI_GRID_H + GUI_GRID_Y;
			w = 34 * GUI_GRID_W;
			h = 5.9 * GUI_GRID_H;
			colorBackground[] = {0.2, 0.4, 0.2, 1};
		};
		// Centred in the strip the two placement buttons used to share, so the panel still meets
		// the screen's frame at the same edge and the box does not have to be re-measured.
		class faction_next_button: RscButton
		{
			idc = 1600;
			text = "$STR_DUWS_T_xxci6q7d";
			x = 11 * GUI_GRID_W + GUI_GRID_X;
			y = 14.4 * GUI_GRID_H + GUI_GRID_Y;
			w = 18 * GUI_GRID_W;
			h = 2.5 * GUI_GRID_H;
			sizeEx = 0.05;
			colorBackground[] = {1, 0, 0, 0.5};
			tooltip = "$STR_DUWS_T_callsign_next_tt";
			action = "duws_faction_screen_next = true;";
		};
	};
};
