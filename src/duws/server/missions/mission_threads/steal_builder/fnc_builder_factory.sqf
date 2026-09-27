// Locality: server. Outside the mission thread because the campaign restore enlists a builder too.

// Object handles, read to class, position and orientation only at the write: R3F lets a player move a build at any time.
DUWS_builds = [];

// The factory role is client-local, so it runs everywhere and stays as a JIP order for late joiners. The order is keyed
// by netId and dropped on the vehicle's death, so a later builder cannot clobber it and it never leaks.
DUWS_fnc_builderEnlist = {
    params ["_bld"];
    _bld setVariable ["DUWS_campaignFactory", true];
    private _jipId = format ["DUWS_bldFactory_%1", netId _bld];
    [_bld, {
        params ["_bld"];
        if (!hasInterface || isNull _bld) exitWith {};
        [_bld, -1, west, "LIGHT"] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
        [_bld, "mil_triangle", "ColorBlue", "2", "2", "BLD-V"] call kndr_assignMarker;
    }] remoteExec ["call", 0, _jipId];
    [_bld, _jipId] spawn {
        params ["_bld", "_jipId"];
        waitUntil { sleep 5; isNull _bld || !alive _bld };
        remoteExec ["", _jipId];
    };
    // Killed retires the key, so the record does not outlive the wreck.
    _bld addEventHandler ["Killed", { ["captured_builder"] call fnc_duws_release }];
    [_bld, "captured_builder"] call fnc_duws_keep;
};

// R3F's creer_objet calls this on every factory build. A mission crate's builds are that mission's and go with it.
DUWS_fnc_buildRegister = {
    params ["_obj", "_factory"];
    if (_factory getVariable ["DUWS_campaignFactory", false]) then { DUWS_builds pushBack _obj };
};
