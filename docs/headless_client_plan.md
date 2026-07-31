# Headless client support: implementation plan

Let a headless client take ownership of the mobile OPFOR groups so their AI runs off the
server. Zone garrisons stay server-owned.

The first step is a bug fix that stands on its own: a headless client currently runs the entire
campaign generator. That is true today, with or without this feature, and it is why connecting
an HC to a DUWS_T server does not merely fail to help — it corrupts the campaign.

## What is broken now

| Problem | Where |
|---|---|
| A headless client runs `server_init.sqf` in full — faction init, HQ build, WARCOM, mission locator, 39 background loops — in parallel with the real server | `INIT.sqf:21`, with `_duwst_isHeadless` defined at `:15` |
| `server_init.sqf` has no early guard. Its `if (!isServer) exitWith {}` is the **last line** of the file, where it does nothing. The two inner `if (isServer)` blocks cover only the kill-income and flare handlers | `server/server_init.sqf:472`, inner guards `:195,281` |
| No ownership transfer exists anywhere. `setGroupOwner` and `setOwner` appear nowhere in `server/`, `client/` or `shared/` | — |
| No HC is declared: no `headlessClients[]` entry, no HC slot among the 20 playable slots | `description.ext`, `mission.sqm` |
| Waypoint commands only take effect where the group is local, and every waypoint call runs server-side | `server/warcom/fnc_WARCOM_wp_*.sqf`, rule in [`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md) |
| `setSkill` needs locality, so HC-owned units would silently never receive skill settings | `server/misc/fnc_AI_Master_Control.sqf:5,22,26` |

The abbreviation is also overloaded, which matters because the file a newcomer will open first
is the wrong one. `client/misc/fnc_hc_init.sqf` is Arma's **High Command** commanding UI —
`:10` creates a `HighCommand` module, `:20` a `HighCommandsubordinate`, `:12` synchronises the
player to it — called from `client/client_init.sqf:218` for squad leaders. The same naming runs
through `server/misc/fnc_HCsquad_spawn.sqf:44` and the `hc_ATTchop` / `hc_CAS` comm-menu items
at `client/dialog/fnc_request_support.sqf:384,416`. None of it is headless-client code.

The only correct HC awareness in the mission is the log machine tag,
`shared/functions/fnc_log_init.sqf:12-15`, which is cosmetic.

## Design

### Stop the HC running the server init

```sqf
if (_duwst_isServer || _duwst_isHostedserver) then { [] execVM "duws\server\server_init.sqf"; };
if (_duwst_isHeadless) then { [] execVM "duws\hc\hc_init.sqf"; };
```

The HC entry path is small by construction: register the machine with the server, then wait. It
must not compile the server function registry or touch generation.

### Declare the HC

`headlessClients[] = {"127.0.0.1"};` in `description.ext`, plus one HC slot in `mission.sqm`
alongside the 20 playable `B_Soldier_SL_F` slots. An HC that never connects must be a no-op:
every handoff falls back to the server.

### Ownership registry

The HC publishes its `clientOwner` to the server on connect; the server keeps it in
`DUWST_hc_owner`, defaulting to `2` (the server itself). One helper:

```sqf
// fnc_hc_handoff: [_group] call fnc_hc_handoff
private _target = missionNamespace getVariable ["DUWST_hc_owner", 2];
if (_target != 2) then { _group setGroupOwner _target; };
```

Called immediately after group creation, never before the group is populated. If the HC
disconnects mid-campaign the server resets `DUWST_hc_owner` to `2`; groups already handed off
revert to the server automatically when their owner drops.

### What gets handed off

Mobile WARCOM groups only:

| Spawner | `path:line` |
|---|---|
| OPFOR assault | `server/warcom/fnc_WARCOM_opf_assault.sqf:98,100,109` |
| OPFOR patrol, air | `server/warcom/fnc_WARCOM_opf_patrol.sqf`, `fnc_WARCOM_opf_air.sqf` |
| Vehicle crews for the above | `server/misc/fnc_random_veh.sqf:105` |

Zone garrisons — `server/init_zones/fnc_createopteam.sqf:23`, `fnc_createopteam2.sqf`,
`fnc_createoppatrol2.sqf`, `fnc_createoppatrol_sniper.sqf`, `fnc_createopwpteam.sqf`,
`fnc_createopfortified.sqf` — stay on the server. See the trade-off below.

### Routing waypoint calls

Waypoint logic is already factored into its own files, which is the seam that makes this
tractable: `fnc_WARCOM_wp_opf_assault.sqf:10,27`, `fnc_WARCOM_wp_opf_patrol.sqf:17`,
`fnc_WARCOM_wp_blu_patrol.sqf:7,17,25`,
`fnc_WARCOM_wp_blu_assault.sqf:29`, plus `fnc_WARCOM_blu_assault.sqf:89,95` and the
`bis_fnc_taskPatrol` call at `server/init_zones/fnc_createopteam.sqf:32`.

Each call becomes `remoteExec [..., groupOwner _grp]` rather than a direct call. Where the group
is server-owned that resolves to the server and behaves exactly as it does today, so the change
is safe before an HC ever connects.

Note that `remoteExec` to your own machine runs a frame later
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md)), so any test-then-act sequence
around a waypoint call must not assume the waypoint exists on the next line.

### Skill assignment

`server/misc/fnc_AI_Master_Control.sqf:22-26` iterates `allUnits` and calls `setSkill` from the
server. It must filter to `local _x` and be spawned on the HC as well as the server, so each
machine sets skill on the units it owns.

## Files touched

| File | Change |
|---|---|
| `INIT.sqf:21` | Split the server branch from the headless branch. |
| `hc/hc_init.sqf` | New. Minimal HC entry: register `clientOwner`, then idle. |
| `description.ext` | `headlessClients[]`. |
| `mission.sqm` | One HC slot. |
| `server/misc/fnc_hc_init.sqf` | New. `fnc_hc_handoff` and the `DUWST_hc_owner` registration handler — the manifest holds no bodies. |
| `server/server_fnc_init.sqf` | Registry lines. |
| `server/server_var_init.sqf` | Declare `DUWST_hc_owner` defaulting to `2`. |
| `server/warcom/fnc_WARCOM_opf_assault.sqf:98-109`, `fnc_WARCOM_opf_patrol.sqf`, `fnc_WARCOM_opf_air.sqf` | Hand off after spawn. |
| `server/misc/fnc_random_veh.sqf:105` | Hand off crews with their group. |
| `server/warcom/fnc_WARCOM_wp_*.sqf` call sites | Route to `groupOwner`. |
| `server/misc/fnc_AI_Master_Control.sqf:5,22-26` | Filter to `local _x`; run on server and HC. |
| `info/server_client_authority.md` | Document the HC as a third machine role and the handoff contract. |

## Task list

- [ ] Fix `INIT.sqf:21` and add a minimal `hc/hc_init.sqf`. Verify: connect an HC and confirm the server log shows one campaign generation, not two.
- [ ] Add `headlessClients[]`, the `mission.sqm` slot, and `DUWST_hc_owner` registration. Verify: with no HC connected, `DUWST_hc_owner` stays `2` and nothing changes.
- [ ] Add `fnc_hc_handoff` and route the waypoint calls through `groupOwner`, with no handoff wired up yet. Verify: a full campaign plays identically — this proves the routing is a no-op on the server before locality moves.
- [ ] Hand off the WARCOM spawners. Verify: `groupOwner` reports the HC for assault groups, and they still reach their objectives.
- [ ] Split `fnc_AI_Master_Control.sqf` by locality.
- [ ] On a dedicated server plus a real headless client: play a campaign to a zone capture. Confirm patrols move, assaults arrive, and server FPS improves.
- [ ] Update `info/server_client_authority.md`.

## Decided trade-offs

**Zone garrisons stay on the server.** They are the larger share of the AI, so this leaves
performance on the table. The reason is `zone_spawn_array`: it is deliberately server-local
(`server/server_var_init.sqf:198`) and it is the control channel between the per-zone loop at
`server/init_zones/fnc_createzone.sqf:295,320-331` and `server/init_zones/fnc_spawnWait.sqf:49,95,110,135-136`.
Moving garrison AI to an HC means either broadcasting that array or moving both loops to the HC,
and both options put campaign-critical spawn/despawn logic on a machine that may not be
connected. Mobile groups are already transient, already respawned freely, and carry no shared
state — they are the safe half. Revisit garrisons once the mobile half is proven in play.

**`fnc_hc_init.sqf` keeps its name.** Renaming it to something unambiguous would touch the file,
its registry line and its call site for no behaviour change. Instead the file gets a header
comment stating it is High Command and unrelated to headless clients, which is where someone
will actually look. This doc is the other half of that fix.

**The waypoint routing lands before any handoff.** Splitting the change this way means the
riskiest edit — 10-odd call sites changing from direct call to `remoteExec` — is validated
against a server-only campaign where the target always resolves to the server. A regression
there shows up immediately instead of being blamed on locality later.

**This cannot be validated on a hosted session.** A hosting player is both server and client, so
locality mistakes work perfectly for the tester and silently do nothing for everyone else. The
mission has already been bitten by exactly that (`KNOWN_ISSUES.md:25-39`), and the dedicated-plus-HC
test rig does not currently exist (`:13-17`). Standing that rig up is a prerequisite of this
plan, not a step inside it.
