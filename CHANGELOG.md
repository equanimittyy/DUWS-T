# Changelog

What has changed in this repo and why, at the level of features and architectural
decisions. Inherited DUWS / DUWS_X behaviour is not covered — see
[`README.md`](README.md) for the fork lineage and
[`docs/info/architecture.md`](docs/info/architecture.md) for how the mission is put together.

Newest first. This is deliberately not exhaustive; `git log` is.

## Support transports

The three transports — helo taxi, boat taxi, heli-lift — had drifted into three different
shapes. They now share one.

- **The heli-lift aircraft is server-owned.** It used to be created by the calling client,
  which then asked the server to give it waypoints. Group commands are only honoured where
  the group is local, so this worked for a hosting player and silently did nothing for
  anyone else — the feature had been disabled for non-host players rather than fixed.
- **One failure handler per transport.** Nine and six copies of the abort block collapsed
  to one each. The copies had drifted: one boat branch had lost its marker cleanup and
  stranded a drop point on the map, and three had kept a `deleteVehicle` for a helipad the
  boat never creates.
- **One cooldown scheme** — 10 s on a rejected request, 120 s after a completed run, 300 s
  when the aircraft is destroyed, so losing an asset costs more than using one. Every timer
  is spoken; the lift previously had no pause at all on its error paths.
- **Fixed callsigns.** Transports rolled a random name and two random digits per call.
  Each support now answers as a fixed element lead (Chariot 1-1, Swordfish 1-1, Mule 1-1,
  Courier 1-1/2-1/3-1, Ranger 1-1, Slingshot 1-1, Longbow 1-1, Koi 1-1, Allseer 1-1).

## Source layout by execution locality

`duws/` was reorganised from topical folders into `server/`, `client/` and `shared/`, so a
file's execution locality is readable from its path. Every `.sqf` outside `factions/`
carries a `// Locality:` header naming the evidence.

A folder states where a file's *own top-level body* runs — not where its callbacks run, and
not where its code is broadcast. `shared/` is therefore narrow. Rationale and the placement
rule: [`docs/info/server_client_authority.md`](docs/info/server_client_authority.md).

## Runtime logging

Arma reports nothing when a script simply stops, which cost two playtests chasing a stall.

- `fnc_log` gives every line a `[DUWS][level][machine][tag]` shape; the machine field
  separates a host's server and client halves, which share one `.rpt`.
- `fnc_waitLogged` wraps a `waitUntil` with a label and timeout, warning every 10 s naming
  the condition it is blocked on. An unbounded wait can no longer stall in silence.
- The function registry self-checks after compiling: an unresolved path makes
  `preprocessFile` return `""`, which compiles to an empty `{}` and then no-ops at every
  call site with no error anywhere.

How to read the output: [`docs/info/testing.md`](docs/info/testing.md#runtime-logging-reading-the-rpt).

## Command-point economy

- **The server decides a purchase, not the buyer.** A client testing its own copy of a pool
  is a network round trip out of date, so two clients each seeing 10 CP both passed a 10 CP
  gate. The test and the debit are now adjacent statements against the one server copy.
- **One server-side writer per pool**, taking signed deltas. A shared global mutated as
  `x = x - c; publicVariable "x"` loses concurrent writes and can create resource from
  nothing.

Faucets, sinks and balance: [`docs/info/cp_economy.md`](docs/info/cp_economy.md).

## Campaign setup

- Squad-callsign screen, threaded through the radio dialogue by substitution at display
  time rather than baked into each string.
- Back navigation through the setup screens, re-picking faction and HQ with nothing yet
  built — faction and HQ init are deferred to a single commit point for this reason.
- Custom-faction paste validates every required key and its class, per side.
- The campaign ends on full capture; Domination mode was dropped.
- Civilian system gained an OFF option.

## HQ and player-facing menus

- HQ and FOB interactions route through one reusable list menu, with primary actions
  pinned, CP costs shown, and live cooldown labels.
- Both disguise modes front a panel menu showing per-mode cooldowns.
- The diary manual is a single subject with a numbered outline.
- `Squad_Leaders` (formerly `Request_Players`) is permission-only, gating FOB refortify
  and reguard.

## Killhouse

Reworked from a timed free-for-all into waves, with integer CP rewards, free enemy
movement, culling for units that fall out of the course, and see-through contact markers
that fade at close range.

## Tooling

- `unpack.cmd` / `repack.cmd` wrap the vendored PBO Manager; `src/` is the source of truth
  and the `.pbo` is build output.
- `duws_eden.ps1` imports Eden compositions by scanning for marker comments.
- `tests/run.sh` gates SQF syntax, static path resolution, and a thin sqf-vm unit layer.
  Details: [`docs/info/testing.md`](docs/info/testing.md).
