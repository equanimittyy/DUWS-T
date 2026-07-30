// Locality: server -- the debug window remoteExecs to target 2.
/*
    fnc_debug_econ_server.sqf
    The half of the CP/AP/town/escalation debug tool that has to run on the server: everything
    below the two campaign pools is server-only state. civ_locations, civ_town_rep, civ_town_ap and
    the escalation counters are never broadcast, so the window cannot read them and cannot write
    them either -- it asks here for a snapshot and sends its edits back through the same door.

    Modes: "snapshot" answers the caller, "rep" / "ap" adjust one town, "escalation" moves the
    destroyed-house count.
*/
if (!isServer) exitWith {};

params ["_mode", "_caller", ["_args", []]];
if (isNull _caller) exitWith {};

// Re-checked here rather than trusted to the window: this is reachable by remoteExec from any
// client, and nothing below charges for what it hands out.
if !((vehicleVarName _caller) in game_master) exitWith {};

switch (toLower _mode) do {

    case "snapshot": {
        private _reps = missionNamespace getVariable ["civ_town_rep", []];
        private _aps  = missionNamespace getVariable ["civ_town_ap", []];
        private _locs = missionNamespace getVariable ["civ_locations", []];

        // One row per town: the name the map readout uses, whether it has a reputation at all, that
        // figure and its worth. The flag is carried rather than a nil reputation, the same way
        // fnc_civ_townQuery does it -- a town in RAVAGE, WBK or a civilians-off campaign registers
        // none, and 0 would report that as a town that feels neutral about the player.
        private _towns = [];
        {
            private _name = text _x;
            if (_name isEqualTo "") then { _name = format ["Unnamed%1", _forEachIndex] };
            private _hasRep = _forEachIndex < count _reps;
            _towns pushBack [_forEachIndex, _name, _hasRep,
                if (_hasRep) then { _reps select _forEachIndex } else { 0 },
                _aps param [_forEachIndex, 0]];
        } forEach _locs;

        // Escalation is absent entirely in RAVAGE and WBK -- fnc_escalation returns before setting
        // any of it -- so every field is defaulted rather than read raw.
        private _escalation = [
            missionNamespace getVariable ["escalation_destroyed", -1],
            missionNamespace getVariable ["escalation_budget", 0],
            missionNamespace getVariable ["escalation_tier", 0],
            missionNamespace getVariable ["escalation_level", 0],
            missionNamespace getVariable ["escalation_multiplier", 1]
        ];

        [_towns, _escalation] remoteExec ["fnc_debug_econ_fill", _caller];
    };

    case "rep": {
        _args params ["_townIndex", "_delta"];
        // Through the campaign's own writer, not a raw array write: it owns the clamp, the rounding
        // and the marker repaint, and a debug tool that bypassed them would show a town the window
        // and the map disagreed about.
        [_townIndex, _delta, "debug menu"] call fnc_town_rep_adjust;
    };

    case "ap": {
        _args params ["_townIndex", "_delta"];
        private _aps = missionNamespace getVariable ["civ_town_ap", []];
        if (_townIndex < 0 || _townIndex >= count _aps) exitWith {};
        // Floored at zero: worth is what a town pays whichever side holds it, and a negative would
        // have the economy tick charge the owner for holding ground.
        _aps set [_townIndex, ((_aps select _townIndex) + _delta) max 0];
        ["INFO", "ECON", format ["TOWNAP %1 -> %2 (debug menu)", _townIndex, _aps select _townIndex]] call fnc_log;
    };

    case "escalation": {
        _args params ["_delta"];
        if (isNil "escalation_tier" || {escalation_tier <= 0}) exitWith {
            ["Escalation is not running in this campaign."] remoteExec ["hint", _caller];
        };
        escalation_destroyed = (escalation_destroyed + _delta) max 0;
        // Recomputed in both directions, unlike the BuildingChanged handler, which only ever raises
        // the level -- a tool that can take houses back has to be able to walk the level down with
        // them or the price multiplier stays where the highest count left it.
        escalation_level = (floor (escalation_destroyed / escalation_tier)) min 11;
        escalation_multiplier = 1 + (escalation_level / 10);
        publicVariable "escalation_multiplier";
        ["INFO", "ECON", format ["Escalation set to %1 destroyed, level %2, prices x%3 (debug menu)",
            escalation_destroyed, escalation_level, escalation_multiplier]] call fnc_log;
    };
};
