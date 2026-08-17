// Locality: runs on each client (the thread remoteExecs it to 0, JIP-keyed). The player-facing half
// of the recon-observe mission: the "look here" icon over the target, the binocular + line-of-sight
// hold, and the report back to the server when a hold completes. The dedicated server and any headless
// client have no player to observe with, so they drop out.
//
// State is held in globals rather than the params' locals because a Draw3D block sees no locals from
// where it was written (the same reason fnc_draw_world_icons names its sources). DUWS_recon_active is
// the server-owned teardown switch: the thread flips it false and publicVariables it on mission end,
// and both the draw handler and the hold loop below stop on it.
params ["_overwatch", "_anchor", "_area", "_range", "_hold"];
if (!hasInterface) exitWith {};

// A late joiner whose JIP copy fires after the mission already ended: nothing to install.
if (!(missionNamespace getVariable ["DUWS_recon_active", false])) exitWith {};

DUWS_recon_overwatch = _overwatch;
DUWS_recon_anchorPos = _anchor;
DUWS_recon_area      = _area;
DUWS_recon_range     = _range;
DUWS_recon_progress  = 0;   // 0..1, written by the hold loop, read by the draw handler

// Glassing = binoculars raised and actually looked through, not merely carried: currentWeapon reports
// the binocular only while it is selected, and cameraView is "GUNNER" only while the optic is up.
if (isNil "DUWS_fnc_recon_glassing") then {
    DUWS_fnc_recon_glassing = {
        params ["_p"];
        private _b = binocular _p;
        _b != "" && {(currentWeapon _p) == _b} && {cameraView == "GUNNER"}
    };
};

// Terrain- and object-honest LOS from the player's eye to a point just above the target. terrainIntersectASL
// answers elevation (a ridge in the way); lineIntersectsSurfaces answers structures, ignoring the player's
// own vehicle so glassing from inside one still counts.
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
        if (terrainIntersectASL [_eye, _to]) exitWith { false };
        if !((lineIntersectsSurfaces [_eye, _to, _p, vehicle _p]) isEqualTo []) exitWith { false };
        // Foliage the geometry ray misses -- canopy over a look-down sight, low bushes -- sampled on the
        // target end. The thread's overwatch was picked through the same helper, so this cannot reject a
        // hold the thread certified.
        [_eye, _to] call fnc_recon_observe_foliageClear
    };
};

// The icon draws only while the player is set up to observe -- inside the designated overwatch area,
// binoculars up. It rides the fixed anchor position (z is metres above it, the array-source convention
// fnc_draw_world_icons uses) and carries the live hold percentage so the marker is the progress read-out.
DUWS_recon_ehDraw = addMissionEventHandler ["Draw3D", {
    if (!(missionNamespace getVariable ["DUWS_recon_active", false])) exitWith {};
    if ((player distance2D DUWS_recon_overwatch) > DUWS_recon_area) exitWith {};
    if (!([player] call DUWS_fnc_recon_glassing)) exitWith {};
    private _a = DUWS_recon_anchorPos;
    private _pct = round (DUWS_recon_progress * 100);
    private _label = if (_pct > 0) then { format ["Observing... (%1%2)", _pct, "%"] } else { "Observe" };
    drawIcon3D ["\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa", [0.2, 1, 0.2, 0.8],
        [_a select 0, _a select 1, 8], 1, 1, 0, _label, 1, 0.03, "TahomaB"];
}];

// The hold. Accrues real elapsed time while the player stays in the area, glassing, with LOS; any break
// resets it -- the observation has to be continuous. On completion it reports once to the server and
// stops; the server owns the win, so this only sends the signal. A short poll keeps it off every frame.
[_hold] spawn {
    params ["_hold"];
    private _acc = 0;
    private _last = diag_tickTime;
    private _sent = false;
    while { (missionNamespace getVariable ["DUWS_recon_active", false]) && !_sent } do {
        private _dt = diag_tickTime - _last;
        _last = diag_tickTime;
        private _ok = alive player
            && {(player distance2D DUWS_recon_overwatch) <= DUWS_recon_area}
            && {[player] call DUWS_fnc_recon_glassing}
            && {[player, DUWS_recon_anchorPos, DUWS_recon_range] call DUWS_fnc_recon_los};
        if (_ok) then { _acc = _acc + _dt } else { _acc = 0 };
        DUWS_recon_progress = 0 max ((_acc / _hold) min 1);
        if (_acc >= _hold) then {
            _sent = true;
            remoteExec ["fnc_recon_observe_success", 2];
        };
        sleep 0.5;
    };
    removeMissionEventHandler ["Draw3D", DUWS_recon_ehDraw];
    DUWS_recon_progress = 0;
};
