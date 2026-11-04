// Locality: server. Caller: fnc_taskforce_tick, in Advanced. Every task force is a live-only tasking of BLUFOR's
// commander, so a squad that joins by any path -- handed over, spawned, restored, or returned by a commander who left
// -- is taken on the next tick. A tasking is bound to its squad's group, and an unbound one (restored, its group gone
// with the last session) to the task force of its name, since names may repeat but a group is one squad. A tasking
// whose task force is gone leaves here, in the OPCOM thread, never under a task step walking the store.
params ["_taskforces"];
private _cmd = DUWS_opcom_cmds get "BLU";

private _names = _taskforces apply { _x select 2 };
private _gone = ((_cmd get "taskings") select { !((_x getOrDefault ["taskforce", ""]) in _names) }) apply { _x get "id" };
if (_gone isNotEqualTo []) then {
	_cmd set ["taskings", (_cmd get "taskings") select { !((_x get "id") in _gone) }];
	{ { _x set ["units", (_x get "units") - _gone] } forEach (_x get "roles") } forEach (_cmd get "attacks");
};

private _taskings = _cmd get "taskings";
{
	_x params ["_group", "", "_tfName"];
	if (!isNull _group && {(units _group) findIf {alive _x} >= 0}) then {
		private _veh = vehicle leader _group;
		private _moveType = switch (true) do {
			case (_veh isKindOf "Helicopter"): { "rotary" };
			case (_veh isKindOf "Plane"): { "fixed" };
			case (_veh isKindOf "Ship"): { "boat" };
			case (_veh isKindOf "Tank"): { "tracked" };
			case (_veh isKindOf "Car"): { "wheeled" };
			default { "inf" };
		};
		private _i = _taskings findIf { (_x get "grp") isEqualTo netId _group };
		if (_i < 0) then { _i = _taskings findIf { (_x get "grp") isEqualTo "" && {(_x getOrDefault ["taskforce", ""]) isEqualTo _tfName} } };
		private _t = if (_i >= 0) then { _taskings select _i } else {
			private _pos = getPosASL leader _group;
			private _force = [_group] call DUWS_fnc_opcom_effForceLive;
			private _new = [[
				["order", "guard"], ["target", _pos], ["pos", _pos], ["moveType", _moveType], ["menu", "taskforce"],
				["taskforce", _tfName], ["fullForce", _force], ["effForce", _force], ["status", "moving"], ["grp", netId _group]
			]] call DUWS_fnc_opcom_taskingNew;
			["INFO", "OPCOM", format ["BLUFOR commander takes task force %1 as tasking %2", _tfName, _new get "id"]] call fnc_log;
			_new
		};
		_t set ["grp", netId _group];
		// The hull a squad rides decides how it moves, and a squad that lost its hull walks.
		_t set ["moveType", _moveType];

		private _attack = (_cmd get "attacks") select { (_x get "id") isEqualTo (_t get "boundTo") };
		private _label = if (_attack isEqualTo []) then { mapGridPosition (_t get "target") } else { (_attack select 0) get "label" };
		private _order = switch (_t get "order") do {
			case "capture": { ["capture", _label] };
			case "move": { [["hold", mapGridPosition (_t get "target")], ["stage", _label]] select (_attack isNotEqualTo []) };
			case "intercept": { ["respond", mapGridPosition (_t get "target")] };
			case "patrol": { ["patrol", mapGridPosition (_t get "target")] };
			case "probe": { ["probe", mapGridPosition (_t get "target")] };
			default { ["hold", mapGridPosition (_t get "pos")] };
		};
		_group setVariable ["DUWS_taskforce_order", _order];
	};
} forEach _taskforces;
