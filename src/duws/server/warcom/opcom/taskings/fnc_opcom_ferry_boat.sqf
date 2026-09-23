// Locality: server, [] call'd at load, after fnc_opcom_ferry_devirt. A boat's live crossing: it parks off the shore
// and swaps the whole group at once at both ends, because boats are finnicky.
if (!isServer) exitWith {};

// A boat's live [shore, park]: the water-cell centre can sit ~350 m out, past any board range. The park is capped
// at that centre, which is water by construction (grid_init samples each cell centre), though not always deep.
DUWS_fnc_opcom_ferryBoatPark = {
    params ["_landPt", "_waterPt"];
    private _dir = _landPt getDir _waterPt;
    private _len = _landPt distance2D _waterPt;
    private _shore = 0;
    for "_d" from 0 to _len step 10 do {
        if !(surfaceIsWater (_landPt getPos [_d, _dir])) then { _shore = _d };
    };
    [_landPt getPos [_shore, _dir], _landPt getPos [(_shore + OPCOM_FERRY_BOAT_PARK) min _len, _dir]]
};

DUWS_fnc_opcom_ferryBoatRiders = {
    private _rg = call DUWS_fnc_opcom_ferryNewRiders;
    if (isNull _rg) exitWith {};
    private _shore = _t get "ferryShore";
    [_rg, "move", _shore] call DUWS_fnc_opcom_applyOrder;
    (_rg addWaypoint [_shore, 0]) setWaypointType "HOLD";
};

DUWS_fnc_opcom_ferryBoatDropLeg = {
    [([_rider get "ferryLand", _t get "target"] call DUWS_fnc_opcom_ferryBoatPark) select 1] call DUWS_fnc_opcom_ferryLegTo;
};

DUWS_fnc_opcom_ferryBoatEmbark = {
    _rider set ["ferryFrozen", true];       // board commit
    call DUWS_fnc_opcom_ferryEmbarkRider;
    call DUWS_fnc_opcom_ferryBoatDropLeg;
    ["carry"] call DUWS_fnc_opcom_ferrySetPhase;
};

DUWS_opcom_ferryHulls set ["boat", createHashMapFromArray [
    ["topickup", {
        if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then {
            private _rpos = _rider get "pos";
            ([_rpos, [_rpos] call DUWS_fnc_opcom_nearestWater] call DUWS_fnc_opcom_ferryBoatPark) params ["_shore", "_park"];
            _t set ["ferryShore", _shore];
            [_park] call DUWS_fnc_opcom_ferryLegTo;
        };
        call DUWS_fnc_opcom_ferryBoatRiders;
        if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
            ["pickupland"] call DUWS_fnc_opcom_ferrySetPhase;
        };
    }],
    ["pickupland", {
        private _wait = call DUWS_fnc_opcom_ferryWaitTick;
        call DUWS_fnc_opcom_ferryBoatRiders;
        if ((_veh distance2D (_t get "ferryLZ")) < OPCOM_FERRY_BOARD_BOAT) exitWith { ["pickupboard"] call DUWS_fnc_opcom_ferrySetPhase };
        if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call DUWS_fnc_opcom_ferryBoatEmbark };
    }],
    ["pickupboard", {
        private _wait = call DUWS_fnc_opcom_ferryWaitTick;
        call DUWS_fnc_opcom_ferryBoatRiders;
        private _rg = groupFromNetId (_rider get "grp");
        private _here = !isNull _rg && {((leader _rg) distance2D (_t get "ferryShore")) < OPCOM_FERRY_BOARD_BOAT};
        if (isNull _rg || _here || {_wait >= OPCOM_FERRY_WAIT_MAX}) then { call DUWS_fnc_opcom_ferryBoatEmbark };
    }],
    ["carry", {
        _rider set ["pos", _tpos];
        if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { call DUWS_fnc_opcom_ferryBoatDropLeg };   // live spell resumed mid-carry
        if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
            ["dropland"] call DUWS_fnc_opcom_ferrySetPhase;
        };
    }],
    ["dropland", {
        _rider set ["pos", _tpos];
        private _wait = call DUWS_fnc_opcom_ferryWaitTick;
        if (((_veh distance2D (_t get "ferryLZ")) < OPCOM_FERRY_BOARD_BOAT) || {_wait >= OPCOM_FERRY_WAIT_MAX}) then { ["dropunload"] call DUWS_fnc_opcom_ferrySetPhase };
    }],
    ["dropunload", {
        [_rider getOrDefault ["ferryLand", _t get "target"]] call DUWS_fnc_opcom_ferryDropSpawn;
        [_t] call DUWS_fnc_opcom_ferryRelease;
    }]
]];
