// Locality: client -- invoked from a dialog action (includes/campaign_menu.hpp:349).
// Campaign screen (startup_dialog2) Back button -> return to the environment screen.
// Snapshot the combo selections first so fnc_campaign_menu restores them when the
// player comes forward again; then closeDialog. startup_dialog2's onUnload
// (fnc_startup_closed) reopens the environment menu because chosen_settings is
// still false at this point. Selections must be read before closeDialog: the
// controls are gone once the dialog tears down.
duws_campaign_sel = [2100,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2111,2112,2113] apply { lbCurSel _x };
closeDialog 0;
