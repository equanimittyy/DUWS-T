// Locality: server, [] call'd at load. Intents: a committed action's record, holding each unit it sends in a role so
// no later pick draws it away mid-action (opcom_plan.md §Orchestration). A role names its unit by tasking id, never
// the record, so an intent serialises on the taskings' own terms.
if (!isServer) exitWith {};

// _roles: [[role, tasking], ...].
DUWS_fnc_opcom_intentOpen = {
    params ["_action", "_target", "_roles"];
    private _id = DUWS_opcom_intentSeq;
    DUWS_opcom_intentSeq = _id + 1;
    private _intent = createHashMapFromArray [
        ["id", _id], ["action", _action], ["target", _target], ["state", "execution"],
        ["roles", _roles apply {
            _x params ["_role", "_t"];
            _t set ["boundTo", _id];
            createHashMapFromArray [["role", _role], ["unit", _t get "id"]]
        }]
    ];
    DUWS_opcom_intents pushBack _intent;
    _intent
};

// Marks rather than removes: the runner calls this mid-pass over the store.
DUWS_fnc_opcom_intentClose = {
    params ["_intent", "_outcome"];
    {
        private _t = [_x get "unit"] call DUWS_fnc_opcom_byId;
        if (!isNil "_t" && {(_t getOrDefault ["boundTo", -1]) == (_intent get "id")}) then { _t set ["boundTo", -1] };
    } forEach (_intent get "roles");
    _intent set ["state", "done"];
    ["INFO", "OPCOM", format ["intent %1 (%2) %3", _intent get "id", _intent get "action", _outcome]] call fnc_log;
};

// After the task step, so an order that ended this tick frees its unit before the pick.
DUWS_fnc_opcom_intentStep = {
    {
        private _intent = _x;
        private _lost = false;
        private _busy = false;
        {
            private _t = [_x get "unit"] call DUWS_fnc_opcom_byId;
            if (isNil "_t" || {(_t get "status") isEqualTo "dead"}) then { _lost = true } else {
                if ([_t] call DUWS_fnc_opcom_marching) then { _busy = true };
            };
        } forEach (_intent get "roles");
        if (_lost) then { [_intent, "aborted: a unit was lost"] call DUWS_fnc_opcom_intentClose } else {
            if (!_busy) then { [_intent, "done"] call DUWS_fnc_opcom_intentClose };
        };
    } forEach DUWS_opcom_intents;
    DUWS_opcom_intents = DUWS_opcom_intents select { (_x get "state") isNotEqualTo "done" };
};
