// Locality: server or client -- fnc_custom_faction_init calls it on the server,
// fnc_custom_faction_capture on a client. It only parses text into locals, so either is
// safe.
// Parse pasted custom-faction text into ["<var> = <class>", ...] assignment
// fragments, then report which required faction keys the paste left missing or
// pointing at a class that doesn't exist. Shared by the paste screen's submit
// validation (client) and the deferred faction build (server).
//
// Side effect: compiling the fragments assigns the faction globals. That is the
// intent server-side; on the client it is a transient pre-check, overwritten when
// the server's data is applied. Every required key is cleared first so a leftover
// value from a previous faction/paste can't mask a key this paste never defines --
// a misspelled key (blufor_SOLDER_X) leaves its canonical name (blufor_SOLDIER_X)
// cleared, so it is reported missing rather than silently accepted.
//
// Returns [_pairs, _valid, _bad]:
//   _pairs   - compiled assignment fragments (consumed by the server build)
//   _valid   - true when every required key is set to a class that exists
//   _bad     - full names of required keys that are missing or resolve to a
//              non-existent class (e.g. "blufor_SOLDIER_X")

params ["_side", "_text"];

private _prefix = if (_side == "opfor") then {"opfor_"} else {"blufor_"};

// Core combat keys a faction must define. What counts as required, and why the request-menu
// catalogue is not, is fnc_faction_schema's to say.
private _requiredKeys = ([_side] call fnc_faction_schema) apply {_x select 0};

// keep only "<prefix>..." lines, break each on ";", drop path-like junk
private _pairs = (_text splitString (toString [13,10])) select { _prefix in _x };
_pairs = flatten (_pairs apply { _x splitString ";" });
_pairs = _pairs select { !(["/", _x] call BIS_fnc_inString) };

// Clear the required keys, then apply the paste over the top.
{ missionNamespace setVariable [_x, ""]; } forEach _requiredKeys;
{ call compile _x; } forEach _pairs;

// A key is OK if it holds at least one classname and every classname it holds
// exists (a role may be a single class or an array of classes, as AutoDetect does).
// An unset key reads as "" here, which fails the class check -> reported as bad.
private _fnc_isOk = {
    private _v = missionNamespace getVariable [_this, ""];
    private _classes = if (_v isEqualType []) then {_v} else {[_v]};
    (count _classes > 0) && {(_classes findIf {
        !(_x isEqualType "") || {_x isEqualTo ""} || {!isClass (configFile >> "CfgVehicles" >> _x)}
    }) < 0}
};

private _bad = _requiredKeys select { !(_x call _fnc_isOk) };
private _valid = _bad isEqualTo [];

[_pairs, _valid, _bad]
