# DUWS_T

**DUWS_T** (*Dynamic Universal War System — Tactic*) is a single-player / co-op
dynamic campaign mission for **Arma 3**, built on the **Altis** map. It procedurally
generates a persistent war — capture zones, run side missions, call in support, and
fight an AI opposition that reacts to your moves. It descends from Tomata's DUWS_X
(originally Kibot's DUWS), reworked here with new side missions, a revised
support/economy system, and automatic faction detection (with ALIVE support), so it
runs mod-free yet adapts to most faction mods.

Play it on the Steam Workshop:
**[[SP/COOP] DUWS_T](https://steamcommunity.com/sharedfiles/filedetails/?id=3685431219)**

## Repo layout

This repo version-controls the **unpacked** mission source. `DUWS_T.altis.pbo` is
build output — repacked from the source — and is **not** tracked (see `.gitignore`).
Commit the unpacked `src/` source; leave the regenerated `.pbo` untracked.

The mission's internal structure (the `modules/` vs `duws/` split, boot flow, and
subsystems) is mapped in [`docs/architecture.md`](docs/architecture.md).

## Developer setup

### 1. Obtain PBO Manager

The mission ships as a packed `.pbo`. Editing it means unpack → change files →
repack, and both steps use **PBO Manager**, a third-party Windows tool.

`tools/PBO Manager/` is **git-ignored** — it's not project source, and its Windows
binaries won't run in the Linux devcontainer, so each environment supplies its own
copy at that path:

1. Download a release from https://github.com/winseros/pboman3.
2. Unzip it into `tools/PBO Manager/`, so that `tools/PBO Manager/pboc.exe` exists.

### 2. Unpack / repack the mission

Two Windows batch scripts wrap the CLI (Windows only — they call `pboc.exe`, which
won't run in the Linux devcontainer):

- **`unpack.cmd`** — extracts `DUWS_T.altis.pbo` into a flat `src/` folder. Run it
  once to seed `src/`, then commit `src/`. It asks for confirmation first and warns
  that re-running replaces `src/` and discards edits.
- **`repack.cmd`** — packs `src/` back into `DUWS_T.altis.pbo` at the repo root, asking
  before it overwrites the `.pbo`. The result is ready to load in Arma.

Edit the mission as `.sqf` / `.hpp` / etc. under `src/`; the packed `.pbo` stays
build output (git-ignored).

## Conventions

Working rules for contributors and agents (voice, comments, docs) live in
[`docs/claude/`](docs/claude/) and load each session via [`CLAUDE.md`](CLAUDE.md).
