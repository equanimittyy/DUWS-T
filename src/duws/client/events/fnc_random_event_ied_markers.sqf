// Locality: client -- inherited from client/client_init.sqf.
// OPFOR-red icon over every VBIED car within range (fnc_random_event_car_bomb), fed by DUWS_vbied_cars
// (server, broadcast). The car is an overt, known threat, marked out to a longer range so the player reads it
// closing before it reaches them (the car's honk was unreliable). Roadside-IED piles carry no world icon.
//
// Draw3D, not a stacked onEachFrame: `onEachFrame {}` clears the whole stack, so a Draw3D event keeps this
// independent of the other marker handlers (client/killhouse, client/missions).
if (!hasInterface) exitWith {};

DUWS_vbiedMarker_range = 100;                                                   // metres -- read the moving car further out
// VBIED is overt, a known threat: OPFOR's own red, read from the engine so it tracks the side colour.
DUWS_vbiedMarker_icon   = "\A3\ui_f\data\map\mapcontrol\Bunker_CA.paa";         // marker 168, loc_Fortress (docs/info/external/arma3_markers.md)
DUWS_vbiedMarker_colour = +(east call BIS_fnc_sideColor);                       // RGB only; alpha set per-frame by distance
DUWS_vbiedMarker_full   = 30;                                                   // metres -- fully opaque here (the car's ARM_RANGE), fading to 5% at _range

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
