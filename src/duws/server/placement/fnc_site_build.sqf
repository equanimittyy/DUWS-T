// Locality: server, except DUWS_fnc_inBaseRing, DUWS_fnc_canSellTo, DUWS_fnc_buildCrewFree and DUWS_fnc_buildContested. A
// held zone's flag, the HQ and each FOB are R3F factories for fortifications (docs/info/gameplay/zones_and_civilians.md).
//
// A factory's credits are R3F's own running balance: R3F spends them on a build and refunds them on a sale, and the
// callers add an allowance and the refund of a clear or of a rejected new build. A destroyed build is lost. Builds are filed under `<siteKey>_builds`,
// beside the site's own key, so a clear takes them without touching the site's composition.

#include "..\..\shared\includes\action_style.hpp"

#define BUILD_REACH 100

// R3F compiles its cost formula on clients only, and a dedicated server has none.
DUWS_fnc_buildCost = compile preprocessFile "modules\R3F_LOG\usine_creation\determiner_cout_creation.sqf";

// The factory role is client-local, so it, the Clear action and a zone flag's redeploy ride one JIP order. A string id,
// because an object-keyed one would evict another order keyed to the same object (a FOB's actions).
DUWS_fnc_siteBuildArm = {
    params ["_factory", "_siteKey"];
    _factory setVariable ["DUWS_buildSite", _siteKey, true];
    _factory setVariable ["DUWS_buildKey", format ["%1_builds", _siteKey]];
    [[_factory, _siteKey], {
        params ["_factory", "_siteKey"];
        if (!hasInterface || isNull _factory) exitWith {};
        waitUntil { !isNil "R3F_LOG_active" };
        if (!R3F_LOG_active) exitWith {};
        [_factory, 0, west, ["Fortifications", "Static"]] call R3F_LOG_FNCT_usine_init;
        // Equal priorities list in the order they are added, so this sits right under R3F's Open action. Its condition
        // is that action's own: a distance to the model centre never shows on a building as big as the HQ.
        _factory addAction ["<t color=""#ff9600"">" + localize "STR_DUWS_T_zonebuild_clear" + "</t>",
            {
                // hideOnUse off so a cancel keeps the action.
                if ([localize "STR_DUWS_T_zonebuild_clear_confirm", localize "STR_DUWS_T_zonebuild_clear", true, true] call BIS_fnc_guiMessage) then {
                    [_this select 0] remoteExec ["DUWS_fnc_siteBuildClear", 2];
                };
            },
            [], 5, false, false, "",
            "!R3F_LOG_mutex_local_verrou && R3F_LOG_objet_addAction == _target && R3F_LOG_action_ouvrir_usine_valide"];
        // The flag's carry gate is its BLUFOR-held test (fnc_zone_flag_logistics).
        if ((_siteKey select [0, 5]) isEqualTo "zone_") then {
            _factory addAction ["<t color=""#ff9600"">" + localize "STR_DUWS_T_ZONE_REDEPLOY_ACTION" + "</t>",
                { [_this select 0] remoteExec ["DUWS_fnc_zoneRedeploy", 2] },
                [], 5, false, true, "",
                "_this == player && {(vehicleVarName _this) in Squad_Leaders} && {!(_target getVariable ['R3F_LOG_disabled', true])}",
                ACT_REACH];
        };
    }] remoteExec ["spawn", 0, format ["DUWS_siteBuild_%1", netId _factory]];
};

// A base is BLUFOR's for as long as it stands, so its factory opens with the whole allowance once Fortification I is
// bought.
DUWS_fnc_baseBuildArm = {
    params ["_building", "_siteKey"];
    private _fort = missionNamespace getVariable ["DUWS_fortLevel", 0];
    _building setVariable ["R3F_LOG_CF_disabled", _fort == 0, true];
    _building setVariable ["R3F_LOG_CF_credits", DUWS_baseBuildPoints select _fort, true];
    [_building, _siteKey] call DUWS_fnc_siteBuildArm;
};

DUWS_fnc_baseBuildGrant = {
    params ["_old", "_new"];
    private _step = (DUWS_baseBuildPoints select _new) - (DUWS_baseBuildPoints select _old);
    {
        _x setVariable ["R3F_LOG_CF_disabled", false, true];
        _x setVariable ["R3F_LOG_CF_credits", (_x getVariable ["R3F_LOG_CF_credits", 0]) + _step, true];
    } forEach (([bluHQ_object] + Array_of_FOBS) select { !isNull _x });
};

// A piece in someone's hands or in a vehicle's cargo is left: deleting it would strand R3F's carry or cargo state.
DUWS_fnc_siteBuildClear = {
    params ["_factory"];
    if (isNull _factory || {_factory getVariable ["R3F_LOG_CF_disabled", true]}) exitWith {};
    if ([_factory getVariable ["DUWS_buildSite", ""]] call DUWS_fnc_opcom_siteContested) exitWith {
        (localize "STR_DUWS_T_site_contested") remoteExec ["hint", remoteExecutedOwner];
    };
    private _key = _factory getVariable ["DUWS_buildKey", ""];
    if (_key == "") exitWith {};
    private _members = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _held = _members select { !isNull attachedTo _x };
    private _gone = _members - _held;
    private _refund = 0;
    // A wreck refunds nothing, as R3F's own sale scales its refund by damage.
    { if (alive _x) then { _refund = _refund + ([typeOf _x] call DUWS_fnc_buildCost) } } forEach _gone;
    { _refund = _refund + ([_x select 0] call DUWS_fnc_buildCost) } forEach (DUWS_stowed getOrDefault [_key, []]);
    { [_x] call DUWS_fnc_buildCrewClear; deleteVehicle _x } forEach _gone;
    if (_held isEqualTo []) then { DUWS_compositions deleteAt _key } else { DUWS_compositions set [_key, _held] };
    DUWS_stowed deleteAt _key;
    _factory setVariable ["R3F_LOG_CF_credits", (_factory getVariable ["R3F_LOG_CF_credits", 0]) + _refund, true];
    (localize "STR_DUWS_T_zonebuild_cleared") remoteExec ["hint", remoteExecutedOwner];
};

// Rebuilds a site's stowed builds, for a zone's wake and for a restore. A deploy makes each piece a new object, so what
// was set on it at build time is set again here.
DUWS_fnc_siteBuildDeploy = {
    params ["_siteKey"];
    private _key = format ["%1_builds", _siteKey];
    if !(_key in DUWS_stowed) exitWith {};
    [_key] call fnc_duws_deploy;
    {
        _x setVariable ["R3F_LOG_CF_depuis_usine", true, true];
        _x setVariable ["DUWS_buildSite", _siteKey, true];
        _x setVariable ["DUWS_buildLastGood", getPosATL _x];
    } forEach ((DUWS_compositions getOrDefault [_key, []]) select { !isNull _x });
};

// Broadcast: R3F's move and direct-sale conditions run it on every client. The crew is deleted before the move or the
// sale, so only friendly AI outside every player's group gives way; an enemy gunner or a squadmate holds the gun, and a
// drone's AI crew is the drone itself.
DUWS_fnc_buildCrewFree = {
    params ["_obj", "_player"];
    _obj getVariable ["DUWS_buildSite", ""] != "" && {getNumber (configFile >> "CfgVehicles" >> typeOf _obj >> "isUav") != 1} && {
        (crew _obj) findIf {
            alive _x && {side group _x != side group _player || {(units group _x) findIf { isPlayer _x } >= 0}}
        } < 0
    }
};

DUWS_fnc_buildCrewClear = {
    params ["_gun"];
    { if ((units group _x) findIf { isPlayer _x } < 0) then { _gun deleteVehicleCrew _x } } forEach crew _gun;
};

DUWS_fnc_buildCrew = {
    params ["_guns", "_blu", ["_roster", []]];
    private _empty = _guns select {
        alive _x && {isNull attachedTo _x} && {_x isKindOf "StaticWeapon"} && {crew _x isEqualTo []}
    };
    if (_empty isEqualTo []) exitWith {};
    private _man = [opfor_SOLDIER_X, blufor_SOLDIER_X] select _blu;
    private _grp = [getPos (_empty select 0), [EAST, WEST] select _blu, _empty apply {_man}, [], [],
        [opfor_ai_skill, blufor_ai_skill] select _blu] call BIS_fnc_spawnGroup;
    _grp deleteGroupWhenEmpty true;
    [_empty, _grp] call DUWS_fnc_manStatics;
    _roster append (units _grp);
};

// Dead gunners only: DUWS_fnc_buildCrewClear would also delete a drone's AI crew, which is the drone itself, and an enemy
// sitting in the gun.
DUWS_fnc_buildRecrew = {
    params ["_guns", "_blu", ["_roster", []]];
    {
        private _gun = _x;
        { _gun deleteVehicleCrew _x } forEach ((crew _gun) select { !alive _x });
    } forEach _guns;
    [_guns, _blu, _roster] call DUWS_fnc_buildCrew;
};

// The key, not the site record, tells a zone from a base: a load can restore the bases before the HQ site is registered.
// A zone's gunner joins its garrison roster so the zone's collect takes him; its wake mans the builds in
// DUWS_fnc_zoneManStatics, before the garrison stands.
DUWS_fnc_buildCrewSite = {
    params ["_guns", "_site"];
    if (_site == "") exitWith {};
    if ((_site select [0, 5]) isNotEqualTo "zone_") exitWith { [_guns, true] call DUWS_fnc_buildCrew };
    if (([_site] call fnc_site_alive) == 0) exitWith {};
    [_guns, ([_site] call DUWS_fnc_garrisonSideOf) isEqualTo "BLU", [_site] call fnc_zone_roster] call DUWS_fnc_buildCrew;
};

// Broadcast: R3F's factory condition runs it on every client (config.sqf).
DUWS_fnc_inBaseRing = {
    params ["_pos"];
    ((Array_of_FOBpos + [PosOfBLUHQ]) findIf { (_x distance2D _pos) <= DUWS_base_keep_radius }) >= 0
};

// Broadcast: R3F's create and sale run it on every client.
DUWS_fnc_buildContested = {
    params ["_factory"];
    (_factory getVariable ["DUWS_buildSite", ""]) in (missionNamespace getVariable ["DUWS_contestedSites", []])
};

// Broadcast: R3F's direct sale runs it on every client. A site's build needs no range, as the drop check already holds
// it within reach of its site.
DUWS_fnc_canSellTo = {
    params ["_obj", "_factory", "_range"];
    private _site = _obj getVariable ["DUWS_buildSite", ""];
    if (_site == "") exitWith { _obj distance _factory < _range };
    _factory getVariable ["DUWS_buildSite", ""] == _site
};

// Thaws a dropped carry under a damage guard for its fall. R3F's carry-end handler has already restored damage on every
// machine, and allowDamage does not follow ownership, so the server reclaims the object before it guards it.
DUWS_fnc_carryThaw = {
    params ["_obj"];
    _obj setOwner 2;
    _obj allowDamage false;
    _obj enableSimulationGlobal true;
    sleep 2;
    if (!isNull _obj) then { _obj allowDamage true };
};

// R3F reports every carried object after its drop (deplacer.sqf), still frozen where the carry set it down, so the check
// reads the pose the carrier chose. A site's build and a zone's flag must stay within reach of the site, and the builder
// vehicle's builds out of every base ring, so only a base's own budget fortifies it.
DUWS_fnc_carryDropped = {
    params ["_obj"];
    // A depot vehicle is thawed by its own placement (fnc_depot_place_finish).
    if (isNull _obj || {_obj getVariable ["DUWS_depot_placing", false]}) exitWith {};
    if (!isNull attachedTo _obj) exitWith { _obj enableSimulationGlobal true };
    private _site = _obj getVariable ["DUWS_buildSite", ""];
    private _bldv = _obj in DUWS_builds;
    private _flag = _obj isKindOf "FlagCarrierCore";
    private _bad = switch (true) do {
        case _bldv: { [getPosATL _obj] call DUWS_fnc_inBaseRing };
        case (_site != ""): { (_obj distance2D (([_site] call fnc_site_at) get "pos")) > BUILD_REACH };
        default { false };
    };
    private _msg = switch (true) do {
        case !_bad: { "STR_DUWS_T_CARRY_PLACED" };
        case _bldv: { "STR_DUWS_T_bldv_base_refused" };
        case _flag: { "STR_DUWS_T_flag_placement_failed" };
        default { "STR_DUWS_T_zonebuild_placement_failed" };
    };
    private _lastGood = _obj getVariable "DUWS_buildLastGood";
    // A new build has no good spot to go back to: R3F makes it far up in the sky before the carry.
    if (_bad && {isNil "_lastGood"}) exitWith {
        private _factory = _obj getVariable ["DUWS_buildFactory", objNull];
        // -1 is R3F's unlimited balance, which the builder vehicle's factory has on the clients only.
        private _credits = _factory getVariable ["R3F_LOG_CF_credits", -1];
        if (_credits != -1) then {
            _factory setVariable ["R3F_LOG_CF_credits", _credits + ([typeOf _obj] call DUWS_fnc_buildCost), true];
            _msg = "STR_DUWS_T_zonebuild_placement_refunded";
        };
        deleteVehicle _obj;
        (localize _msg) remoteExec ["hint", remoteExecutedOwner];
    };
    if (_bad) then { _obj setPosATL _lastGood } else { _obj setVariable ["DUWS_buildLastGood", getPosATL _obj] };
    (format [localize _msg, getText (configFile >> "CfgVehicles" >> typeOf _obj >> "displayName")]) remoteExec ["hint", remoteExecutedOwner];
    // Manned only once the thaw's guard is over, which would otherwise cut short the guard DUWS_fnc_manStatics holds.
    [_obj, _site] spawn {
        params ["_obj", "_site"];
        [_obj] call DUWS_fnc_carryThaw;
        [[_obj], _site] call DUWS_fnc_buildCrewSite;
    };
};
