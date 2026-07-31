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
["INFO", "ECON", format ["permanent support unlocked: %1", _key]] call fnc_log;
