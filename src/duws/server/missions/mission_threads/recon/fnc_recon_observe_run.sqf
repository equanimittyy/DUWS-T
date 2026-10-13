// Locality: server. The hold both recon jobs run, each under its own _id so the HQ mission's and the Intelligence
// Center's can be live at once. The caller owns the task and the tail.
//
// Contract: [_id, _pick, _overwatch, _deadline, _lead] -> true on a completed hold, false on the deadline.
//   _lead  [speakerKey, msgKey] spoken in place of Overlord's brief and the team's copy, its %1 the target's
//          place; [] for the brief.
params ["_id", "_pick", "_overwatch", "_deadline", ["_lead", []]];

#define OBS_AREA    75
#define OBS_RANGE   900
#define HOLD_TIME   12
#define SPAWN_R     200
#define BONUS_MAX   2

_pick params ["_kind", "_target", ["_hpKey", ""]];

// Claimed before anything sleeps: the picker skips a live job's target, or two jobs would widen and hand back one
// zone's radius and pay twice for one hold.
DUWS_recon_targets pushBack _target;
publicVariable "DUWS_recon_targets";

private _marker = [_overwatch, OBS_AREA] call fnc_missionMarkerData;

private _active = format ["DUWS_recon_active_%1", _id];
private _done   = format ["DUWS_recon_done_%1", _id];
private _jip    = format ["DUWS_recon_layer_%1", _id];
missionNamespace setVariable [_done, false];
missionNamespace setVariable [_active, true, true];
// Cleared on end, or the JIP key would replay the layer at the next joiner.
[_id, _overwatch, _target, OBS_AREA, OBS_RANGE, HOLD_TIME] remoteExec ["fnc_recon_observe_layer", 0, _jip];

// The brief names the scouted target, not the overwatch the player is sent to: the overwatch is already marked.
private _place = [_target] call fnc_place_name;
if (_lead isNotEqualTo []) then {
    _lead params ["_spk", "_msg"];
    [localize _spk, [format [localize _msg, _place]] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
} else {
    [localize "STR_DUWS_T_OVERLORD", [format [localize "STR_DUWS_T_RECON_OBSERVE_BRIEF", _place]] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    sleep 6;
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECON_OBSERVE_COPY"] remoteExec ["fnc_duws_dialogue", 0];
};

// The real zone's stream radius is widened rather than a copy built, so its garrison wakes as the player nears
// the overwatch. Only the site record moves: the capture triggers keep their geometry, so the zone still captures
// over its true size.
private _zoneSiteKey    = "";
private _zoneOrigRadius = 0;
if (_kind isEqualTo "zone") then {
    _zoneSiteKey = [_target] call fnc_zone_key;
    private _site = [_zoneSiteKey] call fnc_site_at;
    _zoneOrigRadius = _site getOrDefault ["radius", 0];
    if (_zoneOrigRadius > 0) then {
        private _buffer = ([_zoneSiteKey, "garrison"] call fnc_site_occupant) getOrDefault ["buffer", 400];
        _site set ["radius", (((_overwatch distance2D _target) + SPAWN_R - _buffer) max _zoneOrigRadius)];
    };
};

waitUntil { sleep 2; (missionNamespace getVariable [_done, false]) || {[_deadline] call fnc_time_expired} };
private _won = missionNamespace getVariable [_done, false];

missionNamespace setVariable [_active, false, true];
remoteExec ["", _jip];
if (_zoneSiteKey isNotEqualTo "") then { ([_zoneSiteKey] call fnc_site_at) set ["radius", _zoneOrigRadius] };
[_marker] call fnc_missionMarkerClear;
DUWS_recon_targets = DUWS_recon_targets select { _x distance2D _target > 1 };
publicVariable "DUWS_recon_targets";

if (_won) then {
    // Quiet: the job speaks its own line instead of the reveal's AO-wide broadcast.
    if (_kind isEqualTo "hp") then { ["ONE", _hpKey, true] call fnc_hardpoint_reveal }
    else { ["ONE", _target, true] call fnc_zone_reveal };

    // A hardpoint under a still-hidden zone is no bonus: it reveals with its zone.
    private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
    private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
    private _targetKey = [_target] call fnc_zone_key;
    private _revealedKeys = [_targetKey];
    { _x params ["", "_zp2", "_rev2"]; if (_rev2) then { _revealedKeys pushBack ([_zp2] call fnc_zone_key) } } forEach _pairs;
    private _extra = [];
    {
        _x params ["", "_zp", "_rev"];
        if (!_rev && {_zp distance2D _target > 1} && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
            _extra pushBack ["zone", _zp, _zp distance2D _target];
        };
    } forEach _pairs;
    {
        if (!(_x select 5) && {((_x select 4) isEqualTo "") || {(_x select 4) in _revealedKeys}}) then {
            _extra pushBack ["hp", _x select 0, (_x select 1) distance2D _target];
        };
    } forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);
    private _idx = [];
    { _idx pushBack [_x select 2, _forEachIndex] } forEach _extra;
    _idx sort true;
    private _n = (floor (random (BONUS_MAX + 1))) min (count _idx);
    for "_k" from 0 to (_n - 1) do {
        (_extra select ((_idx select _k) select 1)) params ["_kind", "_ref"];
        if (_kind isEqualTo "zone") then { ["ONE", _ref, true] call fnc_zone_reveal }
        else { ["ONE", _ref, true] call fnc_hardpoint_reveal };
    };

    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_RECON_OBSERVE_DONE"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    if (_n > 0) then {
        [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_RECON_OBSERVE_BONUS"] remoteExec ["fnc_duws_dialogue", 0];
    };
};

_won
