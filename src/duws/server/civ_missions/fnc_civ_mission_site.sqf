// Locality: server. Open ground for a job site outside town _town that also passes _ok, or [] when ten draws find
// none. Bandits fight both armies, so a site near a zone or the HQ loses its bandits before the player arrives --
// and the objective pays whoever killed them.
params ["_town", ["_ok", { true }]];
private _centre = getPos ((missionNamespace getVariable ["civ_locations", []]) select _town);
private _radius = (missionNamespace getVariable ["civ_radii", []]) param [_town, 100];
private _taken = ((values DUWS_civMissions) apply { _x getOrDefault ["site", []] }) select { _x isNotEqualTo [] };

private _found = [];
for "_i" from 1 to 10 do {
    private _p = _centre getPos [_radius + 300 + random 900, random 360];
    if (surfaceIsWater _p) then { continue };
    if ((zone_meta_array findIf { _p distance2D (_x select 1) < (_x select 2) + 300 }) >= 0) then { continue };
    if (PosOfBLUHQ isNotEqualTo [] && {_p distance2D PosOfBLUHQ <= AOI_HQ_REACH}) then { continue };
    // Two givers' sites this close would merge into one fight.
    if ((_taken findIf { _p distance2D _x < 500 }) >= 0) then { continue };
    _found = [_p, 50, 0, 8, 0.3, []] call fnc_safe_pos;
    if (_found isNotEqualTo [] && {[_found] call _ok}) exitWith {};
    _found = [];
};
_found
