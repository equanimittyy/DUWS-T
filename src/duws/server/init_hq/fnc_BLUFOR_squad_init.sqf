if (!isServer) exitWith {};
// Locality: server -- called from server/server_init.sqf once the BLUFOR faction table is built.
//
// What the player can buy, as data. Roles are named rather than referenced: a faction table that
// omits a role leaves its global undefined, and an undefined name inside an array literal reaches
// BIS_fnc_spawnGroup as a nil the engine silently skips -- naming it keeps the gap visible in the
// boot log instead.

["INFO", "BOOT", "Squad File Init"] call fnc_log;

// The team named in column 3 is a row on DUWS_teamRosters (shared/functions/fnc_spawn_vocab),
// which the OPFOR zone band raises out of too: a team is a composition of roles, and the side
// supplies the men. Rosters are shared inside this table as well -- the mechanised and armour
// sections field the same team, and the motorised section fields the recon team.

// The variable in the first column is the join with the request dialogs: fnc_request_squad and
// fnc_request_squad_fob switch on a listbox index and read these names directly, so a renamed row
// leaves that menu entry reading a variable nothing publishes. Row order is free -- the listbox is
// built in shared/includes/request_menu.hpp, not from this table.
// The vehicle pool is drawn once, at boot rather than per purchase: a section's transport is a
// property of the campaign, so the same request twice does not hand back two different vehicles.
// --DUWS-UNITCOMP BEGIN name="BLUFOR squads" kind=composition row="variable, CP cost, team, vehicle pool, AP cost" fields="variable, CP cost, team, vehicle pool, AP cost" prefix=blufor_--
// AP cost is a light spend on the sections that field a vehicle -- the crewed capability, distinct
// from the empty vehicles the request menu hands out CP-only. Infantry is 0: it is the accessible
// tier-1 baseline. Charged on both the High Command and Task Force forms, since both field the hull.
DUWS_bluforSquads = [
    ["blufor_RECON_TEAM_X", 8, "recon", [], 0],
    ["blufor_INF_SQUAD_X", 12, "squad", [], 0],
    ["blufor_MOTOR_SECTION_X", 25, "recon", ["blufor_ARMED_CAR1_X"], 5],
    ["blufor_MECH_SECTION_X", 40, "team", ["blufor_APC1_X", "blufor_APC2_X"], 15],
    ["blufor_ARMOR_SECTION_X", 50, "team", ["blufor_MBT_TANK1_X"], 25]
];
// --DUWS-UNITCOMP END--

// Names to classnames, dropping every vehicle the faction table does not define. The men come from
// the shared roster instead, which resolves its own names.
private _resolve = {
    params ["_names"];
    private _out = [];
    { if (_x != "") then { _out pushBack _x } } forEach (_names apply { missionNamespace getVariable [_x, ""] });
    _out
};

switch (VERSION_X) do {
	case "MODERN": {
		{
			_x params ["_var", "_cost", "_team", "_vehPool", ["_apCost", 0]];
			private _row = [_team] call DUWS_fnc_teamRow;
			if (_row isEqualTo []) then {
				["ERROR", "FACTION", format ["%1 names team %2, which no roster row claims -- it would be sold empty",
					_var, _team]] call fnc_log;
			} else {
				private _roster = [_team, "blufor"] call DUWS_fnc_teamRoster;
				private _veh = [_vehPool] call _resolve;
				// Counted against what the row asked for, before the vehicle is prepended and while
				// the two lists still line up.
				_row params ["", "_roles", "_leader"];
				private _wanted = (count _roles) + ([0, 1] select (_leader != ""));
				private _lost = ((_wanted - count _roster) max 0) + (count _vehPool - count _veh);
				if (count _veh > 0) then { _roster = [selectRandom _veh] + _roster };

				// Broadcast on write: the request dialogs run on the client and read these directly.
				missionNamespace setVariable [_var, [_roster, _cost, _apCost], true];

				// A section that lost roles still spawns, just thinner, and nothing on the ground says
				// so -- which is how a faction mod missing one class reads as a balance problem.
				if (_lost > 0) then {
					["WARN", "FACTION", format ["%1: %2 of its classes are not defined by this faction",
						_var, _lost]] call fnc_log;
				};
			};
		} forEach DUWS_bluforSquads;
	};
};

["INFO", "BOOT", format ["Squad file Armor Section: %1", str blufor_ARMOR_SECTION_X]] call fnc_log;
