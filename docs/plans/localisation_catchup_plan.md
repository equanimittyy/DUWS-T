# Localisation Catch-up Plan

High-level plan to re-translate the mission's player-facing strings from the
current English source into every supported language. English is the default hub
language and the single source of truth.

## Goal

The German, Spanish and Traditional Chinese translations in `src/stringtable.xml`
are stale: they were written against older English copy and have drifted. Rather
than patch gaps, we **re-translate every line** for each target language, straight
from today's English source, one language per pass. Simplified Chinese has had its
pass.

## Non-goals (hard constraints)

- **Never modify `<Original>` or `<English>`.** They are the source of truth. Every
  agent is read-only on these two tags. No rewording, no punctuation "fixes", no
  reordering that disturbs them. A diff that touches an English or Original line is
  a failed run.
- **Do not add or remove `<Key>` entries.** Key IDs and the set of keys are owned by
  the code, not by this effort. Translation only fills the language child tags.
- No new features, no schema changes, no refactor of the stringtable structure.

## Current coverage

1666 keys total, across 26 containers. 49 of them stay English in every language
(see [Do-not-translate list](#do-not-translate-list)), so a complete language has
1617 tags.

| Arma tag | Language | Keys present | State |
|---|---|---|---|
| `<Original>` / `<English>` | English (source) | 1666 | Frozen — never edited |
| `<German>` | German | 607 | Stale — redo all |
| `<Spanish>` | Spanish | 606 | Stale — redo all |
| `<Chinesesimp>` | Chinese (Simplified) | 1617 | Done — matches the current English |
| `<Chinese>` | Chinese (Traditional) | 17 | Stale — redo all |
| `<Polish>` | Polish | 0 | New |
| `<Czech>` | Czech | 0 | New |
| `<Russian>` | Russian | 0 | New |
| `<French>` | French | 0 | New |

"Keys present" is only the starting count; a pass overwrites or creates the tag on
every translatable key regardless.

## Target languages

Nine total: English (source, untouched) plus eight translation targets. Arma's
stringtable uses a fixed set of language child-tag names; the mapping below is the
authoritative tag to write. Confirm each remaining tag name against the packed game
before its pass.

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

Some text must stay verbatim even in a translated tag:

- **Callsigns** (the `Callsigns` container, and Alpha 1-1 / Overlord / Allseer-style
  handles wherever they appear). Callsigns read in English on purpose, and two code
  paths depend on it: `fnc_cs` replaces only the literal `Alpha 1-1`, and the
  dialogue speaker tables compare localised callsigns.
- **Faction proper nouns and speaker labels** (e.g. OPFOR/BLUFOR tags, faction
  names). Faction detection is unreliable; leave these hardcoded and untranslated.
- **Class names, markup and placeholders.** Keep `<br/>`, `<t>` tags, a literal `\n`
  and real line breaks where the English has them. Keep every `%1`/`%2` placeholder;
  the order can change for word order, because `format` substitutes by index.

A key whose whole text stays English (a callsign, a bare number, a BLUFOR/OPFOR
label) gets no language tag, so `<Original>` falls back and later English edits flow
through. A translation that comes back identical to the English is dropped the same
way.

The per-language agent brief must call these out explicitly so translators skip
them rather than guessing.

## Workflow structure

Editing one 1666-key XML file with several agents in parallel would clobber.
Instead, fan out on disjoint data and merge once. Each language is one pass:

1. **Export (main thread).** For every translatable key, emit `key ID + container
   name + English source text`, unescaped. Container name gives tone/context (e.g.
   terse map marker vs. full manual prose). Also keep every key's English as a
   baseline for the merge.
2. **Glossary (one Sonnet agent).** It reads the whole export and the player-text
   style guide and writes the language's glossary: recurring mechanic nouns, support
   names, radio procedure words, UI verbs, and a keep-or-translate decision for each
   acronym. The main thread reviews it before fan-out. Common words are marked so
   the checker does not flag them in other senses.
3. **Translate (four Sonnet agents).** Split the containers into four groups of
   about 20,000 English characters each; the `Manual, Help & Credits` container
   alone is about 17,000. Each agent gets the shared brief (voice, hard rules,
   output format), the glossary and its group. It never sees the XML, writes a
   `ID -> translated text` JSON mapping in parts, and runs the checker until it
   reports 0 errors.
4. **Merge (main thread, single writer).** Fold the mapping into
   `src/stringtable.xml`: replace the language tag in place, or insert it after
   `<English>`. Skip a key whose English changed after the export, and translate it
   at the end against the new English.
5. **Validate.** See checklist below.

Rationale for the fragment-and-merge shape over per-agent worktrees: every agent
would otherwise edit the same lines of the same file, producing unmergeable
conflicts. Separating "produce translations" (parallel, per-group) from "write XML"
(serial, one writer) removes the conflict entirely and keeps English provably
untouched.

## Files touched

- `src/stringtable.xml` — all translation tags land here.
- `docs/info/gameplay/player_text_style_guide.md` — which tags lag English, and each
  finished language's punctuation, spacing and term conventions.
- This plan doc — reference only; not shipped.

Do not create per-language stringtable files or split the table; Arma expects the
single `stringtable.xml`.

## Consistency and style

- **Punctuation and register follow the existing player-text conventions** already
  used across the mission (terminal periods on hints/dialogue/descriptions, none on
  cards/markers; terse, action-first phrasing). Translations match the English
  line's register, not a more formal one.
- **One glossary per language, built first** (workflow step 2), so the same concept
  is not rendered three different ways across containers.
- **Encoding: UTF-8 throughout** (the file is already `encoding="utf-8"`). XML
  special characters stay escaped (`&amp;`, `&lt;`, `&gt;`). CJK text is fine inline
  under UTF-8.

## Validation checklist

Each agent runs the per-key checker before it finishes:

- Placeholder, markup-tag, literal `\n` and line-break counts match the English.
- Every callsign and BLUFOR/OPFOR/INDFOR token appears as often as in the English.
- `!` only where the English has one.
- The final period mirrors the English (`.` and `...` map to the language's own
  marks), except abbreviations such as the tier labels `Inf.` and `Mot.`.

Run after merge, before commit:

- `git diff` shows **zero** changes to any `<Original>` or `<English>` line.
- Per-language tag count equals the translatable-key count (full coverage, no
  silent drops).
- No `<Key>` added or removed; key ID set identical to pre-run.
- XML is well-formed and parses.
- Placeholder audit: `%1`/`%2`/… count per key matches the English source.
- Spot-check the do-not-translate keys stayed verbatim.

## Scope: everything, including long-form prose

Full scope — no container deferred. The long-form prose keys (the `Manual, Help &
Credits` container, journal/briefing entries, side-mission narrative text) are the
bulk of the token cost but are explicitly **in scope** for full translation in each
pass. Each language must ship complete; a partially-translated manual reads worse
than none. The Simplified Chinese pass used about 620,000 Sonnet tokens across its
five agents.
