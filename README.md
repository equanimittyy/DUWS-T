# DUWS_T

**DUWS_T** (*Dynamic Universal War System: Tactic*) is a single-player / co-op
dynamic campaign mission for **Arma 3**. It procedurally
generates a persistent war: capture zones, run side missions, call in support, and
fight an AI opposition that reacts to your moves. It descends from Tomata's DUWS_X
(originally Kibot's DUWS), reworked here with new side missions, a revised
support/economy system, and automatic faction detection (with ALIVE support), so it
runs mod-free yet adapts to most faction mods.

Play it on the Steam Workshop:
**[[SP/COOP] DUWS_T](https://steamcommunity.com/sharedfiles/filedetails/?id=3685431219)**

## Repo layout

This repo version-controls the **unpacked** mission source. The packed `.pbo` is
build output, repacked from the source, and is **not** tracked (see `.gitignore`).
`repack.cmd` names it after the source commit — `DUWS_T_<hash>.altis.pbo`, e.g.
`DUWS_T_d016106.altis.pbo` — so the file on disk identifies the build it came from.
Commit the unpacked `src/` source; leave the regenerated `.pbo` untracked.

The mission's internal structure (the `modules/` vs `duws/` split, boot flow, and
subsystems) is mapped in [`docs/info/architecture.md`](docs/info/architecture.md).

## Developer setup

### 1. Obtain PBO Manager

The mission ships as a packed `.pbo`. Editing it means unpack → change files →
repack, and both steps use **PBO Manager**, a third-party Windows tool.

`tools/PBO Manager/` is **git-ignored**: it's not project source, and its Windows
binaries won't run in the Linux devcontainer, so each environment supplies its own
copy at that path:

1. Download a release from https://github.com/winseros/pboman3.
2. Unzip it into `tools/PBO Manager/`, so that `tools/PBO Manager/pboc.exe` exists.

### 2. Unpack / repack the mission

Two Windows batch scripts wrap the CLI (Windows only; they call `pboc.exe`, which
won't run in the Linux devcontainer):

- **`scripts/unpack.cmd`**: extracts `DUWS_T.altis.pbo` into a flat `src/` folder. Run it
  once to seed `src/`, then commit `src/`. It asks for confirmation first and warns
  that re-running replaces `src/` and discards edits.
- **`repack.cmd`**: packs `src/` back into `DUWS_T_<hash>.altis.pbo` at the repo root,
  asking before it overwrites the `.pbo`, then normalizes the PBO's internal paths to Arma's
  backslash convention via `scripts/normalize_pbo.ps1`. The result is ready to load in Arma.
  It first deletes any prior `DUWS_T*.altis.pbo` in the root, so only the newest build remains.

Edit the mission as `.sqf` / `.hpp` / etc. under `src/`; the packed `.pbo` stays
build output (git-ignored).

`repack.cmd` also stamps the build into the staged copy, so the mission's first log line
names the source it came from — `DUWS_T START ---- build d016106-dirty 2026-08-05T00:20:13`.
The same hash goes in the `.pbo` filename, and the `-dirty` suffix (shortened to `-d` in the
filename) means `src/` had uncommitted changes at pack time. Check it before trusting an
`.rpt`: a stale `.pbo` in `MPMissions\` reads exactly like a fix that failed.

### 3. Load it in Arma for testing

Copy the packed `DUWS_T_<hash>.altis.pbo` into the Arma 3 **install** folder's `MPMissions\`,
e.g. `...\steamapps\common\Arma 3\MPMissions\`, **not** `Documents\Arma 3\MPMissions\`
(local hosting reads the install folder). Then host a LAN / multiplayer game and select
it from the list. The `<name>.<world>.pbo` filename is required: Arma reads the terrain
from the `.<world>.` part, so the `_<hash>` in the name is free to vary per build.

Hosting this way runs the server and a client in one process, which hides every
locality fault. Persistence, JIP and remote execution need a real dedicated server to
prove anything: [`docs/info/architecture/testing.md`](docs/info/architecture/testing.md#running-a-dedicated-server)
sets one up from the executable already in your Arma install.

## Tests

Static checks (SQF syntax + path resolution) and pure-function unit tests live in
[`tests/`](tests/); run `bash tests/run.sh`. Details in [`docs/info/architecture/testing.md`](docs/info/architecture/testing.md).

Neither layer can see a running mission. What still needs an in-game pass, what is known
broken, and what the previous developer worked around rather than fixed are listed in
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

## Conventions

Working rules for contributors and agents (voice, comments, docs) live inline in
[`CLAUDE.md`](CLAUDE.md) and load each session.

Arma engine traps that aren't visible in the SQF (e.g. what may be stored in the mission
namespace) are collected in [`docs/info/architecture/arma_engine_gotchas.md`](docs/info/architecture/arma_engine_gotchas.md).
