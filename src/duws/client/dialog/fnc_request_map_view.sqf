// Locality: client -- a dialog button action, so it runs on whoever pressed it.
//
// View Map from inside the request menu, which the HQ board used to own alone. The dialog cannot
// stay up over it: a dialog draws on top of the map display, so the readout would be answered onto
// a screen nobody can see. So it comes down, and goes back up when the map closes -- the player
// closing the map is coming back to the menu, not leaving it.
//
// Spawned, never called: it waits on the map twice.
if (!hasInterface) exitWith {};

closeDialog 0;
call fnc_map_readout_open;

// Bounded, because the readout refuses to open while another map mode holds the click claim. On a
// refusal there is no map to wait for and the menu goes straight back up. Real time rather than
// mission time: this is a UI wait and must not stretch with a time multiplier.
private _deadline = diag_tickTime + 3;
waitUntil { visibleMap || {diag_tickTime > _deadline} };
if (visibleMap) then { waitUntil { !visibleMap } };

// Re-opened on the base it was opened from, which the command column needs: a redeploy rebuilds
// that base's garrison, so a menu that came back as the HQ's would spend on the wrong one.
(uiNamespace getVariable ["DUWS_requestMenu_ctx", []]) params [["_site", objNull], ["_isFob", false]];
[_site, player, 0, [_isFob]] call fnc_request_menu;
