// Locality: server. The zone half of the flag factories (placement/fnc_site_build.sqf): a zone's allowance follows its
// garrison tier and the Fortification level, and its builds stream with it.

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
    private _fort = missionNamespace getVariable ["DUWS_fortLevel", 0];
    _flg setVariable ["R3F_LOG_CF_credits", (_flg getVariable ["R3F_LOG_CF_credits", 0])
        + (DUWS_zoneBuildPoints select (_new min _fort)) - (DUWS_zoneBuildPoints select (_old min _fort)), true];
};

DUWS_fnc_zoneFortGrant = {
    params ["_old", "_new"];
    {
        private _zoneKey = [_x] call fnc_zone_key;
        private _flg = [_zoneKey] call DUWS_fnc_zoneFlag;
        private _tier = [_zoneKey] call fnc_zone_tier;
        if (!isNull _flg) then {
            _flg setVariable ["R3F_LOG_CF_disabled", false, true];
            _flg setVariable ["R3F_LOG_CF_credits", (_flg getVariable ["R3F_LOG_CF_credits", 0])
                + (DUWS_zoneBuildPoints select (_tier min _new)) - (DUWS_zoneBuildPoints select (_tier min _old)), true];
        };
    } forEach WARCOM_zones_controled_by_BLUFOR;
};

// A stow would delete a piece out of someone's hands or a vehicle's cargo, or a gun a player's squadmate mans, so
// the lot waits for the next sleep.
DUWS_fnc_zoneBuildSleep = {
    params ["_zoneKey"];
    private _key = format ["%1_builds", _zoneKey];
    if (((DUWS_compositions getOrDefault [_key, []]) findIf {
        !isNull attachedTo _x || {({alive _x} count crew _x) > 0}
    }) >= 0) exitWith {};
    [_key] call fnc_duws_stow;
};

// Tier I and up: a zone with a tier raises, and a raise adopts every seated gunner into the garrison roster that its
// stream-out collects (DUWS_fnc_zoneManStatics). A tier-0 zone never raises, so its gunners would stand for good.
DUWS_fnc_zoneRedeploy = {
    params ["_flg"];
    private _owner = remoteExecutedOwner;
    private _key = _flg getVariable ["DUWS_buildSite", ""];
    if (_key == "" || {!([_key] call fnc_zone_bluforHeld)}) exitWith {};
    if ([_key] call DUWS_fnc_opcom_siteContested) exitWith {
        (localize "STR_DUWS_T_site_contested") remoteExec ["hint", _owner];
    };
    // DUWS_fnc_manStatics sleeps, so a second click in that window would man the same empty guns and charge again.
    if (_flg getVariable ["DUWS_redeployBusy", false]) exitWith {
        (localize "STR_DUWS_T_ZONE_REDEPLOY_BUSY") remoteExec ["hint", _owner];
    };
    if (([_key] call fnc_zone_tier) < 1) exitWith {
        (localize "STR_DUWS_T_ZONE_REDEPLOY_NO_TIER") remoteExec ["hint", _owner];
    };
    if (commandpointsblu1 < 2) exitWith {
        (localize "STR_DUWS_T_e95mc4lv") remoteExec ["hint", _owner];
    };
    _flg setVariable ["DUWS_redeployBusy", true];
    // call, not remoteExec to self, and escalation applied here: the same reason fnc_redeployHQUnits gives.
    [-([2] call fnc_escalation_cost), "zone_redeploy"] call fnc_cp_adjust;
    [(DUWS_compositions getOrDefault [_key, []]) + (DUWS_compositions getOrDefault [format ["%1_builds", _key], []]),
        true, [_key] call fnc_zone_roster] call DUWS_fnc_buildRecrew;
    _flg setVariable ["DUWS_redeployBusy", false];
    (localize "STR_DUWS_T_ZONE_REDEPLOY_SUCCESS") remoteExec ["hint", _owner];
};
