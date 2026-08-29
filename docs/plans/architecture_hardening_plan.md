# Plan: harden the invariants and finish the half-migrations

Turns the point-in-time architecture assessment into ordered, shippable work. The companion map is
[`architecture.md`](../info/architecture/architecture.md); live defects live in
[`KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md). This plan owns the *structural* hardening only.

## Goal

The review found the design healthy in the large and fragile in one specific way: good abstractions
are half-adopted, and the invariants that keep the two halves safe are held by comment and discipline,
not by code. SQF has no compiler, so a violation cannot fail a build — each is one careless edit from a
silent, hard-to-trace break. The tractable response is containment, not a rewrite: verify the
correctness risks, put a cheap runtime assertion behind each load-bearing invariant, then finish the
half-migrations one subsystem at a time. A sweeping `DUWS_` rename is the single highest-risk change
available here — broadcasts are matched as strings with nothing to catch a miss — and is explicitly out
of scope.

**Read the tree, not just the review, before acting.** The assessment predates a burst of hardening
work, and much of what it flags as open is already addressed on disk. Where a phase below is confirmed
done, the task is play-test verification, not a re-fix.

## Baseline — what holds, and must not churn

Four load-bearing decisions are inherited and sound; protect them from incidental regression rather
than revisiting them:

- The flat `missionNamespace` global store is the database. It is the root fragility but not a
  rewrite target — see [Direction](#out-of-scope).
- `server_fnc_init.sqf` is a hand-maintained function registry that compiles and `publicVariable`s the
  library. A registry entry added without a matching broadcast is `nil` on remote clients with nothing
  to catch it — the single most common silent-failure class, addressed in [Phase 4](#phase-4).
- Authority is server-side over a `remoteExec` spine; money, CP, and AP funnel through one writer.
- Presence is streamed by one distance-gating poller (`server/misc/fnc_site_stream_init.sqf`), not
  simulated map-wide.

Genuinely well-built, worth guarding: the garrison attrition multiset
(`server/misc/fnc_garrison_strength_init.sqf`), structured levelled logging (`fnc_log` over raw
`diag_log`), and the config tables that front the complexity (the faction schema, the side-mission
registry `shared/includes/mission_types.hpp`, the support catalogue).

## Phase 1 — verify the correctness risks

The review's four risks were inferred from reading and must be confirmed in-game. A re-read of the tree
shows three already carry a fix; only the fourth still needs code.

- **`fnc_money_spend` non-local item-slot debit — patched, verify.** The removal now splits on locality
  (`server/misc/fnc_economy_init.sqf:246-247`): `removeItem` when the unit is server-local, otherwise
  `remoteExec ["removeItem", _unit]` at the unit's owner. Verify on a dedicated server / joined client
  that buying from the physical cash roll actually debits the client.
- **Escalation on a dedicated server — refactored, verify.** The counter no longer hangs off a
  server-only handler on a client-local damage event; each machine watches its own damage
  (`fnc_escalation_watch`) and forwards to the server (`fnc_escalation_report`) with a JIP-broadcast
  install (`server/misc/fnc_escalation.sqf:81-127`). Verify client-caused building damage raises
  `escalation_multiplier` on a dedicated host.
- **OPFOR faction auto-detect name-fragment matching — refactored, verify.** OPFOR now publishes from
  the schema key list, not name-fragment matching, mirroring the BLUFOR side
  (`shared/factions/MODERN/AUTODETECT_opfor.sqf`, tail). Verify a faction with a role spelled
  off-pattern still fields that role OPFOR-side, and confirm no name-fragment path survives in
  `fn_factionAutoDetect.sqf`.
- **Two economy gates trust the client — still open.** The support-tier gate is validated client-side
  only (the server checks balance but not tier), and the captured-gear pool settles from a
  client-supplied loadout it never corroborates. This is the one risk with no fix in the tree. Confirm
  exploitability, then move both checks server-side. Belongs to the economy domain — see
  [`economy_second_pass.md`](./economy_second_pass.md) if the fix grows past a gate.

## Phase 2 — an assertion behind each unasserted invariant

Each load-bearing invariant gets one cheap, loud runtime check — a `WARN`/`ERROR` `fnc_log` line on
violation, not a behaviour change. Runtime checks are the only guardrail a compiler-less language
offers. Two are already done and set the pattern to copy.

Done (reference implementations, `feat(server): guard poller pass-time and double-mission starts`):

- **Poller "never real work inline."** A `WARN` when a site pass exceeds a 15 ms ceiling, at the
  default log level unlike the DEBUG heartbeat (`server/misc/fnc_site_stream_init.sqf`).
- **Single-live-mission.** An `ERROR` when a mission begins while one is already live, because reward
  globals are not bound to their mission and a second start clobbers the first's payout
  (`server/missions/fnc_mission_begin.sqf`).

Still to assert:

- **Lock-free reserve refill single-writer.** The refill assumes exactly one writer
  (`server/init_zones/fnc_garrison_reserve.sqf`). Assert the writer identity, or log if a second path
  writes the reserve within a pass.
- **Tier-monotonic spawn rows.** No tier may field fewer of anything than the tier below it
  (`server/init_zones/fnc_zone_spawn_sizes.sqf`). A loud log on a monotonicity violation at table build
  time catches an edit that breaks the ladder — see the tier-monotonic invariant note.
- **Garrison-live flag cleared on every teardown.** Every teardown path must clear the flag; a leak
  strands a zone as permanently garrisoned. Audit the teardown paths against
  `server/misc/fnc_garrison_strength_init.sqf` and log a flag still set after teardown.

## Phase 3 — finish one migration at a time

The recurring fault is half-adoption; the discipline is to finish one fully before starting the next,
never to open a fifth. Debt is concentrated in identifiable pockets — `client/operative/`, the
GUI-editor `.hpp`, the faction-detection globals, the per-faction request catalogues — not spread
evenly, so it pays down by pocket.

| Migration | State | Action |
|---|---|---|
| Mission lifecycle spine | 8 of 19 threads on the spine | Owned by [`mission_spine_unification_plan.md`](./mission_spine_unification_plan.md); not re-scoped here. |
| Token spawner vs direct `BIS_fnc_spawnGroup` | Token API is the intended default; most threads still call direct | Migrate remaining direct callers to the token spawner (`fnc_spawn_team` / `fnc_spawn_vehicle`). |
| Zone liveness (lost-token ledger) | Zones and towns on the ledger; hardpoints on a separate snapshot | Bring hardpoints onto the lost-token ledger so one model answers liveness everywhere. |
| `DUWS_` prefix on globals / functions | ~549 bare `fnc_`, hundreds of bare globals | Prefix-on-touch only. No sweeping rename — see [out of scope](#out-of-scope). |

## Phase 4 — the static lint guard

Add a lint check that flags a function added to the `server_fnc_init.sqf` registry without a matching
`publicVariable` broadcast. This catches the most common silent-failure class *statically* — the one
guarantee a compiler-less language can buy back cheaply — and generalises the discipline behind
[the registry baseline](#baseline--what-holds-and-must-not-churn).

## Out of scope

The flat-namespace, manual-registry foundation is the root fragility, but a mass `DUWS_`-prefix rename
is the highest-risk change available: broadcasts are matched as strings with no compiler to catch a
missed rename, so a partial sweep silently breaks remote clients. Prefix on touch; never sweep.

## Decisions (settled)

1. **Containment, not rewrite.** The tractable path is verify → assert → finish migrations, not a
   namespace or registry rebuild.
2. **Verify before fixing.** Three of the four review risks are already patched on disk and two of the
   invariants already asserted; the plan confirms in-game rather than re-fixing.
3. **Runtime assertions are the guardrail.** SQF cannot fail a build, so each load-bearing invariant
   gets a loud log on violation — cheap, and the only check the language affords.
4. **One migration finished before the next.** The recurring fault is half-adoption; do not open a
   fifth half-migration to chase the first four.
5. **The mission-spine migration stays in its own plan** and is referenced, not duplicated.

## Task list

- [ ] Phase 1: play-test-confirm the three patched risks (money debit, dedicated escalation, OPFOR
      off-pattern role); scope and fix the two client-trusting economy gates server-side.
- [ ] Phase 2: assert the three still-open invariants (reserve single-writer, tier-monotonic rows,
      garrison-live flag on teardown), copying the poller/mission-begin pattern.
- [ ] Phase 3: finish the token-spawner migration; bring hardpoints onto the lost-token ledger;
      `DUWS_`-prefix on touch only.
- [ ] Phase 4: add the missing-broadcast lint check to the harness.
