// Locality: server -- reads the per-town population and occupancy state the handler publishes.
/*
    How many civilians one town may hold at this moment: its own demand, thinned if the towns
    currently occupied add up to more than the campaign-wide ceiling.
    Params: [_density, _locIndex]. Returns a count.
*/
params ["_density", "_locIndex"];

private _pop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
private _raw = _density min _pop;
if (_raw <= 0) exitWith { 0 };

// Three towns at full density. Keyed to the selected setting rather than to a fixed head count,
// so the headroom scales with it and no option thins any earlier than another.
//
// Three, not two, because two is already the single-player peak: civilian discs cannot overlap --
// the cull in fnc_civ_init_Tomata pushes them apart until they are disjoint -- so one player is
// inside one town, and walking into the next while the last still drains holds two at once. A
// ceiling of two would put every solo town-to-town transition on the boundary and thin the moment
// a second player existed. The third town's worth is the co-op headroom.
//
// Constraint on raising the density options: every civilian gets its own group so it can
// wander independently, and the engine stops issuing groups at roughly 144 per side. The top
// option therefore has to stay under 48, or createGroup starts returning grpNull and towns
// silently spawn nobody.
private _cap = _density * 3;

private _total = _raw;
{
    if (_forEachIndex != _locIndex
        && {missionNamespace getVariable [format ["civ_spawned_%1", _forEachIndex], false]}) then {
        _total = _total + (_density min (missionNamespace getVariable [format ["civ_pop_%1", _forEachIndex], 0]));
    };
} forEach (missionNamespace getVariable ["civ_locations", []]);

if (_total <= _cap) exitWith { _raw };

// Thinned proportionally rather than starving whichever town triggered last: a town holding
// nobody reads as broken, where a thinner one only reads as quiet. The floor holds that line
// even when more towns are occupied than the ceiling covers, so the overshoot is bounded by the
// number of occupied towns rather than by the density setting.
private _share = floor (_cap * _raw / _total);
(_share max (3 min _raw)) min _raw
