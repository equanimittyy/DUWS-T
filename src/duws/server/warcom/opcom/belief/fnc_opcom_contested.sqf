// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several
// functions. Site contest is a belief fact, rebuilt once per OPCOM tick from the settled store (after decay
// and prune), so every reader in a tick sees one snapshot.
if (!isServer) exitWith {};

// A group netId is an "ent:id" string; zone/FOB/HQ-keyed rows are standing knowledge, not a sighting.
DUWS_fnc_opcom_beliefIsSighting = {
    params ["_key"];
    _key isEqualType "" && {(_key find ":") >= 1}
};

// Contested: a BLUFOR sighting within one grid cell of the site's edge -- some OPFOR knows BLUFOR is there. Zones,
// towns and bases alike, so a garrison buy and a base's upkeep read the same rule wherever they land.
DUWS_fnc_opcom_contestedUpdate = {
    private _sighted = [];
    {
        if ([_x] call DUWS_fnc_opcom_beliefIsSighting) then { _sighted pushBack (DUWS_opcom_belief_pos select _forEachIndex) };
    } forEach DUWS_opcom_belief_key;
    private _contested = createHashMap;
    if (_sighted isNotEqualTo []) then {
        {
            private _key = _x;
            if ((_key select [0, 5]) in ["zone_", "town_"] || {(_key select [0, 4]) == "FOB_"} || {_key == "HQ"}) then {
                private _site = [_key] call fnc_site_at;
                private _pos = _site getOrDefault ["pos", []];
                private _reach = (_site getOrDefault ["radius", 0]) + OPCOM_GRID_CELL;
                if (_pos isNotEqualTo [] && {(_sighted findIf { (_x distance2D _pos) <= _reach }) >= 0}) then {
                    _contested set [_key, true];
                };
            };
        } forEach keys DUWS_sites;
    };
    DUWS_opcom_contested = _contested;
    // R3F's create and sale run on the clients, which cannot read this server-side store.
    private _keys = keys _contested;
    _keys sort true;
    if (_keys isNotEqualTo (missionNamespace getVariable ["DUWS_contestedSites", []])) then {
        DUWS_contestedSites = _keys;
        publicVariable "DUWS_contestedSites";
    };
};

// Nil until OPCOM's loop starts, a few seconds after WARCOM init.
DUWS_fnc_opcom_siteContested = {
    params ["_key"];
    !isNil "DUWS_opcom_contested" && {DUWS_opcom_contested getOrDefault [_key, false]}
};
