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

createDialog "startup_hq_placement_dialog";
waitUntil { dialog };

waitUntil { sleep 0.1; random_placement || player_is_choosing_hqpos };
closeDialog 0;

// So the player can see the map to click on. The random roll needs no reveal of its own, but it
// costs nothing there and the fade is what the next screen opens over either way.
titleCut ["", "BLACK IN", 5];

// Both paths end here: the random roll publishes the flag from fnc_HQ_random_place and the manual
// path from the map click, so one wait covers the pair.
waitUntil { sleep 0.1; chosen_hq_placement };
