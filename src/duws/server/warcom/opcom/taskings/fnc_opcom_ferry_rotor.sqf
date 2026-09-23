// Locality: server, [] call'd at load, after fnc_opcom_ferry_devirt. A rotor's live crossing: it lands on a helipad at
// both ends, walking the squad aboard with the skids down and out a man every two seconds.
if (!isServer) exitWith {};

// fnc_rescue_squad_success's put-down: the helipad makes `land` settle on the spot rather than hover over a pick of
// its own, a pinned pilot neither flees nor breaks off to engage, and Vcm_Disable keeps VCOM, when loaded, off the
// scripted waypoints. The pin follows the move, whose applyOrder resets behaviour.
DUWS_fnc_opcom_ferryRotorLeg = {
    params ["_near"];
    private _p = +([_near, 80, 0, 8, 0.3] call fnc_safe_pos); _p set [2, 0];
    [_t] call DUWS_fnc_opcom_ferryClearPad;
    _t set ["ferryPad", netId (createVehicle ["Land_HelipadEmpty_F", _p, [], 0, "NONE"])];
    [_p] call DUWS_fnc_opcom_ferryLegTo;
    _grp setBehaviour "CARELESS"; _grp setCombatMode "BLUE";
    { _x setVariable ["Vcm_Disable", true] } forEach units _grp;
    private _pilot = currentPilot _veh;
    _pilot allowFleeing 0; _pilot disableAI "Target";
};

// Off the LZ, not onto it: a rotor sets down where these men stand. Assignment is what the "GET IN" hold waits on and
// it moves nobody, so the walk-aboard order waits for the skids, in pickupboard.
DUWS_fnc_opcom_ferryRotorRiders = {
    private _rg = call DUWS_fnc_opcom_ferryNewRiders;
    if (isNull _rg) exitWith {};
    private _lz = _t get "ferryLZ";
    [_rg, _lz getPos [OPCOM_FERRY_STAGE, _lz getDir (leader _rg)]] call DUWS_fnc_opcom_ferryWalkAboard;
};

DUWS_fnc_opcom_ferryRotorEmbark = {
    call DUWS_fnc_opcom_ferryEmbarkRider;
    [_veh] call DUWS_fnc_opcom_ferryClearHull;
    _veh land "NONE";   // release the landing hold so it lifts off
    [_t get "target"] call DUWS_fnc_opcom_ferryRotorLeg;
    ["carry"] call DUWS_fnc_opcom_ferrySetPhase;
};

DUWS_opcom_ferryHulls set ["rotor", createHashMapFromArray [
    ["topickup", {
        if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { [_rider get "pos"] call DUWS_fnc_opcom_ferryRotorLeg };
        if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
            // Seat them before the call: "GET IN" keeps the engine turning where "LAND" shuts it down, but with nobody
            // assigned its hold completes at once and the hull lifts straight off again.
            call DUWS_fnc_opcom_ferryRotorRiders;
            _veh land "GET IN";
            _rider set ["ferryFrozen", true];       // board commit
            ["pickupland"] call DUWS_fnc_opcom_ferrySetPhase;
        };
    }],
    // The gate above is one grid cell wide and reads no altitude, so the men are ordered in from pickupboard: ordered
    // here they walk out to a hull still hundreds of metres up, on the board's clock.
    ["pickupland", {
        private _wait = call DUWS_fnc_opcom_ferryWaitTick;
        call DUWS_fnc_opcom_ferryRotorRiders;   // a group re-streamed mid-descent is a new one, and its seats died with the old
        if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
            // A virtual rider has no one to walk in and boards on touchdown.
            if ((_rider get "grp") isEqualTo "") then { call DUWS_fnc_opcom_ferryRotorEmbark } else { ["pickupboard"] call DUWS_fnc_opcom_ferrySetPhase };
        };
        if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call DUWS_fnc_opcom_ferryRotorEmbark };
    }],
    ["pickupboard", { [DUWS_fnc_opcom_ferryRotorRiders, DUWS_fnc_opcom_ferryRotorEmbark] call DUWS_fnc_opcom_ferryWalkBoard }],
    ["carry", {
        _rider set ["pos", _tpos];
        if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { [_t get "target"] call DUWS_fnc_opcom_ferryRotorLeg };   // live spell resumed mid-carry
        if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
            if (call DUWS_fnc_opcom_ferryDropBoard) then { _veh land "GET OUT" };
            ["dropland"] call DUWS_fnc_opcom_ferrySetPhase;
        };
    }],
    ["dropland", {
        _rider set ["pos", _tpos];
        private _wait = call DUWS_fnc_opcom_ferryWaitTick;
        if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
            // No land mode holds a hull for a whole dismount: its waypoint reached and its hold spent, the pilot climbs
            // back to flyInHeight and hovers over the pad. Take away the height it wants.
            _veh flyInHeight 0;
            ["dropunload"] call DUWS_fnc_opcom_ferrySetPhase;
            [true] call DUWS_fnc_opcom_ferryUnloadPaced;
        };
        if (_wait >= OPCOM_FERRY_WAIT_MAX) exitWith { call DUWS_fnc_opcom_ferryDropGround; [_t] call DUWS_fnc_opcom_ferryRelease };
    }],
    ["dropunload", {
        private _wait = call DUWS_fnc_opcom_ferryWaitTick;
        // The pin failed and men are still to come out: set them down rather than let the drop finish at height.
        if ((((getPosATL _veh) select 2) >= OPCOM_FERRY_GROUND_ALT) && {[_veh] call DUWS_fnc_opcom_ferryUnloadPending}) exitWith {
            call DUWS_fnc_opcom_ferryDropGround;
            [_t] call DUWS_fnc_opcom_ferryRelease;
        };
        [_wait] call DUWS_fnc_opcom_ferryUnloadEnd;
    }]
]];
