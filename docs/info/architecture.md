# DUWS_T mission architecture

Orientation map for the unpacked mission source under `src/`. For the unpack/repack build workflow see
[`README.md`](../../README.md); for working rules (voice, comments, docs) see [`claude/`](../claude/).

## Lineage

DUWS_T is a fork chain: Kibot's original DUWS → Killa Tomata's DUWS_X → 5U5's DUWS_T. The practical
consequence for a maintainer is that provenance is not uniform: older English-commented DUWS-era code
sits alongside 5U5's Chinese-commented additions, and three third-party AI/logistics/medical frameworks
are embedded wholesale. Treat each subsystem on its own terms rather than assuming one authorship or
style.

## Source layout: vendored vs owned

| Path | Contents | Ownership |
|---|---|---|
| `src/modules/` | `AIS`, `R3F_LOG`, `VCOM`, `taw_vd`, `zbe_cache` | Vendored third-party — **frozen** |
| `src/duws/` | `server`, `client`, `shared` | DUWS_T (Kibot/Tomata/5U5 lineage) |
| `src/` (root) | `mission.sqm`, `description.ext`, `stringtable.xml`, root event scripts, `DUWS_T.jpg` | Engine-pinned |

The engine loads a fixed set of scripts by name from the mission root and they cannot move: `INIT.sqf`,
`initPlayerLocal.sqf`, `onPlayerKilled.sqf`, `onPlayerRespawn.sqf`. Note the root `INIT.sqf` (an entry
script) is distinct from `duws/server/server_init.sqf` and `duws/client/client_init.sqf` (the init
scripts it delegates to by role).

**The `modules/` boundary is load-bearing.** Editing a vendored framework forfeits the ability to pull
upstream fixes and inherits its bugs permanently. Change code in `duws/`; leave `modules/` alone.

Folder names under `duws/` follow `lower_snake_case`. The one intentional exception is
`duws/shared/factions/MODERN`: `MODERN` mirrors the `VERSION_X` logic constant (see
[§Cross-cutting systems](#cross-cutting-systems)), so it is uppercase like a constant, not a naming slip.

## Path references are string literals

Arma has no compiler and no path resolver. Script and asset paths are string literals, resolved
**relative to the mission root** for `execVM` / `execFSM` / `preprocessFile` /
`preprocessFileLineNumbers` / `loadFile` / `compile preprocessFile*`, and **relative to the including
file** for `#include`. A moved or renamed folder therefore breaks every reference to it silently — the
failure surfaces only at runtime, in-game. Any folder restructure must rewrite all such references and be
smoke-tested in Arma; grep-verifying zero residual paths is necessary but not sufficient.

Two function-loading mechanisms coexist, which is not inferable from any single file:

- **Vendored frameworks** register through `CfgFunctions` in
  [`src/description.ext`](../../src/description.ext), producing namespaced globals (`AIS_*_fnc_*`,
  `TAWVD_fnc_*`, `VCM_fnc_*`).
- **The DUWS core** compiles its `fnc_*` globals from a hand-maintained registry in
  `src/duws/server/server_fnc_init.sqf` (~310 entries). There is no manifest of these functions beyond
  that file.

## Globals have no namespace

`src/duws/` calls `publicVariable` on **394 distinct names** across over 500 sites, in a global namespace
several times that size. Nothing separates campaign state from scratch variables, so nothing prevents a
collision between subsystems and nothing makes one visible when it happens.

This is not fixable in bulk. A sweeping rename is the single highest-risk change available in this
codebase: `addPublicVariableEventHandler` matches names as strings, so a missed rename fails silently at
runtime with no compiler to catch it. **Require a `DUWS_` prefix on new globals, and prefix on touch.**
The mission already has instances of the discipline (`DUWS_enemyGear_scannedUnits`, `DUWS_zoneSpawnTiers`,
`DUWS_missionSlots`) beside bare ones like `support_count` and `Mission_available`.

Retiring a broadcast name needs positive evidence that no reader can exist, not merely the absence of one
in this tree — a `publicVariable`'d global is readable by any client and by any joiner, and the mission
ships to a workshop where third-party faction files call into it.

## Boot flow

`INIT.sqf` is the runtime entry point; `description.ext` wires config and `mission.sqm` is binarized
world state.

```text
INIT.sqf ── detects role (server / hosted / client / headless)
  ├─ server → duws/server/server_init.sqf   campaign generator
  ├─ client → duws/client/client_init.sqf   UI, actions, menus
  └─ both   → modules/R3F_LOG/init.sqf    logistics, after WARCOM is ready
```

`server_init.sqf` runs the campaign lifecycle in order: compile the function registry → faction detection
and BLUFOR/OPFOR init → place HQ (blocks on the player) → generate enemy zones → start the WARCOM AI
director → register the capture-zones win task → then the ongoing side-mission spawner, cleanup loops and
event scripts.

## The DUWS engine — `duws/`

The top level is execution locality, the level below it is subsystem:

```text
src/duws/
  server/   server_init.sqf  server_var_init.sqf  server_fnc_init.sqf
            init_zones/ warcom/ missions/ misc/ init_hq/ dialog/ supports/
  client/   client_init.sqf
            dialog/ supports/ misc/ init_hq/ operative/ missions/ warcom/ sounds/ includes/
  shared/   functions/ factions/ includes/ sounds_npics/
```

**A folder states where the file's own top-level body executes. Nothing more.** Two things it
deliberately cannot express, both recorded in the file's `// Locality:` header instead:

- **Callbacks.** ~49 files hang an `addAction`, trigger, button or map-click body that runs on whichever
  machine triggers it, not where the file ran. `server/init_zones/fnc_createzone.sqf` builds a zone on the
  server *and* attaches actions that fire on a player's machine; it lives in `server/` because that is
  where its own body runs.
- **Reachability.** `server_fnc_init.sqf` broadcasts most of what it compiles with `publicVariable`, so
  the code exists on every machine. Having a copy is not running there.

`shared/` is therefore narrow: `shared/functions/` holds only the files whose top-level body genuinely
runs on more than one machine, alongside data, config and assets that have no locality at all. A file
passed to `remoteExec` *by value* rather than by name needs no broadcast, so "never `publicVariable`'d"
does not imply server-only.

| Subsystem | Role |
|---|---|
| `init_zones/` | Procedural zone generation: garrisons, patrols, fortifications, capture logic. Siting (the "More Urban" town detection) and the civilian town system are in [`zones_and_civilians.md`](gameplay/zones_and_civilians.md) |
| `init_hq/` | HQ and FOB setup: base init, fortify/guard, FOB patrols. The Main Base layout, the tool that edits it and the spawn tables are in [`composition_tooling.md`](architecture/composition_tooling.md) (HQ specifics: [§Editing the HQ layout](architecture/composition_tooling.md#editing-the-hq-layout)) |
| `missions/` | Side missions: spawner (`fnc_missionLocator`), rewards, timers; `mission_threads/` holds one folder per mission type. How to add a type, and the design bar it must clear, in [`side_mission_authoring.md`](gameplay/side_mission_authoring.md) |
| `supports/` | Support requests: CAS, artillery, UAV, paradrop, heli-lift, vehicle drop, FOB deploy, transport |
| `warcom/` | War Command — the dynamic AI director for both sides (assault and patrol task forces reacting to the front line) |
| `dialog/` | Runtime UI: HQ/FOB request menus, mobile-HQ deploy, campaign menu, faction dialog, the CP/AP economy |
| `misc/` | Autosave, recruiting, black market, civilian/informant system, intel-on-death, AI master control |
| `sounds/` | Ambient music loop |
| `operative/` | Operative recruit/deploy menu |
| `includes/` | Dialog and config `.hpp` under `shared/`; the two `#include`d SQF bodies under `client/` |
| `functions/` | Under `shared/`: the runs-anywhere bodies, plus `fnc_log_init.sqf`, which defines `fnc_log` and `fnc_waitLogged` |

## Cross-cutting systems

| System | Where | Note |
|---|---|---|
| Economy | `client/dialog/`, `client/supports/` | Two currencies, CP and AP, earned by capturing zones and completing side missions, plus per-town reputation. Writers, faucets and sinks in [`economy.md`](gameplay/economy.md) |
| Persistence | `server/misc/fnc_autoSave.sqf` | Vanilla `saveGame` only — no custom serialization; save/continue relies entirely on the engine's campaign save |
| Faction detection | `server/misc/fnc_factions_check_modern.sqf`, `shared/factions/MODERN/AUTODETECT_*` | Adapts to installed faction mods and runs mod-free. `VERSION_X` (value `"MODERN"`) selects the faction set, doubles as the `shared/factions/` subfolder name, and is game state — so its value is not safe to change. Full detail in [`faction_system.md`](gameplay/faction_system.md) |
| Revive | `initPlayerLocal.sqf` | Chosen at start: AIS, vanilla, or auto-disabled when ACE medical is present |
| Scroll-menu actions | `addAction` / `BIS_fnc_holdActionAdd` / `fnc_open_action_menu` call sites across `client/`, `server/` and `shared/` | Priority and colour buckets are defined in `shared/includes/action_style.hpp`; a server-attached entry broadcasts with the owning object as the JIP target, so its id cannot outlive the object |
| Player-facing text | `stringtable.xml`, `fnc_cs` | English `<Original>`/`<English>` is the source of truth; the localised tags lag it deliberately, and any key naming the player callsign must go through `fnc_cs`. Style guide: [`player_text_style_guide.md`](gameplay/player_text_style_guide.md) |
| Performance | `modules/taw_vd`, `server/misc/fnc_site_stream_init.sqf`, `server/misc/fnc_repetitive_cleanup.sqf` | View-distance control, one poller streaming every site's AI and props, and aggressive cleanup keep a whole-map persistent war affordable. `modules/zbe_cache` ships **disabled**; why re-enabling it is not a one-line change is in [`performance.md`](architecture/performance.md) |
| Hardcore mode | `hardcore_mode_enable`, chosen in the environment menu (`client/dialog/fnc_process_enviro_menu.sqf:160`), gating ~22 sites across `server/init_zones/`, `server/missions/`, `server/warcom/` | Zone markers are created at alpha 0 and revealed by entering a zone or finding intel (`server/init_zones/fnc_zone_reveal.sqf`). See [`intel_system.md`](gameplay/intel_system.md) |

## Vendored frameworks — `modules/`

| Framework | Purpose | State |
|---|---|---|
| `AIS` | Advanced Injury System — revive/medical, an alternative to ACE or vanilla | Active |
| `R3F_LOG` | R3F Logistics — vehicle/object lift, tow, load, and factory building | Active |
| `VCOM` | VCOM AI — enemy AI behavior enhancement | Compiled but never started; nothing calls `VCM_fnc_VcomInit` |
| `taw_vd` | TAW View Distance control | Active |
| `zbe_cache` | ZBE caching — despawns distant AI for performance | Present but disabled; zone streaming owns AI despawn instead |
