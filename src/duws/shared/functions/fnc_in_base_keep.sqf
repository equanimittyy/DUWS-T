// Locality: any. Reads PosOfBLUHQ, Array_of_FOBpos, MHQ1 and DUWS_base_keep_radius, all broadcast by
// the server.

// Does this position sit within the base-keep ring of the HQ, a FOB or the MHQ -- the set the cleanup
// sweep spares (server/misc/fnc_repetitive_cleanup.sqf)? A vehicle dropped outside it is collected by
// the sweep, so the R3F carry refuses a base-bound drop there.
//
// The radius falls back to 250 for a JIP client that missed the DUWS_base_keep_radius broadcast.
params ["_pos"];
// Copied: pushBack would otherwise grow the broadcast array itself.
private _bases = +(missionNamespace getVariable ["Array_of_FOBpos", []]);
private _hq = missionNamespace getVariable ["PosOfBLUHQ", []];
if !(_hq isEqualTo []) then { _bases pushBack _hq };
private _mhq = missionNamespace getVariable ["MHQ1", objNull];
if (!isNull _mhq) then { _bases pushBack (getPos _mhq) };
private _radius = missionNamespace getVariable ["DUWS_base_keep_radius", 250];
(_bases findIf { (_pos distance2D _x) <= _radius }) >= 0
