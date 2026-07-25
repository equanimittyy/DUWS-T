// Locality: client -- invoked from a dialog action (shared/includes/enviro_menu.hpp:309).
// Environment screen (startup_dialog) Back button -> re-pick faction + HQ.
// Snapshot selections (restored when the flow returns to this screen), flag the
// reopen, then close. startup_dialog's onUnload (fnc_startup_enviro_closed)
// routes to fnc_startup_faction_flow because chosen_settings is still false.
// Selections must be read before closeDialog while the controls still exist.
duws_enviro_sel = [2100,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2111] apply { lbCurSel _x };
duws_faction_reselect = true;
closeDialog 0;
