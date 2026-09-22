// Locality: any. Pure, so the unit tests drive it directly.
// The cap sits below 100 so the floor alone never breaks cover: a break always needs a spotter.
// Contract: [_mismatch] ([slot, class] pairs from fnc_disguise_enemyMismatch; class "" is an empty slot)
// -> the enemy disguise's suspicion floor. A wrong item costs twice its slot's penalty, an empty slot once.
params ["_mismatch"];

private _sum = 0;
{
    _x params ["_slot", "_cls"];
    _sum = _sum + ([2, 1] select (_cls == "")) * (switch (_slot) do {
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
} forEach _mismatch;
_sum min 95
