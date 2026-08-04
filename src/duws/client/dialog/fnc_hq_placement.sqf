// Locality: client -- inherited from client/dialog/fnc_startup_faction_flow.sqf.
//
// HQ placement: the two buttons, and the wait for whichever one the player picks to finish.
//
// This used to be the tail of fnc_HQ_faction_dialog, run while the faction screen was still on
// screen. It sits after the confirmation screen instead so the campaign's rosters are settled
// before the player is asked to commit to a position -- stepping back from the confirmation screen
// re-picks factions, and a base placed ahead of that would have been placed against a roster the
// player then changed.
//
// Cleared before the dialog opens, because a click is live the moment the buttons exist.
random_placement = false;
player_is_choosing_hqpos = false;

if (!createDialog "startup_hq_placement_dialog") exitWith {
    ["ERROR", "BOOT", "HQ placement screen failed to open; the campaign has nowhere to build."] call fnc_log;
};
waitUntil { dialog };

private _display = uiNamespace getVariable ["duws_hq_placement_display", displayNull];
if (!isNull _display) then {
    (_display displayCtrl 1440) ctrlSetFont "PuristaMedium";
    (_display displayCtrl 1441) ctrlSetStructuredText parseText format ["<t size='0.85'>%1</t>",
        localize "STR_DUWS_T_hq_place_intro"];
};

// Both button actions close this dialog themselves, so there is nothing to close here -- and a
// closeDialog at this point would take whatever the manual path opened next instead.
waitUntil { sleep 0.1; random_placement || player_is_choosing_hqpos };

// So the player can see the map to click on. The random roll needs no reveal of its own, but it
// costs nothing there and the fade is what the next screen opens over either way.
titleCut ["", "BLACK IN", 5];

// Both paths end here: the random roll publishes the flag from fnc_HQ_random_place and the manual
// path from the map click, so one wait covers the pair.
waitUntil { sleep 0.1; chosen_hq_placement };
