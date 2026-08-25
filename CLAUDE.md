# CLAUDE.md

## What this project is

DUWS_T (*Dynamic Universal War System — Tactic*) is a single-player / co-op dynamic
campaign mission for Arma 3, shipped on the Altis map. It procedurally generates a
persistent war: the player captures zones, runs side missions, and calls in support
while an AI opposition reacts. It descends from Tomata's DUWS_X (originally Kibot's
DUWS), rebuilt here with reworked side missions, a revised support/economy system,
and automatic faction detection (with ALIVE support) — so it runs mod-free yet adapts
to most faction mods on the Workshop.

"Done well" means the mission stays tactically demanding (one bad move costs the
player dearly), keeps working in single-player and LAN co-op with no required mods,
and stays portable to other maps. Player-facing page:
https://steamcommunity.com/sharedfiles/filedetails/?id=3685431219

## Principles

- **No hard mod dependency.** The mission must run stand-alone. Anything that would
  force a mod, or break the faction auto-detection / ALIVE support, is the wrong call.
- **The unpacked source is the source of truth.** Edit the mission under `src/`
  and repack; never hand-edit the packed `.pbo`. Workflow: [`README.md`](README.md).
- **Mind the engine's traps.** Arma-specific behaviours that aren't visible in the SQF
  (e.g. what may be stored in the mission namespace) are collected in
  [`docs/info/architecture/arma_engine_gotchas.md`](docs/info/architecture/arma_engine_gotchas.md); check it before chasing a
  strange engine error.

## Always-loaded working rules

Voice, working method, commit style, and comment/doc style live in `docs/claude/`
and load every session:

@docs/claude/BEHAVIOUR.md
@docs/claude/CODE_COMMENTS.md
@docs/claude/DOCUMENTATION.md

## Optional: caveman plugin + statusline context bar

Per-machine conveniences (Claude Code user config, *not* this repo): the caveman
compressed-communication plugin and the context-window statusline bar. Full
reconstruction recipe lives in the `caveman-statusline-setup` skill — invoke it when
setting up a new machine or restoring the config.
