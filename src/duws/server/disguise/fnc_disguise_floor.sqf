// Locality: any. Pure, so the unit tests drive it directly.
// The cap sits below 100 so the floor alone never breaks cover: a break always needs a spotter.
// Contract: [_slots] (mismatched slot names) -> the enemy disguise's suspicion floor.
params ["_slots"];

private _sum = 0;
{
    _sum = _sum + (switch (_x) do {
        case "primary":  { 30 };
        case "vehicle":  { 30 };
        case "launcher": { 20 };
        case "vest":     { 20 };
        case "headgear": { 20 };
        case "nvg":      { 15 };
        case "handgun":  { 10 };
        case "backpack": { 10 };
        default          { 0 };
    });
} forEach _slots;
_sum min 95
