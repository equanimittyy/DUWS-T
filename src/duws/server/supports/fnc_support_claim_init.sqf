// The single-claimant lock every support asset is acquired through.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

// Server-authoritative fire-mission slot, one per support type. Unlocks and cooldowns are both
// per player, so nothing stopped two squad leads walking mortars onto the map at the same moment
// and talking over each other on the net for the whole salvo.
//
// The slot carries an expiry as well as an explicit release. A caller that disconnects, dies or
// errors out between claiming and releasing would otherwise hold its support type for the rest
// of the campaign, and a fire mission that never comes back is a worse bug than two at once.
fnc_support_try_claim = {
	if (!isServer) exitWith {};
	params [["_type", ""], ["_hold", 300], ["_requester", objNull], ["_replyVar", ""]];
	private _key = format ["duws_support_busy_%1", _type];
	private _ok = time > (missionNamespace getVariable [_key, 0]);
	if (_ok) then { missionNamespace setVariable [_key, time + _hold]; };
	[_replyVar, _ok] remoteExec ["fnc_support_reply", _requester];
};

fnc_support_release = {
	if (!isServer) exitWith {};
	params [["_type", ""]];
	missionNamespace setVariable [format ["duws_support_busy_%1", _type], 0];
};

fnc_support_reply = {
	params [["_replyVar", ""], ["_ok", false]];
	missionNamespace setVariable [_replyVar, _ok];
};

// Client half of the slot handshake, same shape as fnc_pool_spend: blocks on the server's
// ruling, so callers must already be scheduled. Refuses on timeout rather than falling through --
// two simultaneous fire missions is the thing this exists to prevent, so a dropped reply must
// not read as a free slot.
fnc_support_claim = {
	params [["_type", ""], ["_hold", 300]];
	duws_support_seq = (missionNamespace getVariable ["duws_support_seq", 0]) + 1;
	private _replyVar = format ["duws_support_reply_%1", duws_support_seq];
	[_type, _hold, player, _replyVar] remoteExec ["fnc_support_try_claim", 2];
	private _deadline = diag_tickTime + 5;
	waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
	private _replied = !isNil _replyVar;
	private _ok = missionNamespace getVariable [_replyVar, false];
	missionNamespace setVariable [_replyVar, nil];
	if (!_replied) then { ["WARN", "SUPPORT", format ["fnc_support_claim: no reply for %1, refused", _type]] call fnc_log; };
	_ok
};

// High Command aircraft lock. One airborne at a time across the whole team, then a global cooldown
// everyone waits out. Kept apart from the fire-mission slot above because a sortie is long and its two
// refusal states -- one already on station, or the cooldown still running -- carry different hints, and
// the cooldown end is broadcast so any client can show the time left without another round-trip.
fnc_hcair_claim = {
	if (!isServer) exitWith {};
	params [["_type", ""], ["_requester", objNull], ["_replyVar", ""]];
	private _activeVar = format ["DUWS_hcair_active_%1", _type];
	private _untilVar = format ["DUWS_hcair_activeUntil_%1", _type];
	private _cdVar = format ["DUWS_hcair_cooldownEnd_%1", _type];
	private _active = missionNamespace getVariable [_activeVar, false];
	// Safety expiry: a caller that disconnects or errors between claim and end would otherwise hold the
	// slot for the rest of the campaign, so an over-age active claim is treated as free.
	private _stale = _active && {time > (missionNamespace getVariable [_untilVar, 0])};
	private _ok = (!_active || _stale) && {time > (missionNamespace getVariable [_cdVar, 0])};
	if (_ok) then {
		missionNamespace setVariable [_activeVar, true];
		missionNamespace setVariable [_untilVar, time + 1800];
	};
	[_replyVar, _ok] remoteExec ["fnc_support_reply", _requester];
};

// Sortie over (RTB, shot down, or no-show): free the slot and start the global cooldown. The end time
// is broadcast (public) so the refusal hint on every client can read how long is left.
fnc_hcair_endActive = {
	if (!isServer) exitWith {};
	params [["_type", ""], ["_cooldown", 600]];
	missionNamespace setVariable [format ["DUWS_hcair_active_%1", _type], false];
	missionNamespace setVariable [format ["DUWS_hcair_cooldownEnd_%1", _type], time + _cooldown, true];
};

// Client half of the aircraft lock, same handshake shape as fnc_support_claim. On refusal it shows the
// reason -- cooldown with time left, or one already on station -- and hands the comm-menu entry back,
// so a refused request costs the caller nothing.
fnc_hcair_claim_request = {
	params [["_type", ""], ["_commItem", ""], ["_busyKey", ""], ["_cdKey", ""]];
	duws_hcair_seq = (missionNamespace getVariable ["duws_hcair_seq", 0]) + 1;
	private _replyVar = format ["duws_hcair_reply_%1", duws_hcair_seq];
	[_type, player, _replyVar] remoteExec ["fnc_hcair_claim", 2];
	private _deadline = diag_tickTime + 5;
	waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
	private _ok = missionNamespace getVariable [_replyVar, false];
	missionNamespace setVariable [_replyVar, nil];
	if (!_ok) then {
		private _left = (missionNamespace getVariable [format ["DUWS_hcair_cooldownEnd_%1", _type], 0]) - time;
		if (_left > 0) then {
			hint format [localize _cdKey, floor (_left / 60), floor (_left % 60)];
		} else {
			hint localize _busyKey;
		};
		if (_commItem isNotEqualTo "") then { [_commItem] call fnc_support_comm_add };
	};
	_ok
};
