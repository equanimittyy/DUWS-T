// Locality: client -- invoked from a dialog action (shared/includes/campaign_menu.hpp:338).
// NEXT on the campaign screen (startup_dialog2): read the campaign combos into their
// vars while the dialog is still open, snapshot the selections so the screen can
// restore them if the player returns via the callsign screen's Back, then advance to
// the callsign screen. Zone placement (random/manual) and the commit are chosen there.
[] call fnc_process_campaign_menu;

duws_campaign_sel = [2100,2101,2102,2103,2104,2106,2107,2108,2109,2110,2111,2112,2113,2114] apply { lbCurSel _x };
duws_campaign_forward = true;   // startup_dialog2's onUnload must not reopen the enviro screen
closeDialog 0;
[] spawn fnc_callsign_menu;
