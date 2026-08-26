// Site-finder for the destroy-hardpoint mission. Accepts a picker candidate only where a live,
// intel-revealed OPFOR standalone hardpoint of a destructible type sits within reach, and returns that
// hardpoint's position. The mission points at an existing emplacement rather than a spawned stand-in, so
// with none in range the offer is dropped.
//
// Intel IS a prerequisite here, unlike the tower picker: only a revealed row (index 5) qualifies, so the
// mission never sends the player after an emplacement they have not found. Under non-hardcore fog every
// hardpoint spawns revealed, so the flag only bites in hardcore mode.
//
// Excludes RADIO (its own Destroy Signal Tower mission) and MINEFIELD (no emplacement to wreck -- it is a
// hazard cleared, not a garrison beaten). Standalone only (zoneKey ""): a zone-child hardpoint reveals
// with its zone and sits inside its footprint, so it is taken by capturing the zone, not as a discrete
// objective, and pays no destruction bounty.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only the broadcast
// DUWS_hardpoints. Presence in that array == the emplacement is alive: the streamer deletes the row the
// instant it clears, so no separate liveness query is needed.
//
// Contract: [_candidatePos] -> [] reject, or [_hpPos] accept.
params ["_pos"];

// TUNABLE. How far the target may sit from where the picker wanted the offer before it drags the mission
// across the map. Kept in step with the thread, which re-derives the same nearest hardpoint.
#define ACCEPT_RADIUS 2500

// Nearest live, revealed OPFOR standalone hardpoint of a destructible type within reach. Row:
// [key, pos, type, side, zoneKey, revealed, dir].
private _best = [];
private _bestD = ACCEPT_RADIUS;
{
    _x params ["", "_hp", "_type", "_side", "_zoneKey", "_revealed"];
    if (
        !(_type in ["RADIO", "MINEFIELD"])
        && {_side isEqualTo "opfor"}
        && {_zoneKey isEqualTo ""}
        && {_revealed}
    ) then {
        private _d = _hp distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _best = _hp };
    };
} forEach (missionNamespace getVariable ["DUWS_hardpoints", []]);

if (_best isEqualTo []) exitWith { [] };
[_best]
