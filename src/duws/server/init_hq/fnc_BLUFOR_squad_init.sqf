if (!isServer) exitWith {};
// Locality: server -- called from server/server_init.sqf once the BLUFOR faction table is built.
//
// What the player can buy, as data. Roles are named rather than referenced: a faction table that
// omits a role leaves its global undefined, and an undefined name inside an array literal reaches
// BIS_fnc_spawnGroup as a nil the engine silently skips -- naming it keeps the gap visible in the
// boot log instead.

["INFO", "BOOT", "Squad File Init"] call fnc_log;

// Rosters are shared: the mechanised and armour sections field the same infantry team, and the
// motorised section fields the recon team. Held apart from the squad table below so changing what
// an infantry team is stays one edit rather than three that can drift.
// --DUWS-UNITCOMP BEGIN name="BLUFOR teams" kind=team row="team, roles..." fields="team, roles" prefix=blufor_--
DUWS_bluforTeams = [
    ["recon", ["blufor_SPECOPS_X", "blufor_SPECOPS_GL_X", "blufor_SPECOPS_MG_X", "blufor_SPECOPS_LAT_X"]],
    ["infantry", ["blufor_SOLDIER_TL_X", "blufor_SOLDIER_GL_X", "blufor_SOLDIER_LAT_X", "blufor_SOLDIER_AR_X"]],
    ["squad", ["blufor_SOLDIER_SL_X", "blufor_SOLDIER_X", "blufor_SOLDIER_X", "blufor_SOLDIER_GL_X", "blufor_SOLDIER_GL_X", "blufor_SOLDIER_LAT_X", "blufor_SOLDIER_LAT_X", "blufor_SOLDIER_AR_X"]]
];
// --DUWS-UNITCOMP END--

// The variable in the first column is the join with the request dialogs: fnc_request_squad and
// fnc_request_squad_fob switch on a listbox index and read these names directly, so a renamed row
// leaves that menu entry reading a variable nothing publishes. Row order is free -- the listbox is
// built in shared/includes/request_menu.hpp, not from this table.
// The vehicle pool is drawn once, at boot rather than per purchase: a section's transport is a
// property of the campaign, so the same request twice does not hand back two different vehicles.
// --DUWS-UNITCOMP BEGIN name="BLUFOR squads" kind=composition row="variable, CP cost, team, vehicle pool" fields="variable, CP cost, team, vehicle pool" prefix=blufor_--
DUWS_bluforSquads = [
    ["blufor_RECON_TEAM_X", 8, "recon", []],
    ["blufor_INF_SQUAD_X", 12, "squad", []],
    ["blufor_MOTOR_SECTION_X", 25, "recon", ["blufor_CAR_PATROL1_X"]],
    ["blufor_MECH_SECTION_X", 40, "infantry", ["blufor_APC_PATROL1_X", "blufor_APC_PATROL2_X"]],
    ["blufor_ARMOR_SECTION_X", 50, "infantry", ["blufor_TANK_PATROL1_X"]]
];
// --DUWS-UNITCOMP END--

// Names to classnames, dropping every role the faction table does not define.
private _resolve = {
    params ["_names"];
    private _out = [];
    { if (_x != "") then { _out pushBack _x } } forEach (_names apply { missionNamespace getVariable [_x, ""] });
    _out
};

switch (VERSION_X) do {
	case "MODERN": {
		{
			_x params ["_var", "_cost", "_team", "_vehPool"];
			private _ti = DUWS_bluforTeams findIf { (_x select 0) isEqualTo _team };
			private _roles = if (_ti < 0) then { [] } else { (DUWS_bluforTeams select _ti) select 1 };
			private _roster = [_roles] call _resolve;
			private _veh = [_vehPool] call _resolve;
			// Counted before the vehicle is prepended, while the two lists still line up with what
			// the table asked for.
			private _lost = (count _roles - count _roster) + (count _vehPool - count _veh);
			if (count _veh > 0) then { _roster = [selectRandom _veh] + _roster };

			// Broadcast on write: the request dialogs run on the client and read these directly.
			missionNamespace setVariable [_var, [_roster, _cost], true];

			// A section that lost roles still spawns, just thinner, and nothing on the ground says
			// so -- which is how a faction mod missing one class reads as a balance problem.
			if (_lost > 0) then {
				["WARN", "FACTION", format ["%1: %2 of its classes are not defined by this faction",
					_var, _lost]] call fnc_log;
			};
		} forEach DUWS_bluforSquads;
	};
};

["INFO", "BOOT", format ["Squad file Armor Section: %1", str blufor_ARMOR_SECTION_X]] call fnc_log;
