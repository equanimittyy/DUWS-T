// Locality: client -- inherited from client/client_init.sqf.
// Small yellow "?" icon over every roadside-IED pile within range, live or decoy alike, so the two cannot be
// told apart (fnc_random_event_ied). The pile is a question, not a confirmed threat -- a maybe-IED to weigh,
// not a known enemy. Fed by DUWS_ied_piles (server, broadcast); a pile stops drawing once its DUWS_ied_active
// clears (defuse or trip) or it is deleted at field teardown.
//
// The VBIED car (fnc_random_event_car_bomb) draws off DUWS_vbied_cars instead: an OPFOR-red icon, not the
// covert yellow "?", because the car is an overt, known threat -- and out to a longer range so the player
// reads it closing before it reaches them (the car's honk was unreliable).
//
// Draw3D, not a stacked onEachFrame: `onEachFrame {}` clears the whole stack, so a Draw3D event keeps this
// independent of the other marker handlers (client/killhouse, client/missions).
if (!hasInterface) exitWith {};

DUWS_iedMarker_range   = 15;                                                    // metres, player to pile
DUWS_vbiedMarker_range = 100;                                                   // metres -- read the moving car further out
DUWS_iedMarker_icon  = "\A3\ui_f\data\map\markers\military\unknown_CA.paa";     // marker 266, mil_unknown (docs/info/external/arma3_markers.md)
DUWS_iedMarker_colour = [1, 1, 0, 1];                                           // yellow; alpha set per-frame by distance
DUWS_iedMarker_full  = 0;                                                       // metres -- fully opaque here, fading to 5% at _range
// VBIED is overt, a known threat: OPFOR's own red, read from the engine so it tracks the side colour.
DUWS_vbiedMarker_icon   = "\A3\ui_f\data\map\mapcontrol\Bunker_CA.paa";         // marker 168, loc_Fortress (docs/info/external/arma3_markers.md)
DUWS_vbiedMarker_colour = +(east call BIS_fnc_sideColor);                       // RGB only; alpha set per-frame by distance
DUWS_vbiedMarker_full   = 30;                                                   // metres -- fully opaque here (the car's ARM_RANGE), fading to 5% at _range

addMissionEventHandler ["Draw3D", {
    {
        // isNull-guarded: a pile is deleted on defuse, trip or teardown a beat before the broadcast list is
        // pruned, and a client's list copy lags the server's. DUWS_ied_active drops at trip, so the icon
        // clears the instant a live pile is committed to blowing, ahead of the fuse deleting the pile.
        if (!isNull _x
            && {_x getVariable ["DUWS_ied_active", false]}
            && {player distance _x <= DUWS_iedMarker_range}) then {
            // Fade in as the player nears: 5% opaque at _range, solid by _full. Copy the colour so the
            // per-frame alpha is not baked into the shared global.
            private _c = +DUWS_iedMarker_colour;
            _c set [3, linearConversion [DUWS_iedMarker_full, DUWS_iedMarker_range, player distance _x, 1, 0.05, true]];
            drawIcon3D [
                DUWS_iedMarker_icon,
                _c,
                _x modelToWorldVisual [0, 0, 0.5],   // vertical centre of the low pile
                0.45, 0.45, 0
            ];
        };
    } forEach (missionNamespace getVariable ["DUWS_ied_piles", []]);
}];

addMissionEventHandler ["Draw3D", {
    {
        // isNull-guarded: the car is dropped from the list on detonation or teardown a beat before a client's
        // list copy catches up.
        if (!isNull _x && {player distance _x <= DUWS_vbiedMarker_range}) then {
            // Fade in as it closes: 5% opaque at _range, solid by _full (the arming distance) -- a far car is a
            // faint warning, a near one unmissable.
            private _c = +DUWS_vbiedMarker_colour;
            _c set [3, linearConversion [DUWS_vbiedMarker_full, DUWS_vbiedMarker_range, player distance _x, 1, 0.05, true]];
            drawIcon3D [
                DUWS_vbiedMarker_icon,
                _c,
                _x modelToWorldVisual [0, 0, 1.5],   // above the car roof
                0.5, 0.5, 0
            ];
        };
    } forEach (missionNamespace getVariable ["DUWS_vbied_cars", []]);
}];
