// Locality: client -- inherited from client/client_init.sqf.
// Faint orange icon over each un-sabotaged sabotage-mission laptop within range. Fed by
// DUWS_sabotage_laptops (server, broadcast); an entry stops drawing once its laptop is sabotaged
// (DUWS_laptop_done) or the mission prunes it on end.
//
// Draw3D, not a stacked onEachFrame: `onEachFrame {}` clears the whole stack, so a Draw3D event keeps this
// independent of the HQ table and the killhouse markers (both in client/misc/).
if (!hasInterface) exitWith {};

// Label localised once, not per frame -- the Draw3D body below runs every frame.
DUWS_laptopMarker_range  = 50;                                                    // metres, player to laptop
DUWS_laptopMarker_icon   = "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa";
DUWS_laptopMarker_colour = [1, 0.5, 0, 0.5];                                      // orange, faint
DUWS_laptopMarker_label  = localize "STR_DUWS_T_p3200mf5";

addMissionEventHandler ["Draw3D", {
    {
        // isNull-guarded: a laptop can be deleted (keep-radius clock) a beat before the list is pruned, and
        // a client's list copy lags the server's.
        if (!isNull _x && {!(_x getVariable ["DUWS_laptop_done", false])} && {player distance _x <= DUWS_laptopMarker_range}) then {
            drawIcon3D [
                DUWS_laptopMarker_icon,
                DUWS_laptopMarker_colour,
                _x modelToWorldVisual [0, 0, 1.5],
                1, 1, 0,
                DUWS_laptopMarker_label, 1, 0.025, "TahomaB"
            ];
        };
    } forEach (missionNamespace getVariable ["DUWS_sabotage_laptops", []]);
}];
