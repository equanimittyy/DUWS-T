
if (!isServer) exitWith {};

// Offered to the curator once and flagged on the object itself, so a pass carries only what has
// appeared since the last one. The whole set went over every 30 s before, which on a generated
// campaign is thousands of objects re-submitted and re-synced to the curator's machine for the
// handful that were new. The flag is deleted with the object, so a prop that fnc_duws_stow removed
// is offered again when fnc_duws_deploy rebuilds the composition.
private _fnc_offer = {
	params ["_objs"];
	private _new = _objs select { !(_x getVariable ["DUWS_zeusEditable", false]) };
	if (count _new == 0) exitWith {};
	// One call for the batch: addCuratorEditableObjects takes an array, so the per-unit form would
	// pay the call overhead once for every unit and vehicle on the map.
	Curator addCuratorEditableObjects [_new, true];
	{ _x setVariable ["DUWS_zeusEditable", true] } forEach _new;
};

while {true} do {
	// A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
	try {

	if (ZeusStatus == 1) then {
		[(allUnits + vehicles) select { side _x in [west, civilian] }] call _fnc_offer;
	} else {
		[allMissionObjects "ALL"] call _fnc_offer;
	};

	sleep 30;

	} catch {
		["ERROR", "ZEUS", format ["curator sync threw, thread held alive: %1", _exception]] call fnc_log;
		sleep 10;
	};

};