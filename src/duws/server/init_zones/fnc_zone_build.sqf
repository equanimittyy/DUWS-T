// Locality: server. The zone half of the flag factories (placement/fnc_site_build.sqf): a zone's allowance follows its
// garrison tier, and its builds stream with it.

DUWS_fnc_zoneFlag = {
    params ["_zoneKey"];
    private _p = ([_zoneKey] call fnc_site_at) get "pos";
    missionNamespace getVariable [format ["flag_%1_%2", floor abs (_p select 0), floor abs (_p select 1)], objNull]
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

// A stow would delete a piece out of someone's hands or a vehicle's cargo, so the lot waits for the next sleep.
DUWS_fnc_zoneBuildSleep = {
    params ["_zoneKey"];
    private _key = format ["%1_builds", _zoneKey];
    if (((DUWS_compositions getOrDefault [_key, []]) findIf { !isNull attachedTo _x }) >= 0) exitWith {};
    [_key] call fnc_duws_stow;
};
