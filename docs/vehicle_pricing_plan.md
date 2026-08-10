# Vehicle CP pricing — convergence plan

Today a purchasable vehicle's CP cost comes from two unrelated places: the 122 shipped
`blufor_RQST_VEHICLES` tables carry a hand-authored cost per row, while auto-detected and
modded factions price themselves through `fnc_evalVehicleCost`
(`src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf:76-144`), a free-floating 1-100
heuristic. The two disagree, and neither is bound to the capability tier the vehicle sits in —
so a low-tier vehicle can out-cost a high-tier one, and logistics trucks (a `+40` supply modifier
in the heuristic, `50` in the shipped tables) cost more than the armour they support.

This converges both onto one config-driven model: **kind sets a price band, a heaviness score
places the vehicle inside it.** Price and the tier gate then derive from the same kind classifier,
so they always agree. The classifier reads only config (armour, armament, threat, capacity), so a
modded vehicle prices itself with no per-faction data. Persistence is out of scope. The tier ladder
this sits beside is designed in [`ap_ladder_gating_plan.md`](ap_ladder_gating_plan.md); the economy
it feeds is [`economy_second_pass.md`](economy_second_pass.md).

## Why band + score, not a flat per-kind price

A flat price per kind cannot tell a T-60 from a T-72 — the player asked for the heavier, better-armed
tank to cost more. A single continuous heuristic (what ships now) gives that spread but cannot hold
an ordering: a heavily-armed car outscores a stripped light tank and crosses into tank money. Banding
by kind fixes the ordering as a hard constraint (a car can never reach a tank's band); the score only
moves a vehicle *within* its band. Both properties are load-bearing, so both mechanisms are kept.

## Kind classifier

`DUWS_fnc_vehKind {_class} -> _kindKey`, matched in priority order, first match wins. Order matters:
an AA tank and an arty piece are both `isKindOf "Tank"`, so their specific signals are tested first.

| Order | Kind key | Config signal |
|------|----------|---------------|
| 1 | `arty` | `artilleryScanner == 1` |
| 2 | `uav` | `vehicleClass == "Autonomous"` |
| 3 | `aa` | `radarType == 2` (vehicle AA radar; jets are `4`, so excluded) |
| 4 | `planeArmed` / `planeTransport` | `isKindOf "Plane"`, split on any turret weapon or pylon |
| 5 | `heliArmed` / `heliTransport` | `isKindOf "Helicopter"`, split on weapon/pylon; transport also needs `transportSoldier >= 4` |
| 6 | `tank` | `isKindOf "Tank"` |
| 7 | `logi` | `isKindOf "Car"` and (`transportRepair`/`transportAmmo`/`transportFuel` non-zero, or `attendant == 1`) |
| 8 | `apcIfv` | `isKindOf "Wheeled_APC_F"`, or `isKindOf "Car"` with `armor > 300` |
| 9 | `armedCar` | `isKindOf "Car"` with a turret weapon |
| 10 | `lightUnarmed` | `isKindOf "Car"` |
| 11 | `boat` | `isKindOf "Ship"` |
| 12 | `default` | anything unplaced |

`DUWS_fnc_vehTier` (`shared/functions/fnc_ap_gate.sqf`) is refactored to derive its tier from
`vehKind` rather than repeat the `isKindOf` cascade, so tier and price cannot drift apart.

## Band table

CP `[lo, hi]` per kind. The score picks a point in the range; `lo == hi` where a kind does not spread.

| Kind | lo | hi |
|------|----|----|
| `lightUnarmed` | 1 | 8 |
| `logi` | 14 | 18 |
| `armedCar` | 12 | 22 |
| `apcIfv` | 24 | 32 |
| `aa` | 28 | 32 |
| `tank` | 34 | 46 |
| `heliTransport` | 20 | 30 |
| `heliArmed` | 40 | 48 |
| `planeTransport` | 42 | 48 |
| `planeArmed` | 52 | 65 |
| `arty` | 66 | 75 |
| `uav` | 5 | 22 |
| `boat` | 16 | 24 |
| `default` | 10 | 10 |

The ordering the player asked for is a property of this table, not of the score: light ≪ armed car
< APC/IFV < tank ≪ jet/arty, and logistics sits beside the armed car rather than above the armour.

## Heaviness score

`DUWS_fnc_vehScore {_class} -> 0..1` blends three terms — armour, armament and seat capacity — each
normalised to `0..1` against fixed reference ranges so a vehicle's score never depends on the rest of
the faction. How the three are weighted is set **per kind**: armour barely varies inside the car band
while the gun is the whole story there, and a transport's value is its capacity, not its armour — so a
single fixed split cannot span every band. The per-kind weight vector below is what does.

Armour term:

```
armorN = clamp01 (armor / ARMOR_REF)                        # ARMOR_REF ~ 1200
```

Armament term — a sum over every turret weapon, so armament **count** enters as the number of terms.
Each weapon is weighted by its class, then modulated by fire-rate and magazine capacity:

```
weaponScore = SUM over turret weapons of  typeW[w] * (1 + RATE_W*rateN[w]) * (1 + CAP_W*capN[w])
            + PYLON_W * pylonCount
typeW  : CANNON 10, ATGM 8, AUTOCANNON 7, GMG 5, HMG 3, MG 2   # weapon class, via BIS_fnc_returnParents
rateN  = clamp01 (RATE_PIVOT / reloadTime)                     # fire-rate; faster -> higher, capped at 1
capN   = clamp01 (magRounds / CAP_REF)                         # rounds in the loaded magazine (firing capacity)
weaponN = clamp01 (weaponScore / WEAPON_REF)                   # WEAPON_REF ~ 30
```

Seats term — passenger capacity, so a bigger troop or supply carrier costs more:

```
seatsN = clamp01 (transportSoldier / SEAT_REF)              # SEAT_REF ~ 14
```

The score is a **weighted sum of all three terms**, the weights set per kind so every vehicle reads
armour, armament and seats but each kind leans on what actually varies for it — armour for a tank,
the gun for a car, capacity for a transport. Weights per row sum to 1:

| Kind | wArmour | wWeapon | wSeats |
|------|--------:|--------:|-------:|
| `tank` | 0.55 | 0.40 | 0.05 |
| `apcIfv` | 0.45 | 0.30 | 0.25 |
| `aa` | 0.35 | 0.65 | 0.00 |
| `armedCar` | 0.20 | 0.75 | 0.05 |
| `heliArmed` | 0.10 | 0.80 | 0.10 |
| `planeArmed` | 0.05 | 0.95 | 0.00 |
| `heliTransport` | 0.20 | 0.10 | 0.70 |
| `planeTransport` | 0.10 | 0.00 | 0.90 |
| `logi` | 0.10 | 0.00 | 0.90 |
| `lightUnarmed` | 0.00 | 0.00 | 1.00 |
| `boat` | 0.10 | 0.60 | 0.30 |
| `uav` | 0.00 | 1.00 | 0.00 |
| `default` | — flat 0.5 — |||

```
score = wArmour*armorN + wWeapon*weaponN + wSeats*seatsN
CP    = round (lo + score * (hi - lo))
```

Config read per weapon: class via `BIS_fnc_returnParents` on the turret weapon (`MGun`/`HMG`/`GMG_F`/
`autocannon`/`cannoncore`/`launchercore`); `reloadTime` from the weapon's first firemode; magazine
`count` from the weapon's first `CfgMagazines` entry; pylons via `getAllPylonsInfo`; passengers from
`transportSoldier`. `ARMOR_REF`, `WEAPON_REF`, `CAP_REF`, `SEAT_REF`, `RATE_PIVOT`, `RATE_W`, `CAP_W`,
`PYLON_W`, the `typeW` weights and the per-kind weight vectors are all constants at the top of the
pricing file — the play-test tuning surface.

Worked examples (illustrative, pending in-game dump):

- **T-60 vs T-72** — both `tank`, band `[34,46]`, armour-led. Lighter armour and a smaller,
  slower-firing gun score the T-60 near `0.1` (~35 CP); the T-72's heavier armour and larger cannon
  score near `0.8` (~44 CP).
- **MG vs GMG vs autocannon offroad** — all `armedCar`, band `[12,22]`, weapon-led. The type weight
  carries it: MG (`typeW 2`) ~13, GMG (`typeW 5`) ~18, a rare autocannon car toward `22`; a high
  fire-rate or a fat belt nudges each up within the band.
- **Small vs large transport heli** — both `heliTransport`, band `[20,30]`, seat-led. An 8-seat
  Hummingbird-class lands low; a Huron-class carrying twice the passengers lands near the top.
- **Soft vs up-armoured MRAP** — both `armedCar`: the up-armoured hull lifts `armorN`, so it costs a
  little more than the soft-skin on the same gun, even though the car band leans on the weapon.

## Application — one chokepoint

`fnc_faction_rqst_list.sqf` is the single reader of every request menu, for shipped, auto-detected
and unconverted third-party factions alike. The reprice happens there, on the `VEHICLE` kind only:
each row is rebuilt to `[_class, "<displayName> (<CP>CP)", CP]` from `DUWS_fnc_vehPrice`, so the
authored `select 2` cost and its baked `(NNCP)` label text are both overridden. Price is memoised in
a per-class hash so repeated menu opens do not recompute. `fnc_evalVehicleCost` and the
`fnc_enumCost*` wrappers in the autodetect file are retired — the autodetect path builds its rows
from `vehPrice` like everything else.

`DUWS_fnc_vehKind`, `DUWS_fnc_vehScore` and `DUWS_fnc_vehPrice` live in a new
`shared/functions/fnc_veh_price.sqf`, compiled and each `publicVariable`'d in `server_fnc_init.sqf`
next to the `fnc_ap_gate` broadcast, because the reader runs on clients as well as the server.

## Slices

1. `fnc_veh_price.sqf`: `vehKind`, `vehScore`, `vehPrice`, the band table and the tuning constants;
   broadcast in `server_fnc_init`.
2. Refactor `DUWS_fnc_vehTier` to derive from `vehKind`.
3. Reprice `VEHICLE` rows in `fnc_faction_rqst_list`, memoised; retire `fnc_evalVehicleCost` and the
   `fnc_enumCost*` wrappers, routing autodetect through `vehPrice`.
4. Follow-up, separate commit: strip the now-vestigial authored cost literal and `(NNCP)` label text
   from the 122 shipped `blufor_RQST_VEHICLES` tables. Functional no-op — the reader already ignores
   them — but it stops the source files showing a number the game does not charge.

## Verification

No in-repo compiler. Each slice is brace-balance and threshold grepped, then play-tested. The score
weights are calibrated from an in-game dump of `{kind, class, CP}` across a vanilla, a modded and an
auto-detected faction — the only way to confirm the bands land where intended and the T-60/T-72 style
spreads read right, since these globals are built at runtime and no static check sees them.
