# Plan: split `duws/` by execution locality

Restructure `src/duws/` from topical folders (`functions/dialog`, `functions/warcom`, …)
into `server/`, `client/` and `shared/`, so a file's execution locality is visible from its
path. This is a migration plan; delete it once the migration is done. Background on the
locality model it encodes: [`server_client_authority.md`](server_client_authority.md).

## The rule the tree encodes

**A folder states where the file's own top-level body executes.** Nothing more.

That deliberately excludes two things a folder cannot express:

- **Callbacks.** 49 files register an `addAction`, trigger, button or map-click body that runs
  on whichever machine triggers it, not where the file ran. `init_zones/fnc_createzone.sqf`
  builds a zone on the server *and* hangs actions that fire on a player's machine. It belongs
  in `server/` — that is where its body runs — and its line-1 header keeps recording the
  callback caveat, which is more precise than any folder name.
- **Reachability.** The registry broadcasts 177 of its 264 compiled functions with
  `publicVariable`, so their code exists on every machine. Having a copy is not running there.

`shared/` is therefore narrow: files whose *top-level body* genuinely runs on more than one
machine (16 of them, headed `Locality: all machines` or `server or client`), plus data,
config and assets that have no locality at all.

> This narrows what an earlier sketch of this split proposed, which put all 65
> dual-locality files in `shared/`. Sorting the 49 callback-registering files there would move
> 5 of the 16 zone builders and most of the civilian system out of `server/` — files that are
> server code start to finish apart from the callbacks they attach. The result reads worse than
> today's neutral `supports/`, because a reader would trust `shared/` to mean "runs in more than
> one place" and be wrong 49 times out of 65.

## Target tree

```text
src/duws/
  server/
    server_init.sqf  server_var_init.sqf  server_fnc_init.sqf
    init_zones/  warcom/  missions/  misc/  init_hq/  dialog/  supports/
  client/
    client_init.sqf
    dialog/  supports/  misc/  init_hq/  operative/  sounds/  includes/
  shared/
    functions/   the 16 runs-on-any-machine files
    factions/    faction data and the autodetect functions
    includes/    the .hpp config description.ext pulls in
    sounds_npics/
```

Filenames do not change. `server/server_init.sqf` is mildly redundant, but renaming it to
`init.sqf` would churn `INIT.sqf`, ~15 locality headers that cite it by path, and six docs
that cite it by basename, in exchange for nothing the folder does not already say.

## Where each source folder lands

Counts are files whose destination is already provable from a locality header or a column-0
`isServer` / `hasInterface` guard. `TBD` is the classification work in phase 1.

| Source | server | client | shared | TBD | Total |
|---|---:|---:|---:|---:|---:|
| `functions/misc` | 58 | 20 | 12 | 4 | 94 |
| `functions/dialog` | 7 | 17 | 3 | 23 | 50 |
| `functions/missions` | 29 | 1 | 0 | 4 | 34 |
| `functions/supports` | 3 | 6 | 1 | 17 | 27 |
| `functions/init_zones` | 16 | 0 | 0 | 9 | 25 |
| `functions/warcom` | 19 | 1 | 0 | 0 | 20 |
| `functions/init_hq` | 6 | 5 | 0 | 0 | 11 |
| `functions/sounds` | 0 | 1 | 0 | 0 | 1 |
| **`functions/` total** | **138** | **51** | **16** | **57** | **262** |

The rest of the tree carries no such question:

| Source | Destination | Reason |
|---|---|---|
| `factions/` (256) | `shared/factions/` | Spawn tables the server reads and clients re-read on JIP (`client_init.sqf:161-168`). `MODERN/fn_factionAutoDetect.sqf` is compiled server-side but defines functions its own header describes as running "wherever their own callers do, including client dialogs" |
| `includes/` (20 `.hpp`) | `shared/includes/` | `description.ext` is engine-pinned config parsed on every machine; dialog *definitions* are not dialog *code* |
| `includes/supports_init.hpp`, `squad_number_init.hpp` | `client/includes/` | These two are SQF bodies `#include`d by `client_init.sqf:52-53`, not config. `squad_number_init.hpp` already documents that its counters are per-client |
| `sounds_npics/` | `shared/sounds_npics/` | Assets, referenced from `description.ext` and `includes/sounds.hpp` |
| `operative/modern/` (5) | 4 → `client/operative/`, `fnc_operative_mission_complete.sqf` → `server/misc/` | The one server file is called from `fnc_blufor_cap` and `fnc_mission_reward`; keeping a one-file `server/operative/` would be structure for its own sake |
| `init/` (4) | 3 → `server/`, `client_init.sqf` → `client/` | The `init/` folder disappears; the root `INIT.sqf` stays put, engine-pinned |

Four files under `functions/` are not in the registry at all and need a decision rather than a
destination: `init_zones/fnc_spawnwait - copy.sqf` (dead — delete rather than file it),
`misc/fnc_collectEquipmentFromUnits.sqf` (`execVM`'d from
`server_init.sqf:479`), `misc/fnc_hirePartisans_clientMap.sqf` (compiled in
`client_init.sqf:3`), and `warcom/fnc_WARCOM_opf_qrf.sqf` (compiled as `fnc_QRF_test` in
`server_var_init.sqf:164`).

## Phases

Each phase is one commit and ends green on `bash tests/run.sh`.

### Phase 1 — classify, move nothing

Add a `// Locality:` header to the 57 files that have neither a header nor a column-0 guard,
naming the evidence (`remoteExec` target, dialog action, or the caller it inherits from) as
the existing 141 headers do. Concentrated in `functions/dialog` (23) and
`functions/supports` (17).

- [ ] Header every unclassified file
- [ ] Verify: the classifier below reports zero `TBD`
- [ ] Verify: `bash tests/run.sh` green (headers are comments; nothing should move)

This phase carries all the judgement and none of the risk, and it is worth having on its own
if the rest is abandoned. Watch for the three failure modes
[`server_client_authority.md`](server_client_authority.md#adding-a-function) records: an
*indented* guard governs its block and not the file (`supports/fnc_helolift.sqf` is the
example), an `addAction` body runs on whoever triggers it, and `player` is `objNull` wherever
the server executes.

Regenerating the classification, so no stale list has to live in this doc:

```sh
python3 - <<'PY'
import re, os
for root, _, fs in os.walk('src/duws'):
    if os.sep + 'factions' in root: continue   # spawn tables, not code with a locality
    for f in sorted(fs):
        if not f.endswith('.sqf'): continue
        p = os.path.join(root, f)
        t = open(p, encoding='utf-8', errors='replace').read()
        if re.search(r'Locality:', t[:4000]): continue
        if any(re.match(r'if\s*\(\s*!?\s*(isServer|hasInterface|isDedicated)\b', l)
               for l in t.split('\n')[:60]): continue
        print('TBD', p)
PY
```

### Phase 2 — move `shared/`

`factions/`, `includes/`, `sounds_npics/` and the 16 runs-anywhere functions. No locality
question, so it exercises the path-rewrite mechanics on the least contentious files.

- [ ] `git mv` the four groups
- [ ] Rewrite `description.ext`'s 21 `#include`s and `includes/sounds.hpp`'s 5 asset paths
- [ ] Rewrite the two dynamic builds by hand — `init_hq/fnc_BLUFOR_faction_init.sqf:23` and
      `warcom/fnc_OPFOR_faction_init.sqf:17` both concatenate `"duws\factions\" + VERSION_X`
- [ ] Verify: `bash tests/run.sh` green, and grep the tree for surviving `duws\factions`,
      `duws\includes`, `duws\sounds_npics` literals — the linter cannot see the two dynamic ones

### Phase 3 — move `server/`

- [ ] `git mv` the 138 + resolved-TBD server files and the three `server_*.sqf`
- [ ] Rewrite the affected subset of the 265 registry paths in `server_fnc_init.sqf`
- [ ] Rewrite `INIT.sqf:16`, `server_init.sqf:5-6,479`, `server_var_init.sqf:164`
- [ ] Verify: `bash tests/run.sh` green

### Phase 4 — move `client/`

- [ ] `git mv` the 51 + resolved-TBD client files, `client_init.sqf`, `operative/`
- [ ] Rewrite the remaining registry paths, `INIT.sqf:21`, `client_init.sqf:3` and its two
      relative `#include "..\includes\…"` directives
- [ ] Verify: `bash tests/run.sh` green, and zero `"duws\functions`, `"duws\init`,
      `"duws\operative` literals remain

### Phase 5 — documentation and the smoke test

- [ ] Update the ~20 locality headers that cite a moved path, and the path citations in
      `architecture.md` (9), `faction_system.md` (9), `server_client_authority.md` (8),
      `cp_economy.md` (7), `arma_engine_gotchas.md` (5), `hq_layout_editing.md` (5),
      `zone_and_town_generation.md` (4)
- [ ] Replace `architecture.md`'s source-layout and `functions/` tables with the new tree, and
      fold the placement rule above into it
- [ ] `repack.cmd`, then a full in-game run: host a LAN game, generate zones, capture one,
      request a support and a side mission, save and reload

## What the tests do and do not cover

`tests/lint/check_paths.py` resolves every static `execVM` / `preprocessFile` / `#include`
path case-insensitively, which is exactly the failure a folder move produces, and it is
mechanical to re-run after each phase. It is a necessary check, not a sufficient one:

| Gap | Consequence |
|---|---|
| Dynamic paths are skipped by design | The two `"duws\factions\" + VERSION_X` builds break silently; only the phase 2 grep and the in-game run catch them |
| Path resolution is not execution | A registry entry pointed at the wrong file still resolves. Only the smoke test proves the campaign boots |
| The registry's `publicVariable` lines are unchecked | A client calling a function that was never broadcast fails as a nil-variable error at the call site, far from the cause |

The three build scripts need no changes: `repack.cmd` stages `src/` wholesale, and
`duws_eden.ps1` scans for marker comments rather than fixed paths.

## Keeping it true

The split makes locality visible but cannot enforce it — nothing stops a later commit
dropping a client dialog into `server/misc/`. The cheap guard is a third lint alongside the
existing two, failing when a file's declared locality disagrees with its folder, and when a
file under `client/` is not `publicVariable`'d in the registry. That second check is the one
with standalone value: a missing broadcast is currently a runtime nil-variable error with no
static signal at all. It is not a prerequisite for any phase above.
