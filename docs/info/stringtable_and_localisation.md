# Stringtable and localisation

All player-facing text lives in `src/stringtable.xml`, grouped into `<Container>` blocks by
subsystem. Keys are `STR_DUWS_T_*` (a handful of newer ones use a bare `STR_DUWS_*` prefix);
lookups are case-insensitive, so a `localize` that differs in case from the `Key ID` still
resolves.

## English is the source of truth

Every key carries both `<Original>` and `<English>`, and Arma falls back to `<Original>` when
the active language has no tag. **Edit the two in lockstep** — changing only `<English>` leaves
the old wording live for anyone whose game language isn't listed on that key.

## The localised tags lag English on purpose

The `<German>`, `<Spanish>` and `<Chinesesimp>` tags were translated from the pre-rework text and
have not been carried forward through the English prose passes. They still contain the retired
callsigns (`Action Squad`, `Overlord 1-1`), the old unnamed-department phrasing for Allseer, and
pre-rework mission briefings whose stated timings and reward tags no longer match the English.

This is known divergence, not corruption: **do not treat a German/Spanish/Chinese tag that
disagrees with `<English>` as a bug, and do not machine-translate the gap closed.** Retranslation
is a deliberate pass of its own, because the briefings encode gameplay numbers a translator has to
check against the mission code rather than against the old text.

## Player callsign substitution

The squad callsign is host-settable (`duws_callsign`, default `Alpha 1-1`). `fnc_cs` rewrites the
literal string `Alpha 1-1` at display time, so **any key whose text contains `Alpha 1-1` must be
localised through `([localize "STR_..."] call fnc_cs)`** — a bare `localize` prints the default
callsign no matter what the host chose. Fixed callsigns (`Overlord`, `Allseer`, `Dispatch`) are
never wrapped.

Substitution matches the English literal only, which is a second reason the localised tags cannot
simply be aligned key-for-key.

## Register

The reference for radio prose is the `Support & Radio` container: speaker-first callsign framing
(`Alpha 1-1, this is Overlord.` / `Swordfish 1-1 to Alpha 1-1, ...`), procedure words (*be advised,
roger, stand by, over, out*), numbers spelled out in spoken lines but numerals in HUD text, and
flat declaratives — Overlord does not shout. Hints carry no trailing period; subtitles do.
Mission briefings end with a parenthesised reward tag, `(High CP, average AP)`.

## Unreferenced keys

A key can be deleted only once nothing references it. No call site builds a key name dynamically
(no `format ["STR_DUWS_T_%1", ...]`), so a plain text scan over `src/` is authoritative for
liveness — which is what makes bulk pruning safe to reason about.
