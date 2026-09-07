// Locality: server. Definition file (several functions), executed by the registry ahead of any caller.
//
// Holds interaction-critical objects (the HQ fixtures, zone flags, FOB, MHQ) out of the Zeus curator, so a
// game master cannot select, move or delete them by accident. The lock is re-asserted on a slow loop,
// because a mod running its own curator population can hand a locked object back.
if (!isServer) exitWith {};

DUWS_guarded = [];

// Hold one object out of the Zeus curator. Idempotent. DUWS_zeusEditable is the flag fnc_zeus_objects_init
// sets once it has offered an object; setting it here stops that daemon ever offering this one, and
// removeCuratorEditableObjects undoes an add it has already made.
fnc_guard_lock = {
	params ["_obj"];
	if (isNull _obj) exitWith {};
	if (!isNil "Curator" && {!isNull Curator}) then { Curator removeCuratorEditableObjects [[_obj], true]; };
	_obj setVariable ["DUWS_zeusEditable", true];
};

// Register an object to keep locked. Locks it now; the daemon re-asserts it from then on.
fnc_guard_register = {
	params ["_obj"];
	if (isNull _obj) exitWith {};
	[_obj] call fnc_guard_lock;
	DUWS_guarded pushBackUnique _obj;
};

// Re-assert the lock on every live guarded object (countering a mod's re-add); drop any that have gone.
fnc_guard_watch = {
	while {true} do {
		// A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
		try {
			{ [_x] call fnc_guard_lock } forEach DUWS_guarded;
			DUWS_guarded = DUWS_guarded select { !isNull _x };
			sleep 30;
		} catch {
			["ERROR", "GUARD", format ["asset guard threw, held alive: %1", _exception]] call fnc_log;
			sleep 10;
		};
	};
};
