# DUWS_T mission architecture

Orientation map for the unpacked mission source under `src/`. For the unpack/repack
build workflow see [`../README.md`](../README.md); for working rules (voice, comments,
docs) see [`claude/`](claude/).

## Lineage

DUWS_T is a fork chain: Kibot's original DUWS → Killa Tomata's DUWS_X → 5U5's DUWS_T.
The practical consequence for a maintainer is that provenance is not uniform: older
English-commented DUWS-era code sits alongside 5U5's Chinese-commented additions, and
three third-party AI/logistics/medical frameworks are embedded wholesale. Treat each
subsystem on its own terms rather than assuming one authorship or style.

## Source layout: vendored vs owned

The mission root splits into two trees plus the engine-pinned root files.

| Path | Contents | Ownership |
|---|---|---|
| `src/modules/` | `AIS`, `R3F_LOG`, `VCOM`, `taw_vd`, `zbe_cache` | Vendored third-party — **frozen** |
| `src/duws/` | `functions`, `includes`, `init`, `operative`, `factions`, `sounds_npics` | DUWS_T (Kibot/Tomata/5U5 lineage) |
| `src/` (root) | `mission.sqm`, `description.ext`, `stringtable.xml`, root event scripts, `DUWS_T.jpg` | Engine-pinned |

The engine loads a fixed set of scripts by name from the mission root and they cannot
move: `INIT.sqf`, `initPlayerLocal.sqf`, `onPlayerKilled.sqf`, `onPlayerRespawn.sqf`.
Note the root `INIT.sqf` (an entry script) is distinct from the `duws/init/` folder
(the server/client init scripts it delegates to).

**The `modules/` boundary is load-bearing.** Editing a vendored framework forfeits the
ability to pull upstream fixes and inherits its bugs permanently. Change code in
`duws/`; leave `modules/` alone.

Folder names under `duws/` follow `lower_snake_case`. The one intentional exception is
`duws/factions/MODERN`: `MODERN` mirrors the `VERSION_X` logic constant (see
[§Cross-cutting systems](#cross-cutting-systems)), so it is uppercase like a constant,
not a naming slip.

## Path references are string literals

Arma has no compiler and no path resolver. Script and asset paths are string literals,
resolved **relative to the mission root** for `execVM` / `execFSM` / `preprocessFile` /
`preprocessFileLineNumbers` / `loadFile` / `compile preprocessFile*`, and **relative to
the including file** for `#include`. A moved or renamed folder therefore breaks every
reference to it silently — the failure surfaces only at runtime, in-game. Any folder
restructure must rewrite all such references and be smoke-tested in Arma; grep-verifying
zero residual paths is necessary but not sufficient.

Two function-loading mechanisms coexist, which is not inferable from any single file:

- **Vendored frameworks** register through `CfgFunctions` in
  [`../src/description.ext`](../src/description.ext), producing namespaced globals
  (`AIS_*_fnc_*`, `TAWVD_fnc_*`, `VCM_fnc_*`).
- **The DUWS core** compiles its `fnc_*` globals from a hand-maintained registry in
  `src/duws/init/server_fnc_init.sqf` (~250 entries). There is no manifest of these
  functions beyond that file.

## Boot flow

`INIT.sqf` is the runtime entry point; `description.ext` wires config and `mission.sqm`
is binarized world state.

```text
INIT.sqf ── detects role (server / hosted / client / headless)
  ├─ server → duws/init/server_init.sqf   campaign generator
  ├─ client → duws/init/client_init.sqf   UI, actions, menus
  └─ both   → modules/R3F_LOG/init.sqf    logistics, after WARCOM is ready
```

`server_init.sqf` runs the campaign lifecycle in order: compile the function registry →
faction detection and BLUFOR/OPFOR init → place HQ (blocks on the player) → generate
enemy zones → start the WARCOM AI director → register the capture-zones win task → then
the ongoing side-mission spawner, cleanup loops, and event scripts.

## The DUWS engine — `duws/functions/`

| Subdir | Role |
|---|---|
| `init_zones/` | Procedural zone generation: garrisons, patrols, fortifications, capture logic. Where zones are sited (the "More Urban" town detection) and the separate civilian "Dynamic Town" system are in [`zone_and_town_generation.md`](zone_and_town_generation.md) |
| `init_hq/` | HQ and FOB setup: base init, fortify/guard, FOB patrols. How the Main Base layout is built and how to rearrange it (including an Eden round-trip) are in [`hq_layout_editing.md`](hq_layout_editing.md) |
| `missions/` | Side missions: spawner (`fnc_missionLocator`), rewards, timers; `mission_threads/` holds one folder per mission type |
| `supports/` | Support requests: CAS, artillery, UAV, paradrop, heli-lift, vehicle drop, FOB deploy, transport |
| `warcom/` | War Command — the dynamic AI director for both sides (assault / patrol / QRF task forces reacting to the front line) |
| `dialog/` | Runtime UI: HQ/FOB request menus, mobile-HQ deploy, campaign menu, faction dialog, the CP/AP economy |
| `misc/` | Autosave, recruiting, black market, civilian/informant system, intel-on-death, fast travel, AI master control |
| `sounds/` | Ambient music loop |

## Cross-cutting systems

| System | Where | Note |
|---|---|---|
| Economy | `functions/dialog/`, `functions/supports/` | Two currencies, CP and AP, earned by capturing zones and completing side missions. CP faucets, sinks, and balance concerns in [`cp_economy.md`](cp_economy.md) |
| Persistence | `functions/misc/fnc_autoSave.sqf` | Vanilla `saveGame` only — no custom serialization; save/continue relies entirely on the engine's campaign save |
| Faction detection | `functions/misc/fnc_factions_check_modern.sqf`, `factions/MODERN/AUTODETECT_*` | Adapts to installed faction mods and runs mod-free. `VERSION_X` (value `"MODERN"`) selects the faction set, doubles as the `factions/` subfolder name, and is game state — so its value is not safe to change. Full detail in [`faction_system.md`](faction_system.md) |
| Revive | `initPlayerLocal.sqf` | Chosen at start: AIS, vanilla, or auto-disabled when ACE medical is present |
| Performance | `modules/zbe_cache`, `modules/taw_vd`, `functions/misc/fnc_repetitive_cleanup.sqf` | Distant-AI caching, view-distance control, and aggressive zone cleanup keep a whole-map persistent war affordable |
| Hardcore mode | `hardcore_mode_enable`, chosen in the environment menu (`functions/dialog/fnc_process_enviro_menu.sqf:160`), gating ~22 sites across `functions/init_zones/`, `functions/missions/`, `functions/warcom/` | Zone markers are created at alpha 0 and revealed by entering a zone or finding intel (`functions/init_zones/fnc_zone_reveal.sqf`); `hardcore_visibleZone_found` then releases WARCOM waves and task-force squads. See the gap below |

**Known gap: hardcore does not hide zone positions from Zeus.** Under the BLUFOR curator option
(`ZeusStatus == 1`), `functions/misc/fnc_zeus_objects_init.sqf` adds every WEST and CIVILIAN unit
and vehicle to the curator on a 30 s loop. Arma counts static weapons as vehicles, so a curator
can read a hidden zone's defences straight off the map. A branch there once narrowed the civilian
half to aircraft for exactly this reason, but it tested `DUWS_MODE == "HARDCORE"` — a value
nothing ever assigned — so it never ran once, and it has been removed rather than left as dead
code. Restoring the intent means gating on `hardcore_mode_enable` instead, and applying the same
guard to the civilian *unit* loop above it, which never had one.

## Vendored frameworks — `modules/`

| Framework | Purpose |
|---|---|
| `AIS` | Advanced Injury System — revive/medical, an alternative to ACE or vanilla |
| `R3F_LOG` | R3F Logistics — vehicle/object lift, tow, load, and factory building |
| `VCOM` | VCOM AI — enemy AI behavior enhancement |
| `taw_vd` | TAW View Distance control |
| `zbe_cache` | ZBE caching — despawns distant AI for performance |
