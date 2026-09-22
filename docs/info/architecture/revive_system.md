# Revive and medical system

How DUWS decides what happens when a unit is wounded — the revive framework, the healing actions at
base, and how the mission steps aside for ACE. Three pieces cover it:

- The **`Revive` mission parameter** picks the revive framework: none, the vendored AIS module, or
  vanilla BIS revive.
- **AIS** (Advanced Injury System, by Psychobastard) under [`src/modules/AIS`](../../../src/modules/AIS) is
  the mission's own revive/wounding framework, used when `Revive == 1`.
- **ACE medical**, when the player has the mod loaded, takes over from all of the above. The mission
  never ships ACE and never requires it; every ACE touchpoint is a runtime `isClass` probe.

Base-side healing (the rearm/rest actions) is separate from the revive framework and always present.

## Respawn config

[`src/description.ext`](../../../src/description.ext) sets `respawn = 3` (BASE) with a 10 s delay and no BIS
Revive template — there is no `respawnTemplates[]`, `ReviveMode`, or `ReviveRequiredItems`. Revive is
scripted (AIS) or off, never the engine's own revive. BASE respawn returns the player to the
`respawn_west` marker, which the HQ repositions
([`fnc_BluHQinit.sqf`](../../../src/duws/server/init_hq/fnc_BluHQinit.sqf)); deployed MHQ, FOBs, the rally
point and the two killhouse entrances add further respawn points via `BIS_fnc_addRespawnPosition`.

A respawned player starts naked: [`onPlayerRespawn.sqf`](../../../src/onPlayerRespawn.sqf) sets an empty
loadout, because the engine otherwise dresses the new unit in its class kit. The dead body keeps the old
kit. The Full and Hybrid arsenal modes keep the startup kit free to draw again. The Limited mode draws it
from the pool like any other gear
([`fnc_arsenal_counts.sqf`](../../../src/duws/client/arsenal/fnc_arsenal_counts.sqf)).

AIS is compiled through `#include "modules\AIS\cfgFunctions.hpp"` in `description.ext` and auto-boots via
its CfgFunctions pre/postInit.

## The Revive parameter and the ACE override

Which framework is live is resolved **once per client** in
[`src/initPlayerLocal.sqf`](../../../src/initPlayerLocal.sqf) off the `"Revive"` parameter (default `0`).
That selection block must stay last in the file:

| `Revive` | Effect |
|---|---|
| `0` | No revive: `bis_fnc_disableRevive`, and `AIS_noReviveInit = true` so AIS skips the player. |
| `1` | AIS: `AIS_System_fnc_loadAIS` on the player, BIS revive disabled. |
| `2` | Vanilla BIS revive: `AIS_noReviveInit = true` (AIS skipped). |

**ACE forces the no-revive branch regardless of the parameter.** The `Revive == 0` test in
`initPlayerLocal.sqf` also fires when `ace_medical` or `ace_main` is in `CfgPatches`, so with ACE loaded
the client disables BIS revive and leaves the player to ACE. AIS and ACE are mutually exclusive by design
— ACE owns all wounding, and running both would double up damage handlers.

## ACE support

ACE support is detection plus deferral, spread across every place the mission touches health. There is no
ACE-specific mission logic beyond handing control over and stocking ACE's gear.

| Where | File | What ACE presence changes |
|---|---|---|
| Revive select | [`initPlayerLocal.sqf`](../../../src/initPlayerLocal.sqf) | Forces the no-revive branch (ACE owns wounding). |
| AIS shutdown | [`AIS/Core/fn_preinit.sqf`](../../../src/modules/AIS/Core/fn_preinit.sqf), [`fn_postinit.sqf`](../../../src/modules/AIS/Core/fn_postinit.sqf), [`fn_aisInitPlayer.sqf`](../../../src/modules/AIS/Core/fn_aisInitPlayer.sqf) | AIS sets `ais_ace_shutDown`/`AIS_noReviveInit` and never installs its handlers. |
| Rest & heal | [`server/dialog/fnc_rest_heal.sqf`](../../../src/duws/server/dialog/fnc_rest_heal.sqf) | Adds `ace_medical_treatment_fnc_fullHealLocal` on top of `setDamage 0`. |
| Arsenal medical | [`server/arsenal/fnc_create_ammo_lists.sqf`](../../../src/duws/server/arsenal/fnc_create_ammo_lists.sqf) | Stocks ACE medical items, tools, and rations. |

### Handoff to ACE

AIS shuts itself off on three paths so nothing survives to fight ACE for the damage handler:
`fn_preinit.sqf` sets the server-wide `ais_ace_shutDown` flag; `fn_postinit.sqf` early-exits on it; and
`fn_aisInitPlayer.sqf` sets `AIS_noReviveInit` per client. (`ais_ace_shutDown` and the lower-case
`ais_ace_shutdown` used in `fn_postinit.sqf` are the same variable — SQF identifiers are
case-insensitive.)

### ACE-aware healing

The game-master rest action heals players ACE-correctly: because `setDamage 0` clears only overall
damage and not ACE's wound/bleeding/pain state, `fnc_rest_heal.sqf` also calls
`ace_medical_treatment_fnc_fullHealLocal` when ACE is present. Both `setDamage` and `fullHealLocal` need
the unit local, so players run this on their own machine, not from the server.

The player is granted the `Medic` trait unconditionally
([`client/client_init.sqf`](../../../src/duws/client/client_init.sqf)), so under ACE any player can perform
the treatments ACE gates on that trait.

### ACE gear in the arsenal

When ACE is loaded, `fnc_create_ammo_lists.sqf` stocks ACE items into the virtual arsenal. Medical items
are found off **ACE's own `ACE_isMedicalItem` config flag** rather than a hardcoded list, so the set
tracks the installed ACE version and catches medical items that ACE-patched faction mods add. Curated ACE
tools live in [`fnc_basic_ammo_lists.sqf`](../../../src/duws/server/arsenal/fnc_basic_ammo_lists.sqf); ACE
utility gear and MRE rations are appended in `fnc_create_ammo_lists.sqf`.

### Known gap

The everyone-facing **rearm & heal** action ([`client/arsenal/fnc_ai_rearm.sqf`](../../../src/duws/client/arsenal/fnc_ai_rearm.sqf))
heals with a bare `player setDamage 0` and has no ACE branch, unlike the game-master rest action above.
Under ACE this leaves the player's wound/bleeding/pain state intact — visually healed, still bleeding. To
close it, mirror the `fnc_rest_heal` ACE branch here, respecting locality (players heal on their own
machine; AI are server-local and need `fullHealLocal` reached by `remoteExec`).

## AIS: who it manages — players and their AI, nothing else

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

## AIS: opting a specific unit out

Set `AIS_noReviveInit = true` on a unit (honored by
[`Core/fn_aisInitHost.sqf:3`](../../../src/modules/AIS/Core/fn_aisInitHost.sqf) and
`System/fn_loadAISlocalToPlayer.sqf`), or pre-set `ais_aisInit` (any non-nil value makes `loadAIS`
early-exit). Reach for this on a friendly/playable-adjacent unit that must die outright — a mission asset
whose death is a win/lose predicate — so AIS can never revive it or replace its damage handler.

This opt-out is inert under ACE (AIS never runs). A death-predicate unit that must not survive its wounds
needs ACE's own AI-medical handling considered separately, since ACE by default drops AI unconscious
rather than killing them.

## AIS: traps

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

## AIS: config worth knowing

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

## Base-side healing

Two heal actions sit on base objects, independent of the revive framework and present in every mode.

- **Rearm & heal** — action body [`client/arsenal/fnc_ai_rearm.sqf`](../../../src/duws/client/arsenal/fnc_ai_rearm.sqf),
  open to everyone, attached at the medical tent
  ([`fnc_medtent_actions.sqf:13`](../../../src/duws/shared/functions/fnc_medtent_actions.sqf)), on FOBs, on
  MHQ deploy, and on ammo boxes. Full `setDamage 0` on the caller's squad. See the ACE gap above.
- **Rest & heal** — game-master only, attached at the medical tent
  ([`fnc_medtent_actions.sqf:16-21`](../../../src/duws/shared/functions/fnc_medtent_actions.sqf)) and FOBs,
  routed through [`server/misc/fnc_restHealServer.sqf`](../../../src/duws/server/misc/fnc_restHealServer.sqf)
  (30 s cooldown) to [`fnc_rest_heal.sqf`](../../../src/duws/server/dialog/fnc_rest_heal.sqf): heals
  everyone within 100 m, clears the dead, skips three hours, and fades the screen. This is the ACE-aware
  path.
