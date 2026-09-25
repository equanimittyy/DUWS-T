// Locality: server, [] call'd at load. Intents: a committed action's record, holding each unit it sends in a role so
// no later pick draws it away mid-action (opcom_plan.md §Orchestration). A role names its unit by tasking id, never
// the record, so an intent serialises on the taskings' own terms.
if (!isServer) exitWith {};

DUWS_fnc_opcom_intentBind = {
    params ["_intent", "_role", "_t"];
    _role set ["unit", _t get "id"];
    _t set ["boundTo", _intent get "id"];
};

// _t takes the first role. _roles: [[role, rally, required], ...], one per unit the intent binds; a role past the
// first stays open for a later pick to fill.
DUWS_fnc_opcom_intentOpen = {
    params ["_action", "_target", "_t", ["_roles", []], ["_state", "execution"], ["_pos", []], ["_label", ""]];
    if (_roles isEqualTo []) then { _roles = [[_action, [], true]] };
    private _id = DUWS_opcom_intentSeq;
    DUWS_opcom_intentSeq = _id + 1;
    private _intent = createHashMapFromArray [
        ["id", _id], ["action", _action], ["target", _target], ["pos", _pos], ["label", _label],
        ["state", _state], ["since", DUWS_opcom_tick],
        ["roles", _roles apply {
            _x params ["_role", "_rally", "_required"];
            createHashMapFromArray [["role", _role], ["unit", -1], ["rally", _rally], ["required", _required]]
        }]
    ];
    [_intent, (_intent get "roles") select 0, _t] call DUWS_fnc_opcom_intentBind;
    DUWS_opcom_intents pushBack _intent;
    _intent
};

// -> the role's tasking, or nil once it is lost: dead, gone, or taken out of the intent by a hand order.
DUWS_fnc_opcom_roleUnit = {
    params ["_intent", "_role"];
    private _t = [_role get "unit"] call DUWS_fnc_opcom_byId;
    if (isNil "_t" || {(_t get "status") isEqualTo "dead"} || {(_t getOrDefault ["boundTo", -1]) != (_intent get "id")}) exitWith { nil };
    _t
};

// Marks rather than removes: the runner calls this mid-pass over the store.
DUWS_fnc_opcom_intentClose = {
    params ["_intent", "_outcome"];
    {
        private _t = [_intent, _x] call DUWS_fnc_opcom_roleUnit;
        if (!isNil "_t") then { _t set ["boundTo", -1] };
    } forEach (_intent get "roles");
    _intent set ["state", "done"];
    ["INFO", "OPCOM", format ["intent %1 (%2 %3) %4", _intent get "id", _intent get "action",
        [_intent get "label", _intent get "target"] select ((_intent get "label") isEqualTo ""), _outcome]] call fnc_log;
};

// A unit lost once the action runs leaves the rest to finish it.
DUWS_fnc_opcom_executionStep = {
    params ["_intent"];
    private _units = [];
    private _roles = (_intent get "roles") select {
        private _t = [_intent, _x] call DUWS_fnc_opcom_roleUnit;
        if (!isNil "_t") then { _units pushBack _t };
        !isNil "_t"
    };
    _intent set ["roles", _roles];
    if (_units isEqualTo []) exitWith { [_intent, "aborted: every unit was lost"] call DUWS_fnc_opcom_intentClose };
    if ((_units findIf { [_x] call DUWS_fnc_opcom_marching }) < 0) then { [_intent, "done"] call DUWS_fnc_opcom_intentClose };
};

// After the task step, so an order that ended this tick frees its unit before the pick.
DUWS_fnc_opcom_intentStep = {
    {
        if ((_x get "state") isEqualTo "buildup") then { [_x] call DUWS_fnc_opcom_buildupStep } else {
            [_x] call DUWS_fnc_opcom_executionStep;
        };
    } forEach DUWS_opcom_intents;
    DUWS_opcom_intents = DUWS_opcom_intents select { (_x get "state") isNotEqualTo "done" };
};
