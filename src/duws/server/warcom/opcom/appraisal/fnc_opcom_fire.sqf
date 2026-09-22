// Locality: server, [] call'd at load. The Arty action: what is worth shelling, with what pattern, and the rest the
// gun takes after (opcom_plan.md §Indirect-fire hardpoints). The mission itself is fnc_opcom_fires, which fires what
// it is handed. AP is the ammunition -- the guns rest empty and are loaded per mission -- so the wallet is the only
// limit on how often they speak.
if (!isServer) exitWith {};

// Tick each emplacement is loaded again, keyed by hardpoint.
DUWS_opcom_gunReady = createHashMap;

// Never aimed at the player HQ, and never onto OPFOR's own zone, which is full of its garrison. Re-read immediately
// before the guns fire: the point is latched at order time, so nothing may walk into the circle behind it.
DUWS_fnc_opcom_fireClear = {
    params ["_pos"];
    if (!isNil "PosOfBLUHQ" && {PosOfBLUHQ isNotEqualTo []} && {(_pos distance2D PosOfBLUHQ) < OPCOM_ARTY_HQ_CLEAR}) exitWith { false };
    (zone_meta_array findIf {
        ((_pos distance2D (_x select 1)) <= (_x select 2)) && {!([[_x select 1] call fnc_zone_key] call fnc_zone_bluforHeld)}
    }) < 0
};

// [[pos, believed force, P(win), shape kind, under an OP], ...]: a sighting fresh enough to still be there, and a
// zone or FOB seen inside the observation span. A sighting's odds are its freshness, because a fading one has
// probably moved; ground does not move, so a holding reads 1. Everything that does not depend on which gun fires is
// settled here, so the per-gun sweep only measures range.
DUWS_fnc_opcom_fireTargetsSeen = {
    private _out = [];
    {
        if ([_x] call DUWS_fnc_opcom_beliefIsSighting) then {
            private _age = DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex);
            private _pos = DUWS_opcom_belief_pos select _forEachIndex;
            if (_age <= OPCOM_BELIEF_FRESH && {[_pos] call DUWS_fnc_opcom_fireClear}) then {
                _out pushBack [_pos, DUWS_opcom_belief_str select _forEachIndex,
                    1 - ((_age / OPCOM_BELIEF_EXPIRE) min 1), "saturate", [_pos] call DUWS_fnc_opcom_opWatches];
            };
        };
    } forEach DUWS_opcom_belief_key;
    {
        _x params ["_key", "_pos"];
        if ((([_key] call DUWS_fnc_opcom_observedAge) <= OPCOM_OBSERVE_SPAN) && {[_pos] call DUWS_fnc_opcom_fireClear}) then {
            _out pushBack [_pos, OPCOM_GRID_ZONE_ENEMY_FORCE, 1, "creep", [_pos] call DUWS_fnc_opcom_opWatches];
        };
    } forEach (call DUWS_fnc_opcom_bluforSites);
    _out
};

DUWS_fnc_opcom_fireTargets = {
    if (isNil "DUWS_opcom_grid_w") exitWith { [] };
    private _seen = call DUWS_fnc_opcom_fireTargetsSeen;
    if (_seen isEqualTo []) exitWith { [] };
    private _out = [];
    {
        _x params ["_key", "_gpos", "_type"];
        private _guns = count ([_key] call DUWS_fnc_opcom_batteryPieces);
        if (_guns > 0 && {DUWS_opcom_tick >= (DUWS_opcom_gunReady getOrDefault [_key, 0])}) then {
            private _reach = [OPCOM_MORTAR_REACH, OPCOM_ARTY_REACH] select (_type isEqualTo "ARTY");
            private _lethal = OPCOM_ARTY_LETHAL getOrDefault [_type, 20];
            (OPCOM_ARTY_ROUNDS getOrDefault [_type, [4, 8]]) params ["_lo", "_hi"];
            private _rounds = _lo + floor random (_hi - _lo + 1);
            {
                _x params ["_pos", "_force", "_pw", "_kind", "_op"];
                private _d = _gpos distance2D _pos;
                if (_d <= _reach) then {
                    private _spread = [OPCOM_ARTY_SPREAD getOrDefault [_type, 50], _d, _op] call DUWS_fnc_opcom_artySpread;
                    // A sighting is saturated where it stands; a zone or a FOB is walked across, away from the gun.
                    private _shape = if (_kind isEqualTo "creep") then { ["creep", _spread, _spread, _gpos getDir _pos] } else { ["saturate", _spread] };
                    // A creep's rounds follow from its size, so its Cost is what the shape will actually fire.
                    private _fired = if (_kind isEqualTo "creep") then {
                        ([_shape, _guns] call DUWS_fnc_opcom_creepGrid) params ["_rows", "_perRow"];
                        _rows * _perRow * _guns
                    } else { _rounds * _guns };
                    private _area = [_shape] call DUWS_fnc_opcom_patternArea;
                    private _share = [_fired, _lethal, _area] call DUWS_fnc_opcom_artyShare;
                    _out pushBack [[_key, _type, +_pos, _rounds, _shape, _spread], _fired * OPCOM_AP_PER_ROUND,
                        format ["Shell %1 from %2", mapGridPosition _pos, DUWS_hardpointName getOrDefault [_type, _type]],
                        [_pos, _force, _spread, _share] call DUWS_fnc_opcom_artyValue, _pw];
                };
            } forEach _seen;
        };
    } forEach ([] call DUWS_fnc_opcom_batteries);
    _out
};

// The telegraph: an Allseer call and a marker on the ground about OPCOM_ARTY_WARN seconds out, so a barrage is
// something players can walk out of rather than a death from nowhere.
DUWS_fnc_opcom_fireWarn = {
    params ["_pt", "_spread", "_eta", "_name"];
    sleep ((_eta - OPCOM_ARTY_WARN) max 0);
    private _mk = createMarker [_name, _pt];
    _mk setMarkerShape "ELLIPSE";
    _mk setMarkerBrush "DiagGrid";
    _mk setMarkerColor "ColorRed";
    _mk setMarkerSize [_spread, _spread];
    [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_OPCOM_ARTY_INBOUND", [_pt] call DUWS_fnc_hardpointNearestPlace]]
        remoteExec ["fnc_duws_dialogue", 0];
    sleep OPCOM_ARTY_MARK;
    deleteMarker _mk;
};

DUWS_fnc_opcom_fireRun = {
    params ["_target"];
    _target params ["_key", "_type", "_pt", "_rounds", "_shape", "_spread"];
    if !([_pt] call DUWS_fnc_opcom_fireClear) exitWith { false };
    private _eta = [_key, _pt] call DUWS_fnc_opcom_fireETA;
    if (([_key, _pt, _rounds, _shape] call DUWS_fnc_opcom_fireMission) <= 0) exitWith { false };
    (OPCOM_ARTY_COOLDOWN getOrDefault [_type, [300, 480]]) params ["_lo", "_hi"];
    DUWS_opcom_gunReady set [_key, DUWS_opcom_tick + _lo + floor random (_hi - _lo + 1)];
    // One mission per emplacement per tick, so the tick and the key name the marker uniquely.
    [_pt, _spread, _eta, format ["opcom_arty_%1_%2", _key, DUWS_opcom_tick]] spawn DUWS_fnc_opcom_fireWarn;
    true
};
