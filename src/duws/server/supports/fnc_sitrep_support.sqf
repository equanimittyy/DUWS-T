// Locality: client -- the comm-menu item runs on the machine that activated it, which is why
// every line below broadcasts outward. SITREP is free: no spend, so no refusal path.

// Saving is server work, so it is asked for rather than confirmed. This sat behind an
// if (isServer) test wrapping a BIS_fnc_guiMessage prompt: on a dedicated server no client
// passes that test, so the save never ran at all, and on a hosted game only the host was ever
// asked for it. Everyone gets the same save.
[] remoteExec ["fnc_autoSave", 2];
["sitrepinfo", [localize "STR_DUWS_T_qkkva9tk", localize "STR_DUWS_T_biham0s3"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

// Through the server rather than broadcast straight to fnc_sitrep_display: the hint's reputation
// line is per player, and only the server can resolve it.
[] remoteExec ["fnc_sitrep_fanout", 2];

[] remoteExec ["fnc_bottom_right_message", 0];
[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_sitrep"] remoteExec ["fnc_duws_dialogue", 0];
