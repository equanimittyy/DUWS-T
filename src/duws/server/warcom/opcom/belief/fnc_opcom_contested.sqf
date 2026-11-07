// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several
// functions. Site contest is rebuilt once per OPCOM tick, so every reader in a tick sees one snapshot.
if (!isServer) exitWith {};

// A group netId is an "ent:id" string; zone/FOB/HQ-keyed rows are standing knowledge, not a sighting.
DUWS_fnc_opcom_beliefIsSighting = {
    params ["_key"];
    _key isEqualType "" && {(_key find ":") >= 1}
};

// One test on either side's ground: at a BLUFOR site it finds the attackers, at an OPFOR site the defenders fighting
// back. An OPFOR zone is also contested while BLUFOR stand on its ground, because an assault outlives its last
// defender: a zone buy landing then raises men or a hardpoint in front of the player and refuses the capture they
// earned. Zones, towns and bases alike, so a garrison buy and a base's upkeep read the same rule.
DUWS_fnc_opcom_contestedUpdate = {
    private _contested = createHashMap;
    {
        private _key = _x;
        private _site = _y;
        if ((_key select [0, 5]) in ["zone_", "town_"] || {(_key select [0, 4]) == "FOB_"} || {_key == "HQ"}) then {
            private _assault = (_key select [0, 5]) == "zone_" && {!([_key] call fnc_zone_bluforHeld)};
            private _men = [];
            private _foes = false;
            {
                private _ground = !(_x isKindOf "Air");
                {
                    if (side _x == EAST) then {
                        if ((_x call fnc_unit_standing) && {[_x] call fnc_duws_engaged}) then { _men pushBack _x };
                    } else {
                        if (_assault && {_ground} && {side _x == WEST} && {_x call fnc_unit_standing}) then { _foes = true };
                    };
                } forEach ([crew _x, [_x]] select (_x isKindOf "CAManBase"));
            } forEach ((_site get "pos") nearEntities [["CAManBase", "LandVehicle", "Air"], _site get "radius"]);
            if (_men isNotEqualTo [] || {_foes}) then {
                _contested set [_key, true];
                if (!(_key in DUWS_opcom_contested) && {_key == "HQ" || {(_key select [0, 4]) == "FOB_"}
                    || {(_key select [0, 5]) == "zone_" && {[_key] call fnc_zone_bluforHeld}}}) then {
                    [_site getOrDefault ["label", ""], _men] call fnc_enemy_contact;
                };
            };
        };
    } forEach DUWS_sites;
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
