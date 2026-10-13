// Locality: server; shared by both recon jobs. Every other enemy zone and hardpoint is avoided, so the player never
// observes from on top of one.
//
// Contract: [_pick] (a fnc_recon_observe_pick result) -> overwatch pos | [] none qualifies.
params ["_pick"];
_pick params ["", "_target", ["_hpKey", ""]];

#define OBS_MIN_DIST    600
#define OBS_MAX_DIST    800
#define ZONE_CLEAR      250
#define HP_CLEAR        300

private _tgtASL    = [_target select 0, _target select 1, (getTerrainHeightASL _target) + 5];
private _tgtGround = getTerrainHeightASL _target;

private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _avoidZones = (missionNamespace getVariable ["zone_meta_array", []]) select {
    private _zp = _x select 1;
    (_zp distance2D _target > 1) && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}
};
// The target HP is watched, not avoided. No side filter: a captured or fallen hardpoint is deleted, not re-sided.
private _hps = (missionNamespace getVariable ["DUWS_hardpoints", []]) select { (_x select 0) != _hpKey };
private _fAnchors = +(missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []]);
if (!(isNil "PosOfBLUHQ") && {!(PosOfBLUHQ isEqualTo [])}) then { _fAnchors pushBack PosOfBLUHQ };
if (!(isNil "Array_of_FOBpos")) then { { _fAnchors pushBack _x } forEach Array_of_FOBpos };
private _baseBearing = if (_fAnchors isEqualTo []) then { random 360 } else {
    private _near = _fAnchors select 0; private _nd = 1e9;
    { private _d = _x distance2D _target; if (_d < _nd) then { _nd = _d; _near = _x } } forEach _fAnchors;
    _target getDir _near
};
private _overwatch = [];
private _bestScore = -1e9;
for "_i" from 0 to 17 do {
    private _b = _baseBearing - 90 + (_i * (180 / 17));
    private _r = OBS_MIN_DIST + random (OBS_MAX_DIST - OBS_MIN_DIST);
    private _cand    = _target getPos [_r, _b];
    private _ground  = getTerrainHeightASL _cand;
    private _eyeASL  = [_cand select 0, _cand select 1, _ground + 1.5];
    if (
        [_eyeASL, _tgtASL] call fnc_sightline_clear
        && {(_avoidZones findIf { _cand distance2D (_x select 1) < ((_x select 2) + ZONE_CLEAR) }) < 0}
        && {(_hps findIf { _cand distance2D (_x select 1) < HP_CLEAR }) < 0}
    ) then {
        private _score = _ground - _tgtGround;   // prefer looking down onto the target
        if (_score > _bestScore) then { _bestScore = _score; _overwatch = _cand };
    };
};

_overwatch
