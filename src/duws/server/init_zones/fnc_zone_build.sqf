// Locality: server. A held zone's flag is an R3F factory for fortifications (docs/info/gameplay/zones_and_civilians.md).
//
// The flag's credits are R3F's own running balance: R3F spends them on a build and refunds them on a sale, and this
// file adds a tier purchase's allowance and a clear's refund. A destroyed build is lost. Builds are filed under their
// own key beside the zone's, so a clear takes them without touching the prefab, and they stream with the zone.

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
            "_this distance _target < 6 && {!(_target getVariable ['R3F_LOG_disabled', true])}"];
    }] remoteExec ["call", 0, _flg];
};

// OPFOR buy tiers on their own ground too, and those grant nothing.
DUWS_fnc_zoneBuildGrant = {
    params ["_zoneKey", "_old", "_new"];
    if !([_zoneKey] call fnc_zone_bluforHeld) exitWith {};
    private _flg = [_zoneKey] call DUWS_fnc_zoneFlag;
    if (isNull _flg) exitWith {};
    _flg setVariable ["R3F_LOG_CF_credits", (_flg getVariable ["R3F_LOG_CF_credits", 0])
        + (DUWS_zoneBuildPoints select _new) - (DUWS_zoneBuildPoints select _old), true];
};

// A piece in someone's hands or in a vehicle's cargo is left: deleting it would strand R3F's carry or cargo state.
DUWS_fnc_zoneBuildClear = {
    params ["_flg"];
    if (isNull _flg || {_flg getVariable ["R3F_LOG_disabled", true]}) exitWith {};
    private _key = _flg getVariable ["DUWS_buildKey", ""];
    if (_key == "") exitWith {};
    private _members = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _held = _members select { !isNull attachedTo _x };
    private _gone = _members - _held;
    private _refund = 0;
    // A wreck refunds nothing, as R3F's own sale scales its refund by damage.
    { if (alive _x) then { _refund = _refund + ([typeOf _x] call DUWS_fnc_buildCost) } } forEach _gone;
    { _refund = _refund + ([_x select 0] call DUWS_fnc_buildCost) } forEach (DUWS_stowed getOrDefault [_key, []]);
    { deleteVehicle _x } forEach _gone;
    if (_held isEqualTo []) then { DUWS_compositions deleteAt _key } else { DUWS_compositions set [_key, _held] };
    DUWS_stowed deleteAt _key;
    _flg setVariable ["R3F_LOG_CF_credits", (_flg getVariable ["R3F_LOG_CF_credits", 0]) + _refund, true];
    (localize "STR_DUWS_T_zonebuild_cleared") remoteExec ["hint", remoteExecutedOwner];
};

// A stow rebuilds each piece as a new object, so what was set on it at build time is set again here.
DUWS_fnc_zoneBuildWake = {
    params ["_zoneKey"];
    private _key = format ["%1_builds", _zoneKey];
    if !(_key in DUWS_stowed) exitWith {};
    [_key] call fnc_duws_deploy;
    {
        _x setVariable ["R3F_LOG_CF_depuis_usine", true, true];
        _x setVariable ["DUWS_buildZone", _zoneKey];
        _x setVariable ["DUWS_buildLastGood", getPosATL _x];
    } forEach ((DUWS_compositions getOrDefault [_key, []]) select { !isNull _x });
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
