// Empty on purpose, and still opened. The faction setup screen is built on an RscDisplayEmpty
// (client/dialog/fnc_HQ_faction_dialog.sqf) and a display created that way takes no mouse cursor;
// having a dialog open beside it is what makes that screen clickable at all, and has been since it
// was written. Every control the player sees lives on the display, because a panel on one surface
// and a button on the other cannot be relied on to draw in the order they were made
// (docs/info/arma_engine_gotchas.md).
class startup_hq_placement_dialog
{
	idd = -1;
	movingenable = false;

	class controls {};
};
