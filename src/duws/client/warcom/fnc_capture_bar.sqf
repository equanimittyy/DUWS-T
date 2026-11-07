// Locality: client, remoteExec'd by DUWS_fnc_siteTakeTell each time a capture's failed tests change. _done is the
// meter, 0 to 1: with no _blockers it fills over _hold, otherwise it drains _decay times as fast.
// A HUD layer, not the hint box: the counts run under the fight, and the flag's report must stay readable over them.
params ["_name", "_side", "_done", "_hold", "_decay", "_blockers"];
if (!hasInterface) exitWith {};

if (isNil "DUWS_captureBars") then { DUWS_captureBars = createHashMap };
DUWS_captureBars set [_name, [_side, _done, _hold, _decay, _blockers, time]];
// One drawing loop for every zone, so two captures at once each keep their own row. It never ends, so a message
// cannot land between its last pass and its exit and be left undrawn.
if (!isNil "DUWS_captureBarLoop" && {!scriptDone DUWS_captureBarLoop}) exitWith {};
DUWS_captureBarLoop = [] spawn {
    private _layer = "DUWS_CaptureBar" call BIS_fnc_rscLayer;
    while { true } do {
        private _rows = [];
        private _gone = [];
        {
            private _name = _x;
            _y params ["_side", "_done", "_hold", "_decay", "_blockers", "_at"];
            private _draining = count _blockers > 0;
            private _now = _done + ([1, -_decay] select _draining) * (time - _at) / _hold;
            if ([_now >= 1, _now <= 0] select _draining) then { _gone pushBack _name } else {
                _rows pushBack ([[0, 1] select (_side isEqualTo east), _name] + ([_name, _side, _now, _hold, _blockers] call fnc_capture_bar_row));
            };
        } forEach DUWS_captureBars;
        { DUWS_captureBars deleteAt _x } forEach _gone;
        _rows sort true;
        // Read at every pass, as every option in fnc_user_options_menu is, so a toggle shows at once.
        DUWS_captureBarText = if (profileNamespace getVariable ["DUWS_T_captureDetails", true]) then {
            [(_rows apply { _x select 2 }) joinString "<br/><br/>", "", ""]
        } else {
            ["", (_rows apply { _x select 3 }) joinString "<br/>", (_rows apply { _x select 4 }) joinString "<br/>"]
        };
        private _disp = uiNamespace getVariable ["DUWS_captureBarDisplay", displayNull];
        switch (true) do {
            case (_rows isEqualTo []): { if (!isNull _disp) then { _layer cutText ["", "PLAIN"] } };
            case (isNull _disp): { _layer cutRsc ["DUWS_CaptureBar", "PLAIN", 0, false] };
            default { { (_disp displayCtrl (8818 + _forEachIndex)) ctrlSetStructuredText parseText _x } forEach DUWS_captureBarText };
        };
        sleep 0.2;
    };
};
