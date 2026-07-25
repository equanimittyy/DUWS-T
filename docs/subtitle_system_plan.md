# Subtitle system: replacement plan

Replace `BIS_fnc_showSubtitle` with a wrapper of the same shape and a renderer that stacks
several attributed lines on screen at once. The complaint driving this is behavioural, not
cosmetic: a new line clobbers the previous one the instant it appears, so a player cannot read
a two-line exchange.

The call sites do not change shape. All 276 of them already pass `[speaker, text]` — speaker
first, which is exactly what an attributed renderer needs — so the mechanical half of this
change is a name swap.

## Why the current system is replaced

| Problem | Where |
|---|---|
| One line at a time. A second line inside the display window replaces the first with no queue and no stacking | `BIS_fnc_showSubtitle`, 276 sites across `src/duws` |
| Audio and text are already desynchronised. `fnc_broadcastRadioChatter` holds a mutex for the full 4-20 s ambient sample, so a second line inside that window gets no squelch and no chatter while its subtitle still displays and still clobbers | `server/server_fnc_init.sqf:1020-1021,1085` |
| The "replace random talking with a UI sound" change is half-applied: the squelch was added *in front of* the random vanilla `RadioAmbient1..30` sample, not instead of it | `:1024-1028` then `:1068-1074,1081-1083`, duration table `:1031-1062` |
| `DUWS_Radio_End` is defined and never played — the other half of a squelch pair whose middle section was never removed | `shared/includes/sounds.hpp:31-35` |
| Many message bodies introduce their own speaker, because today the name sits in a separate slot. Rendered as `Speaker: line` they read "Overlord: This is Overlord. …" | `STR_DUWS_T_taskforces_launched`, `_taskforces_launchrqst`, `_opfast`, `_ammospotted`, `_stmeajce`, `_77l9izur`, `_0jegiaf4`, `_hf9bhgvb` |
| The six bombing supports share one generic subtitle and put the rest of their dialogue on `globalChat`, which is client-local — other players never see it | `client/supports/fnc_arty.sqf:36`, then `:56,58,127,129` |

## Design

### The wrapper

```sqf
// fnc_duws_subtitle: [_speaker, _text, _side] — third argument optional
```

First two arguments are unchanged, so every existing site works untouched after the name swap.
The third defaults to friendly and is set explicitly only where a line is not friendly:
`server/misc/fnc_disguiseAsEnemy.sqf:127` and `server/misc/fnc_disguiseAsCivilian.sqf:223`. It
drives the speaker-name colour; the body text stays neutral.

The wrapper also takes over the callsign substitution. `fnc_cs`
(`server/server_fnc_init.sqf:197-217`) currently swaps the literal `"Alpha 1-1"` for the host's
chosen callsign, and it is applied by callers at 18 speaker assignments. Applying it inside the
wrapper instead means the substitution keeps working after the self-introductions are stripped
out of the bodies — see below, this is the one place the two halves of the change interlock.

### The renderer

A client-side ring buffer of at most four lines, each with its own expiry, rendered into a new
`RscTitles` class. Four matches the reference material and the screen space available.

The UI ground is clear: `RscTitles` is defined in exactly one place, `description.ext:79-95`,
holding a single class (`DUWST`, the intro splash shown once from
`server/misc/fnc_intro_heli.sqf:145`). `BIS_fnc_rscLayer` appears nowhere in `src/duws`, so no
layer number is claimed and a fresh named layer cannot collide. The only care needed is not
fighting the default title layer during the intro.

`shared/includes/notifications.hpp` is not reusable here — it is a `CfgNotifications` block
driving `BIS_fnc_showNotification`, a separate BI queue with its own rendering.

`CfgRemoteExec` needs no change: `shared/includes/remoteExec.hpp:10` sets `mode = 2` for
Functions and `:44` for Commands, so the whitelist is ignored and a new `fnc_*` can be
`remoteExec`'d immediately.

### Two malformed inputs the renderer must survive

`server/missions/mission_threads/destroy_tower/fnc_destroy_tower_mission.sqf:225` passes
`["", _message1]` — a deliberately unattributed line. The renderer needs a blank-speaker path
that does not emit a dangling `": "`.

`server/supports/fnc_fob_server.sqf:70` passes a **position array** where the speaker belongs,
because the call is built with `format` and interpolates `str(_foundPickupPos)`. That is a
pre-existing bug and this plan does not fix it; the renderer must not crash on a non-string
speaker. Flag it, leave it.

### Audio

Same change, because the two are adjacent at ~170 call sites and the current behaviour
undermines the whole point of stacking lines. Strip the `RadioAmbient` pool and its sleep from
`server/server_fnc_init.sqf:1068-1085`, keep `DUWS_Radio_Start`, and either wire up
`DUWS_Radio_End` or delete it from `shared/includes/sounds.hpp:31-35`. With the long sleep gone,
the `DUWS_radioChatterRunning` mutex no longer suppresses the squelch on closely-spaced lines.

### The stringtable pass

This is the larger half of the work, and it is content rather than code.

Speaker names are already independent keys — 16 of them, `STR_DUWS_T_OVERLORD` through
`STR_DUWS_T_DISGUISE_OPFOR_SPEAKER` — so `Speaker: line` composes at runtime with **zero new
keys**. What has to change is the bodies that introduce themselves.

Scope it to `English` and `Chinesesimp`. Those are the two locales at full or near-full coverage
(1322 and 1232 of 1322 keys); `German` and `Spanish` sit at ~75% and already lag, as the
callsign strings do by design. A body edited in English and left alone in German simply keeps
its old self-introduction, which reads redundantly but is not broken.

Two details that will bite otherwise:

- Stripping `"Alpha 1-1"` out of a body also removes the token `fnc_cs` substitutes on. That is
  why the wrapper takes over the substitution first, and why the two tasks are ordered.
- `client/missions/fnc_stratmap.sqf:12` uses lowercase `STR_DUWS_T_overlord`, which does not
  exist as a key and resolves only because `localize` is case-insensitive. Fix it while in there.

### Bombing supports

`client/supports/fnc_arty.sqf` covers all six bombing types and has exactly one subtitle, at
`:36`. The rest of its dialogue is `player globalChat` at `:56,58,127,129` — client-local, so no
other player in a co-op session hears the fire mission at all. Converting those four to the
wrapper is the same mechanical edit and fixes a real multiplayer gap, so it belongs in this
change rather than a later one.

## Files touched

| File | Change |
|---|---|
| `client/misc/fnc_duws_subtitle.sqf` | New. Wrapper: queue, expiry, callsign substitution, side colour, blank-speaker path. |
| `description.ext:79-95` | New `RscTitles` class beside `DUWST`. |
| `server/server_fnc_init.sqf:197-217` | `fnc_cs` applied inside the wrapper; registry line for the wrapper. |
| `server/server_fnc_init.sqf:1024-1085` | Drop the `RadioAmbient` pool and its sleep; keep the squelch. |
| `shared/includes/sounds.hpp:31-35` | Wire up or delete `DUWS_Radio_End`. |
| 267 `remoteExec` sites | `"BIS_fnc_showSubtitle"` → `"fnc_duws_subtitle"`. |
| 9 `call` sites | Same. |
| `server/init_hq/fnc_BluHQinit.sqf:692`, `server/supports/fnc_fob_server.sqf:70` | Name change inside the quoted trigger statement, not in SQF. |
| `server/misc/fnc_disguiseAsEnemy.sqf:127`, `fnc_disguiseAsCivilian.sqf:223` | Pass the side argument. |
| `client/supports/fnc_arty.sqf:56,58,127,129` | `globalChat` → wrapper. |
| `client/missions/fnc_stratmap.sqf:12` | Fix the lowercase key. |
| `stringtable.xml` | Strip self-introductions from the listed keys, English and Chinesesimp. |

## Task list

- [ ] Write `fnc_duws_subtitle.sqf` and the `RscTitles` class; call it directly from a test line. Verify: four lines fired 1 s apart are all visible at once and expire oldest-first.
- [ ] Move `fnc_cs` into the wrapper. Verify: a host-chosen callsign still appears, with no caller changes.
- [ ] Swap the 276 call sites, including the two inside quoted trigger statements. Verify: `bash tests/run.sh`; grep for `BIS_fnc_showSubtitle` returns nothing under `src/duws`.
- [ ] Add the side argument at the enemy and civilian sites.
- [ ] Strip the `RadioAmbient` pool from `fnc_broadcastRadioChatter`. Verify: two subtitles 2 s apart both get a squelch.
- [ ] Stringtable pass, English and Chinesesimp. Verify: no line renders as "Overlord: This is Overlord".
- [ ] Convert the four `fnc_arty.sqf` `globalChat` calls. Verify: a non-host player hears a fire mission called by the host.
- [ ] In-game: run a side mission with dense dialogue and confirm no line is lost.

## Decided trade-offs

**The wrapper keeps the two-argument signature.** Passing a stringtable *key* instead of a
localised string would let the renderer colour by speaker identity across languages, but it
means editing all 276 sites and every one of the `format`-wrapped cases. A side argument
defaulted to friendly gets the colour distinction that actually matters — us versus them —
for the cost of two edited lines.

**Designed from the requirement, not from Dynamic Civil War.** DCW was cited as a working
reference, but its source is not on this machine and was not inspected. Nothing here is derived
from it; if someone later reads DCW and finds a better queue model, this renderer is one file.

**German and Spanish keep their self-introductions.** They are already at ~75% coverage and
localisation lags English here by convention. The redundant reading is the cost of not blocking
this change on a full translation pass.

**The FOB speaker bug is flagged, not fixed.** `server/supports/fnc_fob_server.sqf:70` renders a
coordinate triple where a speaker name belongs. It is pre-existing, it is in a `format`-built
trigger statement that wants care, and fixing it here would mix an unrelated repair into a
mechanical rename. The renderer tolerates it; the fix is its own change.

**Four lines, not a configurable depth.** A queue depth setting invites a screen full of text and
another knob to test. Change the constant if play says so.
