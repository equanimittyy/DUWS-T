// Locality: server. Clearing counterpart to fnc_opcom_cover_stamp: a guaranteed sweep that comes up empty is
// proof of absence, so drop every belief whose remembered cell is in the swept k box and that no sensor
// re-confirmed this tick (time < tick). Detection re-stamps a still-present subject to this tick before this
// runs, so it survives; only a stamp whose position the sweep just disproved goes. Guaranteed sensors only
// (recon, a fired OP post) -- a fallible nearTargets miss is no proof, the reason its miss never stamps either.
//
// Assumes every belief is a mobile group (true today: all faucets stamp BLUFOR group netIds). A static
// discovered subject -- the zone / FOB / HQ keys belief_init reserves -- must be excluded before one is ever
// written, else an overflight that does not re-detect it as a group would un-discover it.
if (isNil "DUWS_opcom_grid_w") exitWith {};
params ["_point", "_k"];

private _w  = DUWS_opcom_grid_w;
private _c  = [_point] call DUWS_fnc_opcom_w2c;
private _cx = _c mod _w;
private _cy = floor (_c / _w);
private _t  = DUWS_opcom_tick;

// High-to-low: deleteAt shifts every later row down, so a forward walk would skip the row after each drop.
for "_i" from (count DUWS_opcom_belief_key - 1) to 0 step -1 do {
    if ((DUWS_opcom_belief_time select _i) < _t) then {
        private _bc = [DUWS_opcom_belief_pos select _i] call DUWS_fnc_opcom_w2c;
        if (((abs ((_bc mod _w) - _cx)) max (abs ((floor (_bc / _w)) - _cy))) <= _k) then {
            [_i] call fnc_opcom_belief_deleteAt;
        };
    };
};
