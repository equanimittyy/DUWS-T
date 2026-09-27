// Locality: server. A held zone's flag is an R3F factory for fortifications (docs/info/gameplay/zones_and_civilians.md).
//
// The flag's credits are derived, never stored: the tier's allowance minus the cost of every build still standing or
// stowed, so a clear, a sale or a wreck frees its points at the next recompute. Builds are filed under their own
// key beside the zone's, so a clear takes them without touching the prefab, and they stream with the zone.

#define BUILD_REACH 100

// R3F compiles its cost formula on clients only, and a dedicated server has none.
DUWS_fnc_buildCost = compile preprocessFile "modules\R3F_LOG\usine_creation\determiner_cout_creation.sqf";

DUWS_fnc_zoneFlag = {
    params ["_zoneKey"];
    private _p = ([_zoneKey] call fnc_site_at) get "pos";
    missionNamespace getVariable [format ["flag_%1_%2", floor abs (_p select 0), floor abs (_p select 1)], objNull]
};

// The factory role is client-local. It and the Clear action share one JIP order, because a second order keyed to the
// flag would replace the first.
DUWS_fnc_zoneBuildArm = {
    params ["_flg", "_zoneKey"];
    _flg setVariable ["DUWS_zoneKey", _zoneKey];
    _flg setVariable ["DUWS_buildKey", format ["%1_builds", _zoneKey]];
    [_flg, {
        params ["_flg"];
        if (!hasInterface || isNull _flg) exitWith {};
        [_flg, 0, west, ["Fortifications"]] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
        _flg addAction [localize "STR_DUWS_T_zonebuild_clear",
            {
                // hideOnUse off so a cancel keeps the action.
                if ([localize "STR_DUWS_T_zonebuild_clear_confirm", localize "STR_DUWS_T_zonebuild_clear", true, true] call BIS_fnc_guiMessage) then {
                    [_this select 0] remoteExec ["DUWS_fnc_zoneBuildClear", 2];
                };
            },
            [], 1.4, false, false, "",
            "_this distance _target < 6 && {!(_target getVariable ['R3F_LOG_disabled', true])} && {(_target getVariable ['DUWS_zoneBuildCount', 0]) > 0}"];
    }] remoteExec ["call", 0, _flg];
};

DUWS_fnc_zoneBuildCredits = {
    params ["_flg"];
    private _zoneKey = _flg getVariable ["DUWS_zoneKey", ""];
    if (_zoneKey == "") exitWith {};
    private _key = _flg getVariable "DUWS_buildKey";
    private _classes = ((DUWS_compositions getOrDefault [_key, []]) select { alive _x }) apply { typeOf _x };
    _classes append ((DUWS_stowed getOrDefault [_key, []]) apply { _x select 0 });
    private _used = 0;
    { _used = _used + ([_x] call DUWS_fnc_buildCost) } forEach _classes;
    private _cap = if ([_zoneKey] call fnc_zone_bluforHeld) then { DUWS_zoneBuildPoints select ([_zoneKey] call fnc_zone_tier) } else { 0 };
    _flg setVariable ["R3F_LOG_CF_credits", (_cap - _used) max 0, true];
    _flg setVariable ["DUWS_zoneBuildCount", count _classes, true];
};

// A piece in someone's hands or in a vehicle's cargo is left: deleting it would strand R3F's carry or cargo state.
DUWS_fnc_zoneBuildClear = {
    params ["_flg"];
    if (isNull _flg || {_flg getVariable ["R3F_LOG_disabled", true]}) exitWith {};
    private _key = _flg getVariable ["DUWS_buildKey", ""];
    if (_key == "") exitWith {};
    private _members = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _held = _members select { !isNull attachedTo _x };
    { deleteVehicle _x } forEach (_members - _held);
    if (_held isEqualTo []) then { DUWS_compositions deleteAt _key } else { DUWS_compositions set [_key, _held] };
    DUWS_stowed deleteAt _key;
    [_flg] call DUWS_fnc_zoneBuildCredits;
    (localize "STR_DUWS_T_zonebuild_cleared") remoteExec ["hint", remoteExecutedOwner];
};

// A stow rebuilds each piece as a new object, so what was set on it at build time is set again here.
DUWS_fnc_zoneBuildWake = {
    params ["_zoneKey"];
    private _key = format ["%1_builds", _zoneKey];
    if (_key in DUWS_stowed) then {
        [_key] call fnc_duws_deploy;
        {
            _x setVariable ["R3F_LOG_CF_depuis_usine", true, true];
            _x setVariable ["DUWS_buildZone", _zoneKey];
            _x setVariable ["DUWS_buildLastGood", getPosATL _x];
        } forEach ((DUWS_compositions getOrDefault [_key, []]) select { !isNull _x });
    };
    [[_zoneKey] call DUWS_fnc_zoneFlag] call DUWS_fnc_zoneBuildCredits;
};

// A stow would delete a piece out of someone's hands or a vehicle's cargo, so the lot waits for the next sleep.
DUWS_fnc_zoneBuildSleep = {
    params ["_zoneKey"];
    private _key = format ["%1_builds", _zoneKey];
    if (((DUWS_compositions getOrDefault [_key, []]) findIf { !isNull attachedTo _x }) >= 0) exitWith {};
    [_key] call fnc_duws_stow;
};

// R3F reports every carried object once it has settled after a drop (deplacer.sqf); only a zone's build is held to its reach.
DUWS_fnc_buildDropped = {
    params ["_obj"];
    if (isNull _obj || {!isNull attachedTo _obj}) exitWith {};
    private _zoneKey = _obj getVariable ["DUWS_buildZone", ""];
    if (_zoneKey == "") exitWith {};
    if ((_obj distance2D (([_zoneKey] call fnc_site_at) get "pos")) <= BUILD_REACH) exitWith {
        _obj setVariable ["DUWS_buildLastGood", getPosATL _obj];
    };
    _obj setPosATL (_obj getVariable "DUWS_buildLastGood");
    (localize "STR_DUWS_T_zonebuild_placement_failed") remoteExec ["hint", remoteExecutedOwner];
};
