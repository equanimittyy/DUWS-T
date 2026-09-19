# Bandit faction: implementation plan

Add bandits: a third hostile force on the INDEPENDENT side that fights both BLUFOR and OPFOR. A
bandit wears clothes drawn from the three native bandit factions and carries kit drawn from the
BLUFOR and OPFOR gear pools. There are five roles: rifleman, autogunner, grenadier, AT and medic.

This plan builds the faction and one function that raises a bandit group. Where bandits appear in
the campaign is decided in [Phase 4](#phase-4-first-consumer).

## Side

No change. `server/server_init.sqf:22-27` already makes INDEPENDENT hostile to WEST and EAST, and
both hostile to it, so a group created on INDEPENDENT fights both armies.

## Appearance

### Sources

| Source | Factions | Content |
|---|---|---|
| FIA | `BLU_G_F`, `OPF_G_F`, `IND_G_F` | Base game |
| Syndikat | `IND_C_F` | Apex |
| Looters | `IND_L_F` | Contact |

The server scans each source once, at init. Every public (`scope = 2`) unit of the source's
factions gives its `uniformClass` and its headgear: from `headgearList[]` when the class has one,
else from the headgear in `linkedItems[]`. Duplicates are dropped. The headgear pool keeps one empty
entry when a source has bareheaded units, so some bandits go bareheaded. The result is
`DUWS_banditLooks`: one `[uniforms, headgear]` pair per enabled source.

The scan reads config, not a hand-written class list, so it follows the game's own faction
definitions.

### Drawing an outfit

Each slot draws on its own: pick an enabled source at random, then an item from that source. A
bandit can wear a Looter shirt under a Syndikat cap, which reads as scavenged. The source is picked
first so the three sources stay level; FIA spans three factions and would otherwise outweigh the
other two.

Facewear is not drawn. The body keeps the facewear that its FIA identity rolls at spawn.

Vests are kit, not appearance. They come from the army pools through `fnc_civ_arm` (see
[Kit](#kit)).

### Body

Every bandit spawns as `I_G_Soldier_F` (FIA rifleman, INDEPENDENT) and is re-dressed with one
`setUnitLoadout`: the drawn uniform and headgear, the body's own facewear, the basic linked items
(map, compass, watch, radio) and nothing else. The body is base-game content, so no parameter value
can put a DLC unit on the map.

## The Bandits parameter

A new class `DUWS_Bandits` in `shared/includes/params_modern.hpp`, in the gameplay block before
`DUWS_Divider_Dev` (`:84`).

| Value | Text | Sources drawn |
|---|---|---|
| 0 (default) | Full | FIA, Syndikat, Looters |
| 1 | No DLC | FIA |
| 2 | No Apex DLC | FIA, Looters |
| 3 | No Contact DLC | FIA, Syndikat |

A player who does not own a DLC gets that DLC's purchase prompt from its content. The same concern
keeps the HQ ground crew in their own helmet (`server/init_hq/fnc_BluHQinit.sqf:440-442`). The host
sets the parameter to what the session's players own.

The parameter gates appearance only. Bandit kit comes from the two armies the player picked, so it
carries whatever DLC content those factions carry.

Gating is per source, not per item. No Apex DLC drops every Syndikat item, including its base-game
caps. A DLC item that a unit of another source names is not caught.

The server reads the parameter once, when it builds `DUWS_banditLooks`.

## Kit

Bandit kit reuses `fnc_civ_arm` (`server/civilian/fnc_civ_arm.sqf`), the function that arms the
fleeing informant, the safehouse cell and the angry mob.

### Pool union

`_pool` accepts an array of prefixes as well as one string. `["opfor", "blufor"]` unions the
`opfor_*` and `blufor_*` weapons, vests and backpacks (`fnc_civ_arm.sqf:34-39`). String callers are
unchanged.

### Roles

| Role | Token | `_spec` |
|---|---|---|
| Rifleman | `rifleman` | `["vest", "assault_rifle"]` |
| Autogunner | `autogunner` | `["vest", "machinegun"]` |
| Grenadier | `grenadier` | `["vest", "grenadier"]` |
| AT | `at` | `["vest", ["submachinegun", "assault_rifle"], "launcher"]` |
| Medic | `medic` | `["vest", "backpack", ["submachinegun", "assault_rifle"], "medic"]` |

The `machinegun` and `launcher` tokens already add a bag for spares (`fnc_civ_arm.sqf:116`).

### Token changes

| Token | Change |
|---|---|
| `launcher` | Match any pool weapon that passes `fnc_IsAT` and fails `fnc_IsAA`. Today the token matches only the `BIS_fnc_itemType` subcategory `Launcher` (`fnc_civ_arm.sqf:44`), but rocket and missile tubes return `RocketLauncher` and `MissileLauncher` (`client/arsenal/fnc_arsenal_counts.sqf:144` handles all three). No caller uses the token yet, so the fix changes no current behavior. |
| `grenadier` | New. An assault rifle from the pool that passes `fnc_IsGrenadier`, with the rifle muzzle and the grenade-launcher muzzle each loaded and given spares. With no such rifle in the pool it falls back to `assault_rifle`, so a grenadier never spawns unarmed. |
| `medic` | New. A `Medikit` and first aid kits in the bag, a bag added when the unit has none, and `setUnitTrait ["Medic", true]` so the AI treats its squad. |

The three predicates live in `shared/factions/MODERN/fn_factionAutoDetect.sqf`, but they are
assigned inside `fnc_unitParseRoles` (`:220`; predicates at `:232`, `:240`, `:254`), so they are nil
until that function first runs. Move `fnc_IsAT`, `fnc_IsAA` and `fnc_IsGrenadier` to the top level of
the file, so they exist once faction init has run.

### Skill and loot

Bandits spawn at `opfor_ai_skill`: they fight at the enemy skill the player chose, and no new setting
is added. The raise adds no random loot (`fnc_addRandomLoot`); the bodies already carry army kit.

## Raising a group

`[_pos, _roles] call fnc_bandit_spawn` returns the group, or `grpNull` when nothing spawns. `_roles`
is a list of role tokens, for example `["rifleman", "rifleman", "autogunner", "at", "medic"]`. An
unknown token logs a warning and raises no man for that entry.

1. Raise one `I_G_Soldier_F` per role on INDEPENDENT with `BIS_fnc_spawnGroup`, at `opfor_ai_skill`,
   and set `deleteGroupWhenEmpty`.
2. Re-dress each man from `DUWS_banditLooks` (see [Body](#body)).
3. Arm the men of each role with one `fnc_civ_arm` call: side `"IND"`, pool `["opfor", "blufor"]`,
   the role's `_spec`, no flip.
4. Return the group. The caller gives the orders and claims the group for teardown.

This is a bespoke raise (system 3 in
[`unit_spawning.md`](../info/architecture/unit_spawning.md#3-bespoke-direct-spawn--no-team-shape-to-share)),
not the token spawner. A roster token resolves roles to classes from an army's pools
(`DUWS_fnc_teamRoster`), and `fnc_spawn_team` serves only the two armies by design
(`server/placement/fnc_spawn_team.sqf:8-11`). A bandit is a dressed body, not a class, so no roster
row can name one.

## Phases

### Phase 1: kit tokens

Move the three predicates to the top level of `fn_factionAutoDetect.sqf`. In `fnc_civ_arm`, add the
pool union, fix `launcher`, add `grenadier` and `medic`, and update the contract header. This phase
stands alone: existing callers pass a string pool and use none of the three tokens.

### Phase 2: appearance and the parameter

Add `DUWS_Bandits`. Add `server/bandits/fnc_bandit_looks.sqf`, which reads the parameter, scans the
enabled sources and builds `DUWS_banditLooks`. Compile it in `server/server_fnc_init.sqf` and call it
in `server/server_init.sqf` after `fnc_factions_check` (`:31`).

### Phase 3: the raise

Add `server/bandits/fnc_bandit_spawn.sqf` and compile it in `server/server_fnc_init.sqf`. Parse-check
the new files with sqf-vm (see [`testing.md`](../info/architecture/testing.md)). Add a Bandits section
to [`faction_system.md`](../info/gameplay/faction_system.md) (sources, parameter, roles) and a row to
the system-3 table in [`unit_spawning.md`](../info/architecture/unit_spawning.md).

### Phase 4: first consumer

Open: where bandits appear in the campaign. The answer sets group size, the orders the caller gives
and who claims the group for teardown.

Every consumer respects these constraints:

- **Bandits are a vanilla-mode feature.** A consumer raises none in the apocalypse game mode. WBK
  zombies spawn on INDEPENDENT (`server/civilian/fnc_civ_handler_wbk.sqf:254`, `:359`), so bandits
  and zombies would share a side and never fight.
- **Bandits do not affect zone capture.** A zone's enemy trigger counts EAST only
  (`server/init_zones/fnc_createzone.sqf:155`), so bandits inside a zone neither hold it nor block its
  capture.
- **Teardown goes through the map sweep.** The consumer claims the group with `fnc_mission_claim`,
  like any mission group.

## Files touched

| File | Change |
|---|---|
| `shared/factions/MODERN/fn_factionAutoDetect.sqf` | Move `fnc_IsAT`, `fnc_IsAA` and `fnc_IsGrenadier` out of `fnc_unitParseRoles`. |
| `server/civilian/fnc_civ_arm.sqf` | Pool union; `launcher` fix; `grenadier` and `medic` tokens; contract header. |
| `shared/includes/params_modern.hpp` | `DUWS_Bandits`. |
| `server/bandits/fnc_bandit_looks.sqf` | New. Scans the sources and builds `DUWS_banditLooks`. |
| `server/bandits/fnc_bandit_spawn.sqf` | New. Raises a bandit group. |
| `server/server_fnc_init.sqf` | Compile the two new files. |
| `server/server_init.sqf` | Build `DUWS_banditLooks` after `fnc_factions_check`. |
| `docs/info/gameplay/faction_system.md` | Bandits section. |
| `docs/info/architecture/unit_spawning.md` | System-3 table row. |
