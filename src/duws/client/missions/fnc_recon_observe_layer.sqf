// Locality: each client (fnc_recon_observe_run remoteExecs it to 0, JIP-keyed per job).
//
// Per-job state lives in DUWS_recon_layers: the HQ mission and the Intelligence Center's tasking can be live at
// once, and a Draw3D block sees no locals, so one handler draws every job from there.
params ["_id", "_overwatch", "_anchor", "_area", "_range", "_hold"];
if (!hasInterface) exitWith {};

// A JIP copy can fire after the job already ended.
private _activeVar = format ["DUWS_recon_active_%1", _id];
if (!(missionNamespace getVariable [_activeVar, false])) exitWith {};

// [overwatch, anchor, area, progress 0..1]
if (isNil "DUWS_recon_layers") then { DUWS_recon_layers = createHashMap };
DUWS_recon_layers set [_id, [_overwatch, _anchor, _area, 0]];

// Glassing = binoculars raised and actually looked through, not merely carried: currentWeapon reports
// the binocular only while it is selected, and cameraView is "GUNNER" only while the optic is up.
if (isNil "DUWS_fnc_recon_glassing") then {
    DUWS_fnc_recon_glassing = {
        params ["_p"];
        private _b = binocular _p;
        _b != "" && {(currentWeapon _p) == _b} && {cameraView == "GUNNER"}
    };
};

// Ignores the player's own vehicle so glassing from inside one still counts.
if (isNil "DUWS_fnc_recon_los") then {
    DUWS_fnc_recon_los = {
        params ["_p", "_tgt", "_range"];
        if ((_p distance2D _tgt) > _range) exitWith { false };
        private _eye = eyePos _p;   // ASL
        // Aim above the prefab's own structures (towers ~5 m, barriers ~2.5 m): the finder and thread
        // certified LOS to +5 over empty ground, but the observed point now carries the recon's own
        // composition, and a central piece would otherwise occlude the hold the overwatch was picked for.
        // Higher is strictly more terrain-clear, so +8 keeps the +5 certification valid and clears the camp.
        private _to  = [_tgt select 0, _tgt select 1, (getTerrainHeightASL _tgt) + 8];
        [_eye, _to, _p, vehicle _p] call fnc_sightline_clear
    };
};

// Never removed: taking it out as the last job ends would race a new job installing at the same moment.
if (isNil "DUWS_recon_ehDraw") then {
    DUWS_recon_ehDraw = addMissionEventHandler ["Draw3D", {
        {
            _y params ["_ow", "_a", "_area", "_progress"];
            if ((player distance2D _ow) <= _area) then {
                private _label = if (!([player] call DUWS_fnc_recon_glassing)) then { localize "STR_DUWS_T_RECON_OBSERVE_RAISE" } else {
                    private _pct = round (_progress * 100);
                    if (_pct > 0) then { format [localize "STR_DUWS_T_RECON_OBSERVE_HOLDING", _pct, "%"] } else { localize "STR_DUWS_T_RECON_OBSERVE_OBSERVE" }
                };
                drawIcon3D ["\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa", [0.2, 1, 0.2, 0.8],
                    [_a select 0, _a select 1, 8], 1, 1, 0, _label, 1, 0.03, "TahomaB"];
            };
        } forEach DUWS_recon_layers;
    }];
};

// The hold. Accrues real elapsed time while the player stays in the area, glassing, with LOS; any break
// resets it -- the observation has to be continuous. On completion it reports once to the server and
// stops; the server owns the win, so this only sends the signal. A short poll keeps it off every frame.
[_id, _activeVar, _overwatch, _anchor, _area, _range, _hold] spawn {
    params ["_id", "_activeVar", "_overwatch", "_anchor", "_area", "_range", "_hold"];
    private _acc = 0;
    private _last = diag_tickTime;
    private _sent = false;
    while { (missionNamespace getVariable [_activeVar, false]) && !_sent } do {
        private _dt = diag_tickTime - _last;
        _last = diag_tickTime;
        private _ok = alive player
            && {(player distance2D _overwatch) <= _area}
            && {[player] call DUWS_fnc_recon_glassing}
            && {[player, _anchor, _range] call DUWS_fnc_recon_los};
        if (_ok) then { _acc = _acc + _dt } else { _acc = 0 };
        (DUWS_recon_layers get _id) set [3, 0 max ((_acc / _hold) min 1)];
        if (_acc >= _hold) then {
            _sent = true;
            [_id] remoteExec ["fnc_recon_observe_success", 2];
        };
        sleep 0.5;
    };
    DUWS_recon_layers deleteAt _id;
};
