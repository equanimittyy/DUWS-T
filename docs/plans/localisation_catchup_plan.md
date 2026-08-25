# Localisation Catch-up Plan

High-level plan to re-translate the mission's player-facing strings from the
current English source into every supported language. English is the default hub
language and the single source of truth.

## Goal

Every non-English translation currently in `src/stringtable.xml` is stale: it was
written against older English copy and has drifted. Rather than patch gaps, we
**re-translate every line** for each target language, straight from today's
English source, in one coordinated pass.

## Non-goals (hard constraints)

- **Never modify `<Original>` or `<English>`.** They are the source of truth. Every
  agent is read-only on these two tags. No rewording, no punctuation "fixes", no
  reordering that disturbs them. A diff that touches an English or Original line is
  a failed run.
- **Do not add or remove `<Key>` entries.** Key IDs and the set of keys are owned by
  the code, not by this effort. Translation only fills the language child tags.
- No new features, no schema changes, no refactor of the stringtable structure.

## Current coverage

1245 keys total, across 24 containers. Snapshot at time of writing:

| Arma tag | Language | Keys present | State |
|---|---|---|---|
| `<Original>` / `<English>` | English (source) | 1245 | Frozen — never edited |
| `<German>` | German | 700 | Stale — redo all |
| `<Spanish>` | Spanish | 699 | Stale — redo all |
| `<Chinesesimp>` | Chinese (Simplified) | 819 | Stale — redo all |
| `<Chinese>` | Chinese (Traditional) | 22 | Stale — redo all |
| `<Polish>` | Polish | 0 | New |
| `<Czech>` | Czech | 0 | New |
| `<Russian>` | Russian | 0 | New |
| `<French>` | French | 0 | New |

"Keys present" is only the starting count; the plan overwrites/creates the full
1245 for every target language regardless.

## Target languages

Nine total: English (source, untouched) plus eight translation targets. Arma's
stringtable uses a fixed set of language child-tag names; the mapping below is the
authoritative tag to write.

| Target | Arma tag | Why in scope |
|---|---|---|
| German | `<German>` | Large, organised milsim scene; already partially present |
| Polish | `<Polish>` | One of the most active national communities |
| Czech (incl. Slovak) | `<Czech>` | Home market — Bohemia Interactive is Czech |
| Russian | `<Russian>` | Sizeable modding / milsim presence |
| French | `<French>` | Active tactical community |
| Chinese (Simplified) | `<Chinesesimp>` | Player base large enough that BI shipped official CN |
| Chinese (Traditional) | `<Chinese>` | Ships alongside Simplified for the same reason |
| Spanish | `<Spanish>` | Already supported; keep parity rather than regress |

Note on Slovak: Arma 3's standard stringtable has no dedicated Slovak tag, and
Czech/Slovak are highly mutually intelligible, so the Czech tag serves both
markets. Decided — no separate Slovak tag.

## Do-not-translate list

Some strings must stay verbatim even in a translated tag. For these keys, copy the
English text into the language tag unchanged (or omit the tag so `<Original>`
falls back) — do not localise:

- **Callsigns** (the `Callsigns` container, and Alpha 1-1 / Overlord / Allseer-style
  handles wherever they appear). Convention: callsigns read in English on purpose.
- **Faction proper nouns and speaker labels** (e.g. OPFOR/BLUFOR tags, faction
  names). Faction detection is unreliable; leave these hardcoded and untranslated.
- **Class names, format specifiers, and `%1`/`%2` placeholders.** Placeholders must
  survive translation in the same count and order as the English source.

The per-language agent brief must call these out explicitly so translators skip
them rather than guessing.

## Workflow structure

Editing one 1245-key XML file with eight agents in parallel would clobber. Instead,
fan out on disjoint data and merge once:

1. **Export (main thread, one pass).** Generate a translation input list from the
   current stringtable: for every translatable key, emit `key ID + container name +
   English source text`. Container name gives tone/context (e.g. terse map marker
   vs. full manual prose). This export is the single shared input.
2. **Translate (one agent per language, Sonnet).** Eight agents, each owning exactly
   one language tag, each producing a full `ID -> translated text` mapping for all
   translatable keys. Agents run on Sonnet to keep token cost down; they never see
   or touch the XML directly, only the export list, so they cannot disturb English.
   Batch by container (24 groups) to keep each agent's context small and make runs
   resumable if one language fails midway.
3. **Merge (main thread, one pass).** Fold the eight mappings back into
   `src/stringtable.xml`: for each key, keep `<Original>` and `<English>` exactly,
   replace every other language child with the fresh translation. Serialised single
   writer — no concurrent edits to the file.
4. **Validate.** See checklist below.

Rationale for the fragment-and-merge shape over per-agent worktrees: every agent
would otherwise edit the same lines of the same file, producing unmergeable
conflicts. Separating "produce translations" (parallel, per-language) from "write
XML" (serial, one writer) removes the conflict entirely and keeps English provably
untouched.

## Files touched

- `src/stringtable.xml` — the only file edited. All translation tags land here.
- This plan doc — reference only; not shipped.

Do not create per-language stringtable files or split the table; Arma expects the
single `stringtable.xml`.

## Consistency and style

- **Punctuation and register follow the existing player-text conventions** already
  used across the mission (terminal periods on hints/dialogue/descriptions, none on
  cards/markers; terse, action-first phrasing). Translations match the English
  line's register, not a more formal one.
- **Build a small shared glossary first** — recurring domain terms (zone, FOB, HQ,
  support, garrison, side mission, reputation) with one agreed translation per
  language — and hand it to every agent so the same concept is not rendered three
  different ways across containers.
- **Encoding: UTF-8 throughout** (the file is already `encoding="utf-8"`). XML
  special characters stay escaped (`&amp;`, `&lt;`, `&gt;`, `&quot;`). CJK text is
  fine inline under UTF-8.

## Validation checklist

Run after merge, before commit:

- `git diff` shows **zero** changes to any `<Original>` or `<English>` line.
- Per-language tag count equals the translatable-key count (full coverage, no
  silent drops).
- No `<Key>` added or removed; key ID set identical to pre-run.
- XML is well-formed and parses.
- Placeholder audit: `%1`/`%2`/… count and order per key match the English source.
- Spot-check the do-not-translate keys stayed verbatim.

## Scope: everything, including long-form prose

Full scope — no container deferred. The long-form prose keys (the `Manual, Help &
Credits` container, journal/briefing entries, side-mission narrative text) are the
bulk of the token cost but are explicitly **in scope** for full translation in this
pass. Each language must ship complete; a partially-translated manual reads worse
than none. Budget the Sonnet agents accordingly — these prose containers dominate
the per-language token count, so batch them separately from the short UI strings.

## Open questions

- Confirm the exact Arma-supported tag names against the packed game before the run.
