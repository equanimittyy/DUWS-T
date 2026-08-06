// Locality: server -- the hardpoint streaming hooks and the site registration that reuses the shared
// poller. A hardpoint is a site like a zone: it registers with fnc_site_register, files one garrison
// occupant, and the poller in fnc_site_stream_init cycles it against the shared player list. What
// differs from a zone is only what wakes and sleeps -- one gun-and-garrison emplacement, never
// contested for, no attrition -- so the hooks here are the zone's shape stripped to that.
if (!isServer) exitWith {};

// The per-key slot a raise worker files its result in for the tick to adopt, the way a zone's raise
// hands back through ZONE_RAISE_SLOT.
#define HP_RAISE_SLOT(key) (format ["DUWS_hpRaise_%1", key])

// Dispatched, not inline: the raise re-crews statics through DUWS_fnc_manStatics, which sleeps in the
// drop-and-settle, and the poller holds every other site's clock.
DUWS_fnc_hardpointRaiseWorker = {
    params ["_key", "_o"];
    // Confirmed after a pause rather than on the first frame anyone clips the ring: a transiting
    // helicopter would otherwise rebuild the whole emplacement for someone already leaving.
    sleep 5;
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    private _ring = (_site get "radius") + (_o get "buffer");
    private _players = (call BIS_fnc_listPlayers) select { alive _x };
    if ((_players findIf { _x distance _pos < _ring }) < 0) exitWith {
        missionNamespace setVariable [HP_RAISE_SLOT(_key), false];
    };

    // Props and guns back first, then the garrison onto them -- men must not spawn into ground about
    // to carry a bunker, and the guns have to exist before anyone mans them.
    [_key] call fnc_duws_deploy;
    [_key] call fnc_site_roster_clear;
    private _objs = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _men = [_objs, _pos, _o get "hpSide", _key, _o get "hpGarrison"] call fnc_hardpoint_garrison;
    ([_key] call fnc_site_roster) append _men;
    missionNamespace setVariable [HP_RAISE_SLOT(_key), true];
};

// Uncrew, collect, stow -- the zone teardown order, so a gun is empty before its composition stows
// (fnc_duws_stow refuses a crewed member) and the men are collected rather than deleted with the
// props. Pinned guns keep their crew and never stow: the resident-crew step sets that flag, and both
// tests below honour it.
DUWS_fnc_hardpointStow = {
    params ["_key"];
    {
        if (_x isKindOf "StaticWeapon" && {!(_x getVariable ["DUWS_noStow", false])}) then {
            deleteVehicleCrew _x;
        };
    } forEach ((DUWS_compositions getOrDefault [_key, []]) select { !isNull _x });
    [_key] call fnc_site_collect;
    [_key] call fnc_duws_stow;
};

// One tick per hardpoint per pass, presence answered by the poller. The zone cycle without its
// withdraw and retake arms: a hardpoint is only present or not.
DUWS_hardpointHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    if (_here) then { _o set ["lastSeen", _now] };

    // A raise in flight owns the hardpoint until it reports, so a player crossing the ring twice
    // cannot start a second raise onto the first.
    if (_o get "raising") exitWith {
        private _res = missionNamespace getVariable [HP_RAISE_SLOT(_key), nil];
        if (isNil "_res") exitWith {};
        missionNamespace setVariable [HP_RAISE_SLOT(_key), nil];
        _o set ["raising", false];
        _o set ["awake", _res];
    };

    if (_o get "awake") then {
        if (_now - (_o getOrDefault ["lastSeen", _now]) >= (_o get "grace")) then {
            _o set ["awake", false];
            [_key] call DUWS_fnc_hardpointStow;
        };
    } else {
        if (_here) then {
            _o set ["raising", true];
            missionNamespace setVariable [HP_RAISE_SLOT(_key), nil];
            [_key, _o] spawn DUWS_fnc_hardpointRaiseWorker;
        };
    };
}]];

// [_key, _pos, _radius, _men, _grace, _side, _garrison] call fnc_hardpoint_register
//
// Files the hardpoint as a streamed site and adopts the composition and men it was just built with.
// Player-presence, not the AI-aware zone gate: a hardpoint should stand up whenever a player is near
// enough to fight it, whichever side it is. It starts awake because it is created deployed and manned
// -- an occupant starting asleep over a standing composition would raise a second garrison on the
// first tick. hpSide and hpGarrison are the serialisable spec a later raise rebuilds from.
fnc_hardpoint_register = {
    params ["_key", "_pos", "_radius", ["_men", []], ["_grace", 300], ["_side", "opfor"], ["_garrison", []]];
    [_key, _pos, _radius, "stream"] call fnc_site_register;
    private _occ = [_key, "garrison", EAST, 0, _grace, true, false] call fnc_site_occupant_register;
    _occ set ["hpSide", _side];
    _occ set ["hpGarrison", _garrison];
    _occ set ["awake", true];
    _occ set ["lastSeen", time];
    ([_key] call fnc_site_roster) append _men;
    [_key, "garrison", DUWS_hardpointHooks] call fnc_site_hooks_set;
};
