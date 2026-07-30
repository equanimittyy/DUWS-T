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
