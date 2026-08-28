# Architecture review

A point-in-time assessment of `src/duws/`, complementary to [`architecture.md`](../architecture.md)
(the orientation map) and [`KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md) (the live defect queue). This
doc is the high-level "how healthy is the design" view: what holds, what is fragile, and where to spend
effort. It is not a bug list — concrete defects belong in the issue queue.

## Core pattern

The mission is built from four load-bearing decisions, all inherited-and-extended rather than chosen
fresh:

- **A flat global namespace is the database.** ~940 distinct globals carry all state; there is no struct
  for a zone, faction, or mission — each is a cloud of `missionNamespace` keys plus a few hashmaps.
  Nothing separates campaign state from scratch variables.
- **The function library is a hand-maintained registry.** `server_fnc_init.sqf` compiles ~350 `fnc_*`
  into globals and hand-`publicVariable`s ~250 of them for clients (337 broadcast entries in total). SQF
  has no compiler, so a function added to the registry but not broadcast is `nil` on remote clients with
  nothing to catch it.
- **Authority is server-side, over a `remoteExec` spine.** Money, CP, and AP all funnel through a single
  server writer with adjacent test-and-debit, which is what makes the economy co-op-safe.
- **Presence is streamed, not simulated map-wide.** One poller distance-gates every "site" and stows its
  AI when no player is near — the mechanism that makes a whole-Altis persistent war affordable.

Where the design is strongest, a **config table fronts the complexity**: the faction schema
(`shared/functions/fnc_faction_schema.sqf`), the side-mission registry (`shared/includes/mission_types.hpp`),
and the support catalogue each single-source their domain so one edit moves every consumer.

## Strengths

These are genuinely well-built and worth protecting from regression:

- The **garrison attrition model** (`server/misc/fnc_garrison_strength_init.sqf`) tracks lost whole
  tokens as a multiset, not a scalar; capture test, map readout, and refill all read the same numbers.
- **Structured, levelled logging** (`fnc_log`) is used almost everywhere over raw `diag_log`.
- **Modern code is defensive**: reads overwhelmingly use `getVariable [name, default]`, so a stale
  broadcast degrades one row rather than killing a menu.
- The project is **unusually self-aware**: the architecture map, the test/lint harness with baselines,
  and the plans directory already name most of the structural problems below.

## The central weakness

One pattern recurs in every subsystem: **a good abstraction is only half-adopted, and the invariant that
keeps the two halves safe is enforced by comment and discipline, not by code.**

| Abstraction | Adopted | Still legacy |
|---|---|---|
| Mission lifecycle spine (`fnc_mission_run`) | 8 of 19 threads | 11 re-inline the lifecycle |
| Token spawner vs direct `BIS_fnc_spawnGroup` | intended default | most threads still direct |
| Zone liveness (lost-token ledger) | zones and towns | hardpoints on a separate snapshot |
| `DUWS_` global / function prefix | partial | ~549 bare `fnc_`, hundreds of bare globals |

Alongside the half-migrations sit several **campaign-wide invariants with no assertion behind them**: the
single-live-mission rule (mission reward globals are not bound to their mission), the poller's
"never do real work inline" contract, the lock-free reserve refill's single-writer assumption, the
tier-monotonic spawn rows, and the "every teardown path must clear the garrison-live flag" contract. Each
is one careless edit away from a silent, hard-to-trace break, precisely because SQF cannot fail the build.

This is the thing to fix culturally: **finish one migration fully before starting the next, and put a
cheap runtime assertion behind each load-bearing invariant** — a loud log on a tier-monotonic violation,
a poller pass-time ceiling, a garrison-flag audit. Runtime checks are the only guardrail a compiler-less
language offers.

## Risks worth verifying

A short list of the highest-consequence findings surfaced during the review. These are inferred from
reading the code and should be confirmed in-game before acting, most urgently the first two.

- **Money spend may not debit item-slot cash for non-host players.** `fnc_money_spend`
  (`server/misc/fnc_economy_init.sqf`) runs server-side but removes money with a local-effect command on
  a unit that is not local to the server for a joined client. Single-player and listen-host are unaffected.
- **Escalation may not function on a dedicated server.** Its counter hangs off a *local* building-damage
  event but the handler is server-only (`server/misc/fnc_escalation.sqf`), so client-caused damage may
  never reach it. The same handler is also unthrottled and does per-event config lookups.
- **Two economy gates trust the client.** The support tier gate is checked client-side only (the server
  validates balance but not tier), and the captured-gear pool settles from a client-supplied loadout it
  never corroborates.
- **The OPFOR faction auto-detect still uses the name-fragment matching** that the BLUFOR side was
  refactored away from and documents as buggy; it is currently masked by a redundant re-broadcast.

## Direction

The flat-namespace, manual-registry foundation is the root fragility, but a sweeping rename is the single
highest-risk change available here (broadcasts are matched as strings, with no compiler to catch a miss).
The tractable path is containment, not a rewrite:

1. Fix the verified correctness issues above first — they cost a player or an exploiter real state.
2. Pay down debt **one subsystem at a time**; it is concentrated in identifiable pockets
   (`client/operative/`, the GUI-editor `.hpp`, the faction-detection globals, the per-faction request
   catalogues), not spread evenly.
3. `DUWS_`-prefix on touch, and box per-zone state behind its key accessor so teardown is one function
   rather than a scattered audit.
4. Lean on lint: a check that flags a registry function added without a matching broadcast would catch
   the most common silent-failure class statically.
