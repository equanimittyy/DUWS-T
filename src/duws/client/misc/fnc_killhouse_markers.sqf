// Locality: client -- inherited from client/client_init.sqf.
// Contact markers for the killhouse. The course is a ~70 m multi-floor structure, so a run
// whose last few contacts sit behind a wall would otherwise end with the player wandering it
// until they gave up. Icons draw over geometry; they fade out as the player closes, so the
// finding is assisted and the shooting is not.
if (!hasInterface) exitWith {};

// Marker tuning. Distances in metres, player to contact. Whether the markers run at all is a
// separate question, gated on killhouse_area_radius (server side) measuring player to centre.
killhouse_marker_max_range = 150;  // not drawn at all past this. The default clears the far
                                   // corner of the structure, so nothing is hidden until this
                                   // is deliberately tightened
killhouse_marker_fade_near = 5;    // fully transparent at or inside this range
killhouse_marker_fade_far  = 30;   // fully opaque at or beyond it
killhouse_marker_icon      = "\A3\ui_f\data\map\markers\military\dot_CA.paa";

// Draw3D, not the stacked onEachFrame that fnc_draw_HQicon uses: that file clears the whole
// stack with a bare `onEachFrame {}` once the player leaves the base, and leaving the base is
// exactly what teleporting into the killhouse does. A stacked handler here could be wiped at
// the moment it became useful. Draw3D is a separate mission event and cannot be clobbered.
addMissionEventHandler ["Draw3D", {
    private _khX = missionNamespace getVariable ["killhouse_centerX", nil];
    if (isNil "_khX") exitWith {};
    private _centre = [
        _khX,
        missionNamespace getVariable ["killhouse_centerY", 0],
        missionNamespace getVariable ["killhouse_centerZ", 0]
    ];
    if ((getPosWorld player) distance _centre > (missionNamespace getVariable ["killhouse_area_radius", 80])) exitWith {};

    {
        _x params ["_listVar", "_rgb"];
        {
            // Null-guarded because a hit contact leaves the list a couple of seconds before the
            // object is deleted, and a client's copy of the list can lag the server's either way.
            if (!isNull _x) then {
                private _dist = player distance _x;
                private _alpha = linearConversion [
                    killhouse_marker_fade_near, killhouse_marker_fade_far, _dist, 0, 1, true
                ];
                if (_alpha > 0 && { _dist <= killhouse_marker_max_range }) then {
                    drawIcon3D [
                        killhouse_marker_icon,
                        _rgb + [_alpha],
                        _x modelToWorldVisual [0, 0, 2],
                        0.6, 0.6, 0
                    ];
                };
            };
        } forEach (missionNamespace getVariable [_listVar, []]);
    } forEach [
        ["killhouse_targets", [0.35, 0.7, 1]],
        ["killhouse_enemies", [1, 0.25, 0.2]]
    ];
}];
