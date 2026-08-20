// Locality: server -- called once after the convoy group is assembled. The group shape is the caller's
// (a merged road column in both callers): this only tunes how the vehicles hold the road, not who is in
// which group.
//
// Arma's vehicle route *calculation* was never reworked -- only path-following was -- so left to
// themselves the drivers cut corners cross-country into walls and wedge. forceFollowRoad pins them to
// the network for the long haul; fnc_convoy_watch lifts it for the final off-road hop to the objective.
// setUnloadInCombat off + allowCrewInImmobile keep a bumped or immobilised hull's crew aboard rather
// than dumped onto the road to block the column behind. setConvoySeparation holds real spacing so the
// column stops rear-ending into a pile-up; values under ~10 m make the AI swerve off-road to avoid each
// other, so that is the floor.
params ["_group", "_vehicles", ["_sep", 25]];

_group setUnloadInCombat [false, false];
{
    _x setConvoySeparation _sep;
    _x forceFollowRoad true;
    _x allowCrewInImmobile true;
} forEach _vehicles;
