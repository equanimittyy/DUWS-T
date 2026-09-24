// Locality: client -- an fnc_debug_menu row handler, runs on whoever opened the menu. Toggles the OPCOM
// threat-grid overlay: the commander's own grid (friendly/enemy force per cell, the front line, each belief
// stamp and every tasking unit), a server-only picture the dev otherwise cannot see. Independent of the AoI toggle
// (fnc_debug_aoi_view) -- each owns its own marker set and clears only its own. A second call clears it.
// While up it re-requests on the OPCOM tick cadence so it tracks the live grid instead of freezing at the
// moment it opened. Re-checked against game_master because the function is broadcast to every client.
// English-only debug.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

// Flag, not marker presence, drives the toggle: a fast off/on before the first draw still reads as "up".
// Dropping it also stops the refresh loop.
if (missionNamespace getVariable ["DUWS_dbgOpcomOn", false]) exitWith {
    DUWS_dbgOpcomOn = false;
    { if ((_x find "duws_opcom_") == 0) then { deleteMarkerLocal _x } } forEach allMapMarkers;
    // Clear the delta state so a reopen rebuilds the lattice from scratch rather than reusing dropped markers.
    missionNamespace setVariable ["DUWS_dbgOpcomSig", []];
    missionNamespace setVariable ["DUWS_dbgOpcomBelN", 0];
    missionNamespace setVariable ["DUWS_dbgOpcomTaskN", 0];
    hint "OPCOM grid: overlay cleared.";
};

openMap [true, false];
DUWS_dbgOpcomOn = true;
// Generation token: a quick off/on can leave the old loop mid-sleep, so tag this loop and let only the
// newest run -- otherwise two loops double-request forever. 5s mirrors OPCOM_TICK_PERIOD, which is a
// server-only global and nil here.
private _gen = (missionNamespace getVariable ["DUWS_dbgOpcomGen", 0]) + 1;
DUWS_dbgOpcomGen = _gen;
[_gen] spawn {
    params ["_gen"];
    while {DUWS_dbgOpcomOn && {DUWS_dbgOpcomGen == _gen}} do {
        // Grid and belief store live only on the server, so they are gathered there and handed back to draw.
        // One request in flight: overlapping draws split the scheduler, each ran slower, and they piled up
        // until the overlay froze. The timeout covers a gather that sends nothing back (OPCOM init not finished).
        DUWS_dbgOpcomPending = true;
        [player] remoteExec ["fnc_debug_opcom_grid", 2];
        private _deadline = time + 30;
        waitUntil { sleep 0.5; !DUWS_dbgOpcomPending || {time > _deadline} };
        sleep 5;
    };
};
