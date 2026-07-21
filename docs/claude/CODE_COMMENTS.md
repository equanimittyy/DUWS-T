# Code Comment Style

Lean and substance-only. Comments cost reading time and rot independently of code. Sister file: [`DOCUMENTATION.md`](DOCUMENTATION.md) (prose docs, same philosophy).

## Core rule

**Explain WHY, never WHAT.** Code shows what it does. Comment only what code can't:

- Load-bearing constraint or invariant
- Why a "simpler" alternative was rejected
- Security / operational rationale (fail-closed, defence-in-depth, blast-radius)
- Cross-system contract (join key, calibration boundary, schema lockstep)
- Concurrency contract (cache lifetime, sync-vs-async ordering)
- Convention not inferable from one file
- Non-obvious encoding (what a magic value or tier means)
- Bug workaround: **describe the failure mode**, never cite a ticket/issue/audit/run ID

## Drop

Comments restating code carry no information; delete them:

- **Field-restating JSDoc**: `/** Unique ID for this record */ id: string;`
- **Comments restating the next line**: `// Look up the user` above `getUser(...)`
- **Restated function pipelines**: a 6-step `Flow:` block listing what the code already reads top-to-bottom. (One tight line of non-obvious decisions is fine.)
- **Trivial docstrings**: `/** Get config. Throws if not initialized. */` when the return type and error message already say so.
- **Section banners / step breadcrumbs**: `// --- Validation ---`, `// --- 1. Fetch context ---`, `// Helper`, `// Public API`. Functions are grouped by file; decomposition beats dividers. Reserve `// ---` for genuine architectural sections spanning 50+ lines where the boundary aids navigation.

## Keep

Each carries a fact the code can't show. Short examples:

```ts
/** SECURITY: untrusted user input; parameterized queries only. */
/** SECURITY: server-internal only. MUST NOT reach clients unfiltered:
 *  exposes co-located session data. */

// Fail-closed: a truncated/refused validator cannot silently accept.
// Caller treats throws and {accept:false} identically.

/** Concurrency contract: the batch runs items in parallel via a worker pool.
 *  Getters MUST return independent copies; mutations MUST be scoped to the
 *  acting item; per-item DB txns run READ COMMITTED. */

/** Integer tier, not a raw count. 0 = default, 1/2+ escalate, -1 = suppressed.
 *  Real magnitudes live elsewhere. */    // non-obvious encoding

/** floor(timestamp / TIME_BUCKET_MS), stamped at entry. Lets cross-instance
 *  forensic queries group by exact ID, not timestamp ranges. */  // cross-system

/** Bounded |delta| via MAX_DELTA: blocks a hostile model `+9999`. */

/** Convention: common nouns lowercase, proper nouns capitalised.
 *  First-char case determines treatment. */

// reserve is sync (no await) -> event loop serialises concurrent callers.  // why-not-simpler
// JSON.stringify (not delimiter-join) so IDs containing `|`/`,` can't alias keys.
```

Bug rationale (describe the failure mode, no citation):

```ts
// BAD:  Fail-closed on regex throw: see audit Run 21 Auth #7.  (citation rots)
// GOOD: Fail-closed on regex throw: malformed surrogates would otherwise crash
//       the whole batch.
```

## Rules

- **One fact -> one-line `//`.** `/** */` block only for 3+ related facts.
- **Inline comment runs <= 4 lines.** Past that, cut words without cutting facts, or split the code so the comment shrinks. Concise is the constraint; substance is non-negotiable.
- **No tracking IDs anywhere**: no ticket/audit/run/finding/PR refs, and no issue/project numbers (`#1234`, `GH-1234`), in comments or TODOs. The link rots when things are renamed, and a bare number gives a code reader zero context: describe the constraint, not where it was logged. `// TODO: enforce per-user rate limits before the outbound call` is fine. The PR description is the place for ticket links.
- **No** commented-out code (git has it), author names, dates, or changelogs.
- **No emojis.** Keep shipped examples ~80 chars.
- A docstring over ~10 lines means the function needs splitting, or a design-doc link replaces most of it.

## Smell test

Per new comment, finish: *"this exists because a future reader won't know that…"*. Can't? Delete. Comment-to-code ratio >~30% in non-spec files is a smell. Section dividers without 30+ lines under them are noise.
