// Locality: server, [] call'd at load. The virtual ferry crossing -- the whole carry stepped as store math while
// nobody watches, driven each tick by the orchestrator (fnc_opcom_ferry). The live mirror is fnc_opcom_ferry_devirt
// (docs/plans/opcom/opcom_plan.md §Transport).
if (!isServer) exitWith {};

// One tick of the virtual carry. Returns the bound rider record while it stands, else nil (rider gone, or ferry done).
DUWS_fnc_opcom_ferryStep = {
    params ["_t"];
    private _rider = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    if (isNil "_rider" || {((_rider get "status") in ["dead", "done"]) || {(_rider get "ridingOn") != (_t get "id")}}) exitWith {
        _t set ["carrying", -1]; _t set ["embarked", false]; nil
    };
    if (!(_t get "embarked")) then {
        _t set ["target", [_t, _rider get "pos"] call DUWS_fnc_opcom_ferryApproach];
        if (((_t get "pos") distance2D (_t get "target")) <= OPCOM_GRID_CELL) then {
            // Nobody watches the virtual carry, so board-despawn the rider as it embarks (the live path renders boarding).
            private _rg = groupFromNetId (_rider get "grp");
            if (!isNull _rg) then {
                { deleteVehicle _x } forEach units _rg; deleteGroup _rg;
                _rider set ["grp", ""]; _rider set ["status", "virtual"];
            };
            _t set ["embarked", true];
            private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop;
            _rider set ["ferryLand", _drop];
            _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach];
            _t set ["route", []];
            ["INFO", "OPCOM", format ["ferry: transport %1 (%2) boards rider %3 (virtual)", _t get "id", _t get "moveType", _rider get "id"]] call fnc_log;
        } else {
            [_t] call DUWS_fnc_opcom_advance;
        };
    };
    if (_t get "embarked") then {
        private _arrived = ([_t] call DUWS_fnc_opcom_advance) isEqualTo "arrived";
        _rider set ["pos", _t get "pos"];
        if (_arrived) exitWith {
            _rider set ["pos", _rider getOrDefault ["ferryLand", _t get "pos"]];
            // Off-screen drop skips ferryRelease, so thaw the freeze here (a live board may have set it).
            _rider set ["ridingOn", -1]; _rider set ["route", []]; _rider set ["ferryFrozen", false];
            // A boat backs off to navigable water so it never routes, rests or de-virt spawns from land.
            private _tpos = _t get "pos";
            if ((_t get "moveType") isEqualTo "boat") then { _tpos = [_tpos] call DUWS_fnc_opcom_nearestWater };
            _t set ["pos", _tpos]; _t set ["carrying", -1]; _t set ["embarked", false];
            ["INFO", "OPCOM", format ["ferry: transport %1 (%2) drops rider %3 at %4 (virtual)", _t get "id", _t get "moveType", _rider get "id", (_rider get "pos") apply { round _x }]] call fnc_log;
            [_t] call DUWS_fnc_opcom_ferryHome;
            nil
        };
    };
    _rider
};
