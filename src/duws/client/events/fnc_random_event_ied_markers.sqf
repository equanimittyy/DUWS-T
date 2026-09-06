// Locality: client -- inherited from client/client_init.sqf.
// Small OPFOR-red icon over every roadside-IED pile within range, live or decoy alike, so the two cannot be
// told apart (fnc_random_event_ied). Fed by DUWS_ied_piles (server, broadcast); a pile stops drawing once
// its DUWS_ied_active clears (defuse or trip) or it is deleted at field teardown.
//
// Draw3D, not a stacked onEachFrame: `onEachFrame {}` clears the whole stack, so a Draw3D event keeps this
// independent of the other marker handlers (client/killhouse, client/missions).
if (!hasInterface) exitWith {};

DUWS_iedMarker_range = 50;                                             // metres, player to pile
DUWS_iedMarker_icon  = "\A3\ui_f\data\map\mapcontrol\Bunker_CA.paa";   // marker 168, loc_Fortress (docs/info/external/arma3_markers.md)
// OPFOR's own red, read from the engine so it tracks the side colour every other surface uses.
DUWS_iedMarker_colour = +(east call BIS_fnc_sideColor);
DUWS_iedMarker_colour set [3, 0.9];

addMissionEventHandler ["Draw3D", {
    {
        // isNull-guarded: a pile is deleted on defuse, trip or teardown a beat before the broadcast list is
        // pruned, and a client's list copy lags the server's. DUWS_ied_active drops at trip, so the icon
        // clears the instant a live pile is committed to blowing, ahead of the fuse deleting the pile.
        if (!isNull _x
            && {_x getVariable ["DUWS_ied_active", false]}
            && {player distance _x <= DUWS_iedMarker_range}) then {
            drawIcon3D [
                DUWS_iedMarker_icon,
                DUWS_iedMarker_colour,
                _x modelToWorldVisual [0, 0, 0.5],   // vertical centre of the low pile
                0.4, 0.4, 0
            ];
        };
    } forEach (missionNamespace getVariable ["DUWS_ied_piles", []]);
}];
