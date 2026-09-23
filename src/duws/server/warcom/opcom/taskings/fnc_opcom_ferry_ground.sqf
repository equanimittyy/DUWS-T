// Locality: server, [] call'd at load, after fnc_opcom_ferry_devirt. A ground hull's live crossing: it boards and
// unloads like a rotor, but drives straight to within OPCOM_FERRY_BOARD_GROUND of the men and of the drop and stands on
// a HOLD, so it has no pickupland or dropland.
if (!isServer) exitWith {};

// The next leg's order clears the HOLD, so nothing lifts it by hand.
DUWS_fnc_opcom_ferryHoldHull = {
    private _here = getPosASL _veh;
    [_grp, "move", _here] call DUWS_fnc_opcom_applyOrder;
    (_grp addWaypoint [_here, 0]) setWaypointType "HOLD";
};

DUWS_fnc_opcom_ferryGroundRiders = {
    private _rg = call DUWS_fnc_opcom_ferryNewRiders;
    if (isNull _rg) exitWith {};
    [_rg, getPosASL _veh] call DUWS_fnc_opcom_ferryWalkAboard;
};

DUWS_fnc_opcom_ferryGroundDropLeg = {
    [_rider getOrDefault ["ferryLand", _t get "target"]] call DUWS_fnc_opcom_ferryLegTo;
};

DUWS_fnc_opcom_ferryGroundEmbark = {
    call DUWS_fnc_opcom_ferryEmbarkRider;
    [_veh] call DUWS_fnc_opcom_ferryClearHull;
    call DUWS_fnc_opcom_ferryGroundDropLeg;
    ["carry"] call DUWS_fnc_opcom_ferrySetPhase;
};

DUWS_opcom_ferryHulls set ["ground", createHashMapFromArray [
    ["topickup", {
        if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { [_rider get "pos"] call DUWS_fnc_opcom_ferryLegTo };
        if ((_veh distance2D (_rider get "pos")) < OPCOM_FERRY_BOARD_GROUND) then {
            _rider set ["ferryFrozen", true];       // board commit
            if ((_rider get "grp") isEqualTo "") exitWith { call DUWS_fnc_opcom_ferryGroundEmbark };
            call DUWS_fnc_opcom_ferryHoldHull;
            ["pickupboard"] call DUWS_fnc_opcom_ferrySetPhase;
        };
    }],
    ["pickupboard", { [DUWS_fnc_opcom_ferryGroundRiders, DUWS_fnc_opcom_ferryGroundEmbark] call DUWS_fnc_opcom_ferryWalkBoard }],
    ["carry", {
        _rider set ["pos", _tpos];
        if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { call DUWS_fnc_opcom_ferryGroundDropLeg };   // live spell resumed mid-carry
        if ((_veh distance2D (_t get "ferryLZ")) < OPCOM_FERRY_BOARD_GROUND) then {
            call DUWS_fnc_opcom_ferryHoldHull;
            if !(call DUWS_fnc_opcom_ferryDropBoard) exitWith {};
            ["dropunload"] call DUWS_fnc_opcom_ferrySetPhase;
            [false] call DUWS_fnc_opcom_ferryUnloadPaced;
        };
    }],
    ["dropunload", { [call DUWS_fnc_opcom_ferryWaitTick] call DUWS_fnc_opcom_ferryUnloadEnd }]
]];
