// Locality: server. Draws the ring inside which an intact parked vehicle is never collected, so a
// player can see the ground that keeps their kit instead of having to know the number.
//
// Takes a position for a base that cannot move (the HQ, a FOB) and an object for one that can (the
// MHQ), in which case the ring follows it and goes when it dies. Returns the marker name.
if (!isServer) exitWith {""};

params ["_anchor", ["_name", ""]];

private _tracked = _anchor isEqualType objNull;
if (_tracked && {isNull _anchor}) exitWith {""};

private _pos = if (_tracked) then { getPos _anchor } else { _anchor };
if (_name isEqualTo "") then {
	_name = format ["base_range_%1_%2", round (_pos select 0), round (_pos select 1)];
};

// createMarker refuses a name already in use and answers "". The MHQ ring is the case that can hit
// it: a replacement MHQ may be designated before the previous ring's thread has noticed the old one
// died, so the name is cleared rather than trusted to be free. Deleting an absent marker is a no-op.
deleteMarker _name;

private _marker = createMarker [_name, _pos];
_marker setMarkerShape "ELLIPSE";
_marker setMarkerBrush "SolidBorder";
_marker setMarkerColor "ColorBlue";
// The radius the cleanup sweep actually spares, read from the same global it reads, not a number of
// this marker's own. A ring promising more ground than the sweep honours would lose a player's
// vehicle inside the very circle drawn to tell them it was safe.
_marker setMarkerSize [DUWS_base_keep_radius, DUWS_base_keep_radius];
_marker setMarkerAlpha 0.3;

if (_tracked) then {
	[_anchor, _marker] spawn {
		params ["_obj", "_marker"];
		// Five seconds, not every frame: the ring is hundreds of metres across, so nothing driveable
		// leaves its own circle inside one interval, and this thread lives for the rest of the
		// campaign. It also ends when the marker goes, which is how a released MHQ stops being
		// followed by a vehicle that is still very much alive -- markerShape answers "" for a
		// marker that no longer exists.
		while {!isNull _obj && {alive _obj} && {markerShape _marker != ""}} do {
			_marker setMarkerPos (getPos _obj);
			sleep 5;
		};
		deleteMarker _marker;
	};
};

_marker
