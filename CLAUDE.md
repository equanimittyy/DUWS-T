# CLAUDE.md

## What this project is

DUWS_T (*Dynamic Universal War System — Tactic*) is a single-player / co-op dynamic
campaign mission for Arma 3, shipped on the Altis map. It procedurally generates a
persistent war: the player captures zones, runs side missions, and calls in support
while an AI opposition reacts. It descends from Tomata's DUWS_X (originally Kibot's
DUWS), rebuilt here with reworked side missions, a revised support/economy system,
and automatic faction detection (with ALiVE ORBAT Creator support) — so it runs
mod-free yet adapts to most faction mods on the Workshop.

"Done well" means the mission stays tactically demanding (one bad move costs the
player dearly), keeps working in single-player and LAN co-op with no required mods,
and stays portable to other maps. Player-facing page:
https://steamcommunity.com/sharedfiles/filedetails/?id=3685431219

## Principles

- **No hard mod dependency.** The mission must run stand-alone. Anything that would
  force a mod, or break the faction auto-detection / ALiVE ORBAT Creator support, is
  the wrong call.
- **The unpacked source is the source of truth.** Edit the mission under `src/`
  and repack; never hand-edit the packed `.pbo`. Workflow: [`README.md`](README.md).
- **Mind the engine's traps.** Arma-specific behaviours that aren't visible in the SQF
  (e.g. what may be stored in the mission namespace) are collected in
  [`docs/info/architecture/arma_engine_gotchas.md`](docs/info/architecture/arma_engine_gotchas.md). Read it before writing
  engine-touching SQF and before chasing a strange engine error, and add any new trap you hit in the
  same change that works around it.

## Working method

Bias to caution over speed; when in doubt these beat momentum.

1. **Think before coding.** State assumptions. Surface multiple interpretations instead of silently picking one; if it's unclear, ask — don't infer and commit. Name a simpler approach before building the complex one.
2. **Simplicity first.** Minimum code that solves the stated problem. No speculative features, single-use abstractions, unrequested config, or guards for impossible cases. If the diff is 200 lines and the problem needed 50, rewrite it.
3. **Surgical changes.** Touch only what the task requires. Don't reformat or refactor adjacent code; match existing style. Remove orphans your edit creates; flag *pre-existing* dead code, don't silently delete it.
4. **Goal-driven.** Turn fuzzy asks into verifiable outcomes first: "add validation" → tests for invalid inputs; "fix the bug" → a failing repro that goes green. State a brief step → verify plan for multi-step work.
5. **Errors are yours.** Build / typecheck / lint / test failures surfaced during your work are yours to fix or escalate. "Pre-existing" and "unrelated" are deferrals, not diagnoses: if a failure truly predates your diff, say so concretely and ask — don't wave it away.
6. **Commits are explicit-only.** Never `git commit` / `push` unless asked *this turn*; "implement / fix / finish X" means do the work and leave it in the tree for review. Approval for one commit doesn't carry to the next. Commit directly on the working branch; branch only if explicitly told to. Before staging, sweep each touched file (not just the diff) for comments that fail the §Documentation & comments bar. When authorised: Conventional Commits (`feat` / `fix` / `docs` / `refactor` / `chore` / `test`, optional scope); a subject naming the change, and a *why*-focused body only where the diff doesn't show the reason. Write the body as Markdown bullets (`- `), one fact per bullet — never prose paragraphs. Each bullet is one physical line (never hard-wrap — it breaks the Markdown render), ≤400 chars.

## Documentation & comments

Decided things only. Explain **why, never what** — the reader can read the code. Never cite a tracking ID or origin tag (ticket / run / finding / PR, `#1234`, run-dates): they rot; describe the failure mode or constraint directly.

Keep CLAUDE.md slim (purpose + rules; update only when the project's purpose or feel changes). Reference docs hold decided things — speculation goes to the tracker, not prose; update the doc in the same change that alters what it describes. No work-tracking checklists in markdown; backlog and status live in the issue tracker.

**Comments** — default none; the bar to add one is high (deleting needs no reason, adding does). First fix the name or split the function — a comment is the last resort, not the first. A line is earned *only* by a *why* the code can't show: a load-bearing invariant, a rejected alternative, a security / concurrency rationale, a non-obvious encoding, a bug's failure mode. Everything else is noise, cut on sight — restating the next line, narrating a branch or how the code got here, re-describing a visible mechanism, hedging, scene-setting, field-restating JSDoc, section banners, per-function / per-block reflexes, commented-out code, names, dates, emojis. One line; a file-top docblock may carry a longer *why* (locality, invariants, engine traps), kept tight. Delete any duplicate the docblock or a neighbour already states; when unsure, delete. Bad: `// loop the array`. Good: none, or `// Retry: API flakes under load`.

**Prose docs** keep file:line refs and cross-doc pointers (relative links, anchored to stable headings). Drop tracking citations, run-dated / origin-tagged headings, "last updated", restated titles, and "revisit later". One idea per paragraph; a table for 3+ parallel facts; a heading with no body is a TODO. Filenames are `lower_snake_case` (subdir docs get descriptive names, not `README.md`); `UPPER_CASE` only for repo-root `CLAUDE.md` / `README.md`. Smell test per addition: finish "a future reader won't know that…" — can't? Delete it.
