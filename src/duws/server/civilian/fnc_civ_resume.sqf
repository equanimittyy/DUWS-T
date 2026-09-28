// The counterpart to the call-over: putting a civilian back to what they were doing before the
// player interrupted them. Every ending uses it -- a refusal, a granted request, a declined
// surrender, and the panic calm-down -- so none of them can drift apart.
//
// The pause before it is the point. Without it the reply and the turn land in the same frame, so
// the player reads what was said to them after the speaker has already moved. Spawned rather than
// slept in place because the callers are reached by remoteExec from a client's menu action, which
// is not a context sleep can be relied on in.
if (!isServer) exitWith {};
params ["_civilian"];
if (isNull _civilian) exitWith {};
_civilian spawn {
	sleep (1 + random 1);
	if (!alive _this) exitWith {};
	// A shot fired mid-conversation panics the civilian while the dialog is still open, so the
	// row the player then picks lands here on someone already running. Re-issuing would draw a
	// circuit around a fleeing unit and leave its CYCLE in front of the one the calm-down adds
	// a minute later, which the group never walks past. The panic owns the resume in that case.
	if (_this getVariable ["DUWS_civ_panicked", false]) exitWith {};
	private _idx = _this getVariable ["civ_locIndex", -1];
	private _buildings = if (_idx < 0) then { [] } else {
		(missionNamespace getVariable [format ["civ_buildings_%1", _idx], []]) select { !isNull _x }
	};
	[[group _this], _buildings] spawn fnc_civ_wp_Tomata;
};
