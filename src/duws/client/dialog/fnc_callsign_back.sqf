// Locality: client -- invoked from a dialog action (includes/callsign_menu.hpp:101).
// Callsign screen (startup_dialog3) Back -> return to the campaign params screen.
// Keep whatever was typed (unless blank) so coming forward again restores it; the
// campaign screen restores its own combos from duws_campaign_sel. Read before
// closeDialog while the edit control still exists.
private _typed = ctrlText 1400;
if (_typed != "") then { duws_callsign = _typed; };
closeDialog 0;
[] spawn fnc_campaign_menu;
