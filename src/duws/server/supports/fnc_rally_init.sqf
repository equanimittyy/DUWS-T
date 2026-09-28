// Locality: server. Definition file (several functions), executed by the registry; the comm menu
// reaches fnc_rally_place with remoteExec [..., 2].
//
// One rally point stands at a time. The comm item defers its consume to here, so a placement the
// lockout refuses hands the item back instead of spending it. The placement is the whole run, so a
// spent one releases the caller's next copy at once.
//
// The flag is a fast-travel destination, not a respawn position: the trip is taken deliberately from
// a base, so the player arrives kitted and with their squad instead of naked off a death.
if (!isServer) exitWith {};

#define RALLY_TRAVELS 10
#define RALLY_LOCKOUT 600
#define RALLY_CLEAR_RADIUS 200

DUWS_rally_tent = objNull;
DUWS_rally_travels = 0;
DUWS_rally_unlockAt = 0;
DUWS_rally_id = 0;

fnc_rally_remove = {
    if (isNull DUWS_rally_tent) exitWith {};
    deleteVehicle DUWS_rally_tent;
    DUWS_rally_tent = objNull; publicVariable "DUWS_rally_tent";
    deleteMarker "duws_rally";
};

fnc_rally_place = {
    params ["_caller"];
    if (time < DUWS_rally_unlockAt) exitWith {
        [format [localize "STR_DUWS_T_RALLY_LOCKED", ceil ((DUWS_rally_unlockAt - time) / 60)]] remoteExec ["hint", _caller];
        ["rally_point"] remoteExec ["fnc_support_comm_add", _caller];
    };
    ["rally_point"] remoteExec ["fnc_support_consume", _caller];
    ["rally_point"] remoteExec ["fnc_support_comm_add", _caller];
    DUWS_rally_unlockAt = time + RALLY_LOCKOUT;
    [] call fnc_rally_remove;

    // Far enough ahead that the tent's hull does not spawn on top of the player who placed it.
    private _pos = _caller getRelPos [4, 0];
    private _tent = createVehicle ["Land_TentA_F", _pos, [], 0, "CAN_COLLIDE"];
    _tent setDir getDir _caller;
    DUWS_rally_tent = _tent; publicVariable "DUWS_rally_tent";
    // Broadcast: the fast-travel menu prints what is left beside the destination.
    DUWS_rally_travels = RALLY_TRAVELS; publicVariable "DUWS_rally_travels";
    DUWS_rally_id = DUWS_rally_id + 1;

    private _marker = createMarker ["duws_rally", _pos];
    _marker setMarkerType "hd_flag_noShadow";
    _marker setMarkerColor "ColorBLUFOR";
    _marker setMarkerText format [localize "STR_DUWS_T_RALLY_MARKER", RALLY_TRAVELS];

    ["INFO", "SUPPORT", format ["rally point placed at %1 by %2", _pos, name _caller]] call fnc_log;
    ["rally_placed"] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

    // The id tells a replacement, whose own rally must survive, from a loss.
    [_tent, DUWS_rally_id] spawn {
        params ["_tent", "_id"];
        waitUntil {
            sleep 5;
            isNull _tent || {(_tent nearEntities [["CAManBase", "LandVehicle"], RALLY_CLEAR_RADIUS])
                findIf { alive _x && {((side _x) getFriend west) < 0.6} } >= 0}
        };
        if (_id != DUWS_rally_id) exitWith {};
        // A live tent here means the loop broke on the enemy test, not on the rally already being gone.
        private _overrun = !isNull _tent;
        [] call fnc_rally_remove;
        if (_overrun) then {
            ["rally_lost"] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
        };
    };
};

fnc_rally_travelled = {
    params ["_tent"];
    // Null once replaced or lost: that trip is not the new rally's to pay.
    if (isNull _tent) exitWith {};
    DUWS_rally_travels = DUWS_rally_travels - 1;
    publicVariable "DUWS_rally_travels";
    if (DUWS_rally_travels <= 0) exitWith { [] call fnc_rally_remove };
    "duws_rally" setMarkerText format [localize "STR_DUWS_T_RALLY_MARKER", DUWS_rally_travels];
};
