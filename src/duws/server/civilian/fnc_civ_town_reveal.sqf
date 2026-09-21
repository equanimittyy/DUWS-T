// Locality: server. Sole writer of civ_visible, the way fnc_zone_reveal is sole writer of the
// revealed flag in zone_namePOS_pairs. Called straight from the town presence trigger, whose
// evaluation locality is not proven, so the guard has to be here rather than at the call site.
//
// Returns true only when this call changed something, so a caller can tell "revealed a town"
// from "that town was already on the map".
params ["_townIndex"];

if (!isServer) exitWith {false};

private _vis = missionNamespace getVariable ["civ_visible", []];
if (_townIndex < 0 || _townIndex >= count _vis) exitWith {false};
if (_vis select _townIndex) exitWith {false};

_vis set [_townIndex, true];

// Painted here rather than through fnc_civ_townRender: that function returns early for RAVAGE and
// WBK, which register no town reputation, and those towns have to be revealable too.
(format ["civ_area_%1", _townIndex]) setMarkerAlpha 0.3;
(format ["civ_icon_%1", _townIndex]) setMarkerAlpha 1;

// The town's shops come up with it, so the map is never pre-populated with every vendor on the
// island and hardcore mode needs no separate answer. Alpha only: colour is the open/closed channel
// (fnc_vendor_markerPaint), and a revealed shop keeps whichever state its cooldown says.
{
    ([_townIndex, _forEachIndex] call fnc_vendor_markerName) setMarkerAlpha 1;
} forEach ([_townIndex] call fnc_vendor_recs);

["town_discovered", [text ((missionNamespace getVariable ["civ_locations", []]) select _townIndex)]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

true
