// Site-finder for the sabotage-laptop mission -- the offer filter. Accepts a picker candidate only where an
// enterable building sits within reach, and returns that building's position, so the mission only ever offers
// where it can actually build the objective indoors -- a town street or a lone countryside building alike,
// never open ground where the thread would abort after the pick. Buildings outside towns count: this is why
// the type keeps surveyKind "map" rather than "town".
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf). fnc_usableBuildings is server-only,
// so this inlines the same test as a pure engine query (nearestTerrainObjects + buildingPos) valid on any
// client, matched to that function's criteria -- a "House" terrain object with a position at index 3 (its
// minimum, i.e. four+ interior slots) -- so the offer and the thread's fnc_usableBuildings never disagree on
// what is enterable.
//
// Contract: [_candidatePos] -> [] reject, or [_bldgPos] accept.
params ["_pos"];

// TUNABLE. How far the objective building may sit from where the picker wanted the offer.
#define ACCEPT_RADIUS 300

private _bldgs = nearestTerrainObjects [_pos, ["House"], ACCEPT_RADIUS, true];
private _i = _bldgs findIf { !(((_x buildingPos 3) select 0) == 0) };
if (_i < 0) exitWith { [] };

[getPosATL (_bldgs select _i)]
