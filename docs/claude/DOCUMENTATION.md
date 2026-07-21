# Documentation Style

Lean and substance-only. Docs cost reading time and rot independently of code. Sister file: [`CODE_COMMENTS.md`](CODE_COMMENTS.md) (same philosophy, applied to code). Operational rules (where docs live, when to update them) are in [`BEHAVIOUR.md`](BEHAVIOUR.md); this is the *prose-shape* guide.

## Core rule

**Decided things only. Explain WHY, never WHAT.** The reader can read the code. Docs exist for:

- Cross-system contract (join key, schema lockstep, calibration boundary)
- Load-bearing constraint or invariant
- Why a "simpler" alternative was rejected
- Operational rationale (deploy gate, security layer, blast-radius cap)
- Convention not inferable from one file

Speculation does **not** go in reference docs: only as a tracked issue stating the open question as the work (or a design doc's open-questions section, if the repo keeps one).

## Drop

- **Tracking-system citations**: ticket/audit/run/finding/PR IDs. They rot; substance doesn't. `Covers post-code Run 2`, `See audit Run 20 D1`, `TODO(PROJ-1234)` → state the WHY directly instead (e.g. "validate the webhook signature before parsing: an unsigned payload must never reach the handler").
- **Run-dated / origin-tagged headings**: `## Post-code triage (2026-04-14)`, `### Known gaps: from edge-finder`. Group by *what the work is*, not where it came from.
- **Author names, dates, changelogs, "Last updated"**: git owns provenance.
- **Restated titles / TOC**: don't open `## Authentication` with "This section covers authentication."
- **"Will be revisited later"**: file an issue or drop the line.

## Keep

- **File:line refs**: load-bearing; readers don't grep. `` `src/server/health.ts:150-163` races the query against a 1.5s timer; the loser keeps running against the shared pool. ``
- **Cross-doc pointers**: relative links, anchored when the target has stable headings. `See [§Some Section](path/to/doc.md#some-section).`
- **Concurrency / forensic contracts**: name the contract, the field, the failure mode (same shape as code comments).

## Rules

- One paragraph per idea. Tables for 3+ parallel facts; bullets for sequential.
- A heading with no body is a TODO: fill or remove.
- A >~40-line bullet list is probably a table or two subsections.
- CLAUDE.md and README are slim by design (overview + pointer). Don't grow them.
- **Filenames are `lower_snake_case`** (hyphens → underscores too). Exceptions keep `UPPER_CASE`: anything in `docs/claude/`, and the repo-root `CLAUDE.md` / `README.md`. Subdirectory docs get descriptive snake_case names, *not* `README.md`.
- No emojis. Code fences carry language tags. File paths in backticks with a package/dir prefix when ambiguous.
- **Backlog and status live in your issue tracker**, not markdown. The only `- [ ]` exemptions are checklists the project explicitly sanctions (e.g. a plan's task list or a pre-deployment checklist). A closed checklist row is deleted, not summarised.
- Don't restate one doc in another: link. Summarise what *is*, not what *was* (git carries history). Don't link to docs that don't exist yet.

## Smell test

Per new paragraph, finish: *"this exists because a future reader won't know that…"*. Can't? Delete. Then grep the diff for `Run \d+`, `audit #`, `PROJ-\d+`, `[x]`, mid-list "done" summaries: every hit is citation rot or a stale checklist.
