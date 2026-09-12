// Locality: each client -- the furnisher remoteExecs it JIP-keyed on the piece (scroll actions are local).
// The nudge runs back on the server: PhysX velocity only takes on the owner, and furniture is server-created.
// The push is horizontal -- a vertical component would launch the piece.
params ["_obj"];
if (isNull _obj) exitWith {};
#define NUDGE 5   // TUNABLE, m/s

_obj addAction [
    localize "STR_DUWS_T_FURNISH_PUSH",
    {
        params ["_obj", "_who"];
        private _v = (getPosASL _obj) vectorDiff (getPosASL _who);
        _v set [2, 0];
        if (vectorMagnitude _v < 0.01) exitWith {};   // player inside the piece: no push direction
        [[_obj, (vectorNormalized _v) vectorMultiply NUDGE], { (_this select 0) setVelocity (_this select 1) }] remoteExec ["BIS_fnc_call", 2];
    },
    nil, 1.5, false, true, "",
    "true", 3
];
