// Locality: server. Definition file (several functions), executed by the registry; the comm menu
// reaches fnc_rally_place with remoteExec [..., 2].
//
// One rally point stands at a time. The comm item defers its consume to here, so a placement the
// lockout refuses hands the item back instead of spending it.
if (!isServer) exitWith {};

#define RALLY_SPAWNS 10
#define RALLY_LOCKOUT 600
#define RALLY_CLEAR_RADIUS 200

DUWS_rally_flag = objNull;
DUWS_rally_respawn = [];
DUWS_rally_spawns = 0;
DUWS_rally_unlockAt = 0;
DUWS_rally_id = 0;

fnc_rally_remove = {
    if (DUWS_rally_respawn isEqualTo []) exitWith {};
    DUWS_rally_respawn call BIS_fnc_removeRespawnPosition;
    DUWS_rally_respawn = [];
    deleteVehicle DUWS_rally_flag;
    DUWS_rally_flag = objNull; publicVariable "DUWS_rally_flag";
    deleteMarker "duws_rally";
};

fnc_rally_place = {
    params ["_caller"];
    if (time < DUWS_rally_unlockAt) exitWith {
        [format [localize "STR_DUWS_T_RALLY_LOCKED", ceil ((DUWS_rally_unlockAt - time) / 60)]] remoteExec ["hint", _caller];
        ["rally_point"] remoteExec ["fnc_support_comm_add", _caller];
    };
    ["rally_point"] remoteExec ["fnc_support_consume", _caller];
    DUWS_rally_unlockAt = time + RALLY_LOCKOUT;
    [] call fnc_rally_remove;

    private _pos = _caller getRelPos [1, 0];
    private _flag = createVehicle ["FlagChecked_F", _pos, [], 0, "CAN_COLLIDE"];
    DUWS_rally_flag = _flag; publicVariable "DUWS_rally_flag";
    DUWS_rally_respawn = [west, _flag, localize "STR_DUWS_T_RALLY_POINT"] call BIS_fnc_addRespawnPosition;
    DUWS_rally_spawns = RALLY_SPAWNS;
    DUWS_rally_id = DUWS_rally_id + 1;

    private _marker = createMarker ["duws_rally", _pos];
    _marker setMarkerType "hd_flag_noShadow";
    _marker setMarkerColor "ColorBLUFOR";
    _marker setMarkerText format [localize "STR_DUWS_T_RALLY_MARKER", RALLY_SPAWNS];

    ["INFO", "SUPPORT", format ["rally point placed at %1 by %2", _pos, name _caller]] call fnc_log;
    ["rally_placed"] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

    // The id tells a replacement, whose own rally must survive, from a loss.
    [_flag, DUWS_rally_id] spawn {
        params ["_flag", "_id"];
        waitUntil {
            sleep 5;
            isNull _flag || {(_flag nearEntities [["CAManBase", "LandVehicle"], RALLY_CLEAR_RADIUS])
                findIf { alive _x && {((side _x) getFriend west) < 0.6} } >= 0}
        };
        if (_id == DUWS_rally_id) then { [] call fnc_rally_remove };
    };
};

fnc_rally_spawned = {
    params ["_flag"];
    // Null once replaced or lost: that respawn is not the new rally's to pay.
    if (isNull _flag) exitWith {};
    DUWS_rally_spawns = DUWS_rally_spawns - 1;
    if (DUWS_rally_spawns <= 0) exitWith { [] call fnc_rally_remove };
    "duws_rally" setMarkerText format [localize "STR_DUWS_T_RALLY_MARKER", DUWS_rally_spawns];
};
