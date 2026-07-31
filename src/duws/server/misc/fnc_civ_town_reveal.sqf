// Locality: server. Sole writer of civ_visible, the way fnc_zone_reveal is sole writer of the
// revealed flag in zone_namePOS_pairs. Called straight from the town presence trigger, whose
// evaluation locality is not proven, so the guard has to be here rather than at the call site.
//
// Returns true only when this call changed something, so a caller can tell "revealed a town"
// from "that town was already on the map".
//
// _audience is who is told, on the same rule fnc_zone_reveal uses: the presence trigger's reveal
// is everyone's news and takes the default, while one bought with a search is hinted to the
// player who paid for it as well as spoken to them. _quiet likewise hands the reporting to the
// caller, so a search speaks in the searcher's voice rather than Overlord's.
params ["_townIndex", ["_audience", 0], ["_quiet", false]];

if (!isServer) exitWith {false};

private _vis = missionNamespace getVariable ["civ_visible", []];
if (_townIndex < 0 || _townIndex >= count _vis) exitWith {false};
if (_vis select _townIndex) exitWith {false};

_vis set [_townIndex, true];

// Painted here rather than through fnc_civ_townRender: that function returns early for RAVAGE and
// WBK, which register no town reputation, and those towns have to be revealable too.
(format ["civ_area_%1", _townIndex]) setMarkerAlpha 0.3;
(format ["civ_icon_%1", _townIndex]) setMarkerAlpha 1;

if (!_quiet) then {
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_townreveal", _audience] call fnc_duws_report;
};

true
