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
    if (([_key] call fnc_zone_tier) == 0) exitWith {
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

// A string JIP id: one keyed on the flag would evict the factory's order (DUWS_fnc_siteBuildArm).
DUWS_fnc_zoneCaptureArm = {
    params ["_flg"];
    [[_flg], {
        params ["_flg"];
        if (!hasInterface || isNull _flg) exitWith {};
        [
            _flg, localize "STR_DUWS_T_ZONE_CAPTURE_ACTION",
            "\A3\ui_f\data\map\markers\military\flag_CA.paa",
            "\A3\ui_f\data\map\markers\military\flag_CA.paa",
            // Hidden while carried: a BLUFOR zone's pole rides its carrier, so the action would follow them around.
            "isNull attachedTo _target && {_this distance _target < 5}",
            "true",
            {}, {},
            { params ["_flg"]; [_flg] remoteExec ["DUWS_fnc_zoneFlagCapture", 2] },
            {}, [], 1, 30, false, false
        ] call BIS_fnc_holdActionAdd;
    }] remoteExec ["call", [0, -2] select isDedicated, format ["DUWS_zoneCapture_%1", netId _flg]];
};

// Only reports, as the zone's capture bar row with every failed test, for the side that would take the zone from its
// holder: the bar lists the tests only while a meter drains, so at zero the flag is how a player asks.
DUWS_fnc_zoneFlagCapture = {
    params ["_flg"];
    private _owner = remoteExecutedOwner;
    private _key = _flg getVariable ["DUWS_buildSite", ""];
    if (_key == "") exitWith {};
    private _held = [_key] call fnc_zone_bluforHeld;
    private _side = [west, east] select _held;
    private _blockers = [_key, "zone", _side, [east, west] select _held, true] call DUWS_fnc_siteTakeBlockers;
    private _name = (zone_namePOS_pairs select (zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _key })) select 0;
    // Built on the receiving machine: the server's language is not the player's, and structured text does not cross
    // remoteExec.
    [[_name, _side, [_key, _side] call DUWS_fnc_siteTakeDone, DUWS_captureHold, _blockers], {
        params ["_name", "_side", "_done", "_hold", "_blockers"];
        hint parseText (([_name, _side, _done, _hold, _blockers] call fnc_capture_bar_row) select 0);
    }] remoteExec ["call", _owner];
};
