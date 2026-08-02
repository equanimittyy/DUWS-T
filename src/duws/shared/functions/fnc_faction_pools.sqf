// Locality: server -- faction generation is server-only (init_hq/fnc_BLUFOR_faction_init.sqf:1) and
// every path that draws a class from a pool raises units, which only the server does.
//
// Faction detection finds several classnames for most roles: every APC a faction defines, every
// rifleman. The role globals hold *one* classname, because every spawner hands them straight to
// BIS_fnc_spawnGroup or createVehicle. Something has to collapse many to one.
//
// This publishes both halves: the pool under DUWS_factionPool_<role>, and a stable representative in
// the global itself so the two hundred-odd sites that read opfor_SOLDIER_X directly keep working.
// Variety then comes from picking out of the pool at the moment something spawns.
//
// What this replaces: a permanent thread per role -- 38 on the OPFOR side and 34 on the BLUFOR --
// each waking every 300 s to re-pick and publicVariable its answer for the rest of the campaign.
// That was wrong in three ways beyond its cost. The global holds one value at a time, so every zone
// raised inside the same five-minute window fielded the *identical* APC and two zones raised six
// minutes apart differed -- variety across time, where what a player sees is one moment. It made a
// faction's identity drift, which is the one thing auto-detection exists to establish. And it paid
// for both with seventy permanent scripts and seventy network writes every five minutes, for values
// only ever read at the instant something spawns.

// The representative is the first entry rather than a random one: a faction's own file lists its
// mainstay first, and a stable answer is what makes the request menu and the readouts repeatable.
fnc_faction_pools_publish = {
    params ["_names"];
    {
        private _role = _x;
        private _data = missionNamespace getVariable _role;
        if (!isNil "_data") then {
            private _pool = if (_data isEqualType []) then { _data } else { [_data] };
            _pool = _pool select { _x isEqualType "" && {_x != ""} };
            if !(_pool isEqualTo []) then {
                missionNamespace setVariable [format ["DUWS_factionPool_%1", _role], _pool];
                missionNamespace setVariable [_role, _pool select 0, true];
            };
        };
    } forEach _names;
};

// One classname for a role, drawn at the moment of use. Called by the spawn funnels rather than by
// every reader: a squad raised now gets men from across its faction's pool, and two zones raised in
// the same second field different vehicles -- which is the variety a player actually sees.
//
// Falls back to the global for a role with no pool, which is every role a hand-written faction file
// defines as a plain string, and "" for one the faction never defined at all. fnc_opforRoles drops
// the empty answer; inventing a class here would hide a missing role behind a unit that spawns.
fnc_faction_pick = {
    params ["_name"];
    private _pool = missionNamespace getVariable [format ["DUWS_factionPool_%1", _name], []];
    if !(_pool isEqualTo []) exitWith { selectRandom _pool };
    private _v = missionNamespace getVariable [_name, ""];
    if !(_v isEqualType []) exitWith { _v };
    if (_v isEqualTo []) exitWith { "" };
    selectRandom _v
};
