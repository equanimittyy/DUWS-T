// Parse pasted custom-faction text into ["<var> = <class>", ...] assignment
// fragments and report whether the faction's base rifleman resolves to a real
// CfgVehicles class. Shared by the paste screen's submit validation (client) and
// the deferred faction build (server) so both agree on what counts as valid.
//
// Side effect: compiling the fragments assigns the faction globals (e.g.
// blufor_SOLDIER_X). That is the intent server-side; on the client it is a
// transient pre-check, overwritten when the server's data is applied. The
// rifleman global is cleared first so a leftover value from a previous faction
// can't mask a paste that never defines one.
//
// Returns [_pairs, _valid].

params ["_side", "_text"];

private _prefix = "blufor_";
private _riflemanVar = "blufor_SOLDIER_X";
if (_side == "opfor") then { _prefix = "opfor_"; _riflemanVar = "opfor_SOLDIER_X"; };

// keep only "<prefix>..." lines, break each on ";", drop path-like junk
private _pairs = (_text splitString (toString [13,10])) select { _prefix in _x };
_pairs = flatten (_pairs apply { _x splitString ";" });
_pairs = _pairs select { !(["/", _x] call BIS_fnc_inString) };

missionNamespace setVariable [_riflemanVar, ""];
{ call compile _x; } forEach _pairs;

private _valid = isClass (configFile >> "CfgVehicles" >> (missionNamespace getVariable [_riflemanVar, ""]));

[_pairs, _valid]
