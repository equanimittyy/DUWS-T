// Locality: server -- the team's record of which permanent supports it has bought.
//
// The unlock flags themselves stay broadcast booleans and remain every client's fast path. This
// holds the same fact as data a campaign save can walk, rather than as a scatter of named globals
// a restore would have to know one by one. Idempotent, because two players can reach a row in the
// same frame and only one of them paid for it.
if (!isServer) exitWith {};

params [["_key", ""]];
if (_key == "" || {_key in DUWS_support_permanent}) exitWith {};

DUWS_support_permanent pushBack _key;
publicVariable "DUWS_support_permanent";

// The BLUFOR radio level is the count of radio tiers the team owns, recomputed from the permanent
// record rather than incremented -- gated buying means the count equals the tier -- so it cannot drift
// and a save that restored the record restores the level with it. Server-only, like the drift that
// reads it. Not a radio grant leaves it untouched.
DUWS_bluforRadioLevel = { _x in ["radio1", "radio2", "radio3"] } count DUWS_support_permanent;

// The Intelligence Center's level count, recomputed from the record for the same reason and read by
// the OPCOM tick's intel roll and the intel payout's contact share. Server-only, like both.
DUWS_intelLevel = { _x in ["intel1", "intel2", "intel3", "intel4"] } count DUWS_support_permanent;

private _fortWas = missionNamespace getVariable ["DUWS_fortLevel", 0];
DUWS_fortLevel = { _x in ["fort1", "fort2", "fort3", "fort4"] } count DUWS_support_permanent;
if (DUWS_fortLevel != _fortWas) then {
    [_fortWas, DUWS_fortLevel] call DUWS_fnc_baseBuildGrant;
    [_fortWas, DUWS_fortLevel] call DUWS_fnc_zoneFortGrant;
};

// Announced from here rather than from the buyer's own purchase: this is the one place that runs
// exactly once per unlock, so the two players who reach a row in the same frame raise one card
// between them. A permanent row is bought for the whole team, so the whole team is told.
[format ["unlock_%1", _key], []] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

["INFO", "ECON", format ["permanent support unlocked: %1", _key]] call fnc_log;
