# AIS revive integration

How DUWS uses the vendored AIS (Advanced Injury System) module — the revive/medical framework under
[`src/modules/AIS`](../../../src/modules/AIS), an alternative to ACE or vanilla BIS revive. This records
which units it manages, how it is selected at boot, and the traps that bite when a script wants a unit to
die outright or to carry its own damage handler.

## Loading and the Revive parameter

AIS's functions are compiled through `#include "modules\AIS\cfgFunctions.hpp"` in
[`src/description.ext`](../../../src/description.ext); its tunables live in
[`AIS_SETUP.sqf`](../../../src/modules/AIS/AIS_SETUP.sqf). Which revive system is actually live is a
per-mission choice, resolved **once per client** in
[`src/initPlayerLocal.sqf`](../../../src/initPlayerLocal.sqf) off the `"Revive"` mission parameter (that
selection block must stay last in the file):

| `Revive` | Effect |
|---|---|
| `0` | No revive: `bis_fnc_disableRevive`, and `AIS_noReviveInit = true` so AIS skips the player. |
| `1` | AIS: `AIS_System_fnc_loadAIS` on the player, BIS revive disabled. |
| `2` | Vanilla BIS revive: `AIS_noReviveInit = true` (AIS skipped). |

ACE medical is mutually exclusive — if `ace_medical` / `ace_main` is present, AIS shuts itself off
(`Core/fn_aisInitPlayer.sqf`, `Core/fn_postinit.sqf`) and the boot forces the no-revive branch. So AIS
only truly runs when `Revive == 1` and no ACE.

## Who AIS manages: players and their AI, nothing else

`AIS_REVIVE_INIT_UNITS = "allplayables"`, which resolves to **`switchableUnits` in single-player /
`playableUnits` in multiplayer** ([`Core/fn_aisInitPlayer.sqf:75`](../../../src/modules/AIS/Core/fn_aisInitPlayer.sqf))
— the player squad and its commandable AI. AI enrollment happens in exactly two ways, and neither reaches
a dynamically-spawned unit:

- A **one-shot loop at mission start** over that playable set (minus the players), calling `aisInitHost`
  on each ([`Core/fn_postinit.sqf:32-40`](../../../src/modules/AIS/Core/fn_postinit.sqf)). It runs once and
  never re-scans, so a unit created *after* boot is never picked up by it.
- An **explicit `AIS_System_fnc_loadAIS` call**. DUWS makes this in only two places: the player
  (`initPlayerLocal.sqf`) and a recruited operative
  ([`client/operative/fnc_operator_recruit.sqf`](../../../src/duws/client/operative/fnc_operator_recruit.sqf),
  which also `addSwitchableUnit`s them into the player's roster).

Everything the war spawns — zone garrisons, patrols, hardpoint crews, enemy waves, mission-specific AI,
civilians — is therefore **outside AIS**: it dies normally and carries whatever event handlers its spawner
gave it. That is the intended scope; the setup file itself warns against `"allUnits"` "if you play with a
lot of AI units".

## Opting a specific unit out

Set `AIS_noReviveInit = true` on a unit (honored by
[`Core/fn_aisInitHost.sqf:3`](../../../src/modules/AIS/Core/fn_aisInitHost.sqf) and
`System/fn_loadAISlocalToPlayer.sqf`), or pre-set `ais_aisInit` (any non-nil value makes `loadAIS`
early-exit). Reach for this on a friendly/playable-adjacent unit that must die outright — a mission asset
whose death is a win/lose predicate — so AIS can never revive it or replace its damage handler.

## Traps

- **AIS replaces a unit's `HandleDamage`.** `aisInitHost` / `aisInitPlayer` run
  `removeAllEventHandlers "handleDamage"` before installing their own, so a custom `HandleDamage` on any
  AIS-managed unit is destroyed. If a unit needs its own damage handler (a damage-scaling clamp, an
  invulnerability window), it must be a unit AIS does not manage, or be opted out with `AIS_noReviveInit`.
- **A managed unit goes unconscious, not dead.** It gets `ais_unconscious`, and `!alive` does not become
  true until bleedout or a finishing hit. `AIS_REVIVE_GUARANTY = true` makes this unconditional — *any*
  lethal damage drops the unit unconscious regardless of magnitude. A script polling `!alive` on an
  AIS-managed unit can therefore hang; either opt the unit out or also test `ais_unconscious`.
- **Do not "tighten" the setting to `"allplayers"`.** That empties the postinit enrollment set, and the
  player-group-AI fallback in `aisInitPlayer` is gated `!isServer` (dedicated only), so a host player's own
  AI squad would get no AIS at all in single-player or on a listen server. `"allplayables"` is the correct
  setting for a mostly-SP/co-op mission; `"allUnits"` / `"allUnitsBLUFOR"` would drag every spawned unit in.

## Config worth knowing

The rest is in [`AIS_SETUP.sqf`](../../../src/modules/AIS/AIS_SETUP.sqf); the values that change behaviour
most:

| Setting | Value | Meaning |
|---|---|---|
| `AIS_REVIVE_INIT_UNITS` | `"allplayables"` | players + their commandable AI (above) |
| `AIS_MEDICAL_EDUCATION` | `1` | a First Aid Kit or Medkit is needed to revive (AI and players) |
| `AIS_REVIVE_GUARANTY` | `true` | always fall unconscious on lethal damage, regardless of magnitude |
| `AIS_BLEEDOUT_TIME` | `300` | seconds until an untreated unconscious unit dies |
| `AIS_REVIVE_HEAL` | `true` | a revived unit is fully healed (no-medic-friendly) |
| `AIS_MEDEVAC_STATIONS` | `[]` | medevac-only-revive disabled |
