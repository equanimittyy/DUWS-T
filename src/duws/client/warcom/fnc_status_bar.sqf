// Locality: client, spawned once from client_init.
// A poll, not publicVariable handlers: the host's handler never fires for its own broadcast.
if (!hasInterface) exitWith {};

private _layer = "DUWS_StatusBar" call BIS_fnc_rscLayer;
private _shown = [];
private _shownTier = 0;
while {true} do {
    private _disp = uiNamespace getVariable ["DUWS_statusBarDisplay", displayNull];
    if (isNull _disp) then {
        _layer cutRsc ["DUWS_StatusBar", "PLAIN", 0, false];
        _shown = [];
        _shownTier = 0;
    } else {
        private _earned = WARCOM_blufor_ap_earned;
        private _state = [commandpointsblu1, WARCOM_blufor_ap, _earned];
        if (_state isNotEqualTo _shown) then {
            _shown = _state;
            // Derived from the earned counter, not WARCOM_blufor_tier, so the tier name can never
            // disagree with the earned figure beside it.
            private _rungs = DUWS_ap_tier_rungs;
            private _tier = 1 + ({ _earned >= _x } count _rungs);
            private _from = ([0] + _rungs) select (_tier - 1);
            private _to = _rungs param [_tier - 1, -1];
            private _earnedText = if (_to < 0) then { str _earned } else { format ["%1 (%2)", _earned, _to] };
            (_disp displayCtrl 8815) ctrlSetText format [localize "STR_DUWS_T_STATUS_BAR",
                [_tier] call DUWS_fnc_tierName, commandpointsblu1, WARCOM_blufor_ap, _earnedText];

            private _pos = ctrlPosition (_disp displayCtrl 8816);
            _pos set [2, (_pos select 2) * (if (_to < 0) then { 1 } else { (_earned - _from) / (_to - _from) })];
            private _fill = _disp displayCtrl 8817;
            _fill ctrlSetPosition _pos;
            // Snaps on a new tier: sliding back from full would read as AP lost.
            _fill ctrlCommit ([0.5, 0] select (_tier != _shownTier));
            _shownTier = _tier;
        };
    };
    sleep 0.5;
};
