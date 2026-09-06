// Locality: client -- inherited from client/client_init.sqf.
// Small yellow "?" icon over every roadside-IED pile within range, live or decoy alike, so the two cannot be
// told apart (fnc_random_event_ied). The pile is a question, not a confirmed threat -- a maybe-IED to weigh,
// not a known enemy. Fed by DUWS_ied_piles (server, broadcast); a pile stops drawing once its DUWS_ied_active
// clears (defuse or trip) or it is deleted at field teardown.
//
// Draw3D, not a stacked onEachFrame: `onEachFrame {}` clears the whole stack, so a Draw3D event keeps this
// independent of the other marker handlers (client/killhouse, client/missions).
if (!hasInterface) exitWith {};

DUWS_iedMarker_range = 50;                                                      // metres, player to pile
DUWS_iedMarker_icon  = "\A3\ui_f\data\map\markers\military\unknown_CA.paa";     // marker 266, mil_unknown (docs/info/external/arma3_markers.md)
DUWS_iedMarker_colour = [1, 1, 0, 1];                                           // yellow, fully opaque

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
                0.8, 0.8, 0
            ];
        };
    } forEach (missionNamespace getVariable ["DUWS_ied_piles", []]);
}];
