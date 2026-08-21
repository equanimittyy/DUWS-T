# Civilian shops and jobs: design plan

Grow the living-population civilian system into a small economy: named vendor NPCs stand in towns,
sell to the player for money, and dispatch paid jobs. The theme is borrowed from the "shops and
jobs" life scenarios — a car dealer, an arms dealer, a mercenary contractor, a job office, a
garbage round — but every piece is built on the mission's existing plumbing rather than a parallel
one: vendors are ordinary streamed civilians, purchases move the physical money item, and jobs are
gated on the existing civilian disguise.

Two rules govern everything below:

- **Money is the currency, not CP/AP.** The player already carries `Money_roll` inventory items
  spent at the black market and on civilian bribes. Shops and job payouts move that same item, so
  the shop economy is separate from the CP/AP war economy and needs its own faucet (jobs) and sinks
  (shops) to balance. It is per-player: co-op players each have their own wallet, and a bought
  vehicle or hired group belongs to the buyer.
- **A vendor is a civilian, and the vendor system is a vanilla-mode feature.** Vendors spawn through
  the same path as the town crowd and are disabled in `NONE`, `RAVAGE`, and `WBK`, exactly as the
  disguise is. None of the new code runs on the RAVAGE/WBK path; the deliberate separation behind
  `fnc_civ_mode_spawnGate` stays intact.

## Currency and balance

Money today is scarce — earned in small amounts and spent only on black-market micro-purchases
(`fnc_addHQBuildingActions.sqf:29-31`) and civilian bribes. Adding large sinks (vehicles, weapons,
hired groups) without a matching faucet leaves the shops unusable, so **jobs are not optional
flavour; they are the faucet that funds the shops.** Ship at least one job type in the same phase as
the first paid shop.

Money is counted and spent through the two existing server functions — `fnc_money_count`
(`fnc_economy_init.sqf:237`) and `fnc_money_spend` (`fnc_economy_init.sqf:251`). Every shop purchase
and job payout goes through those; no second money path.

The one economy question that needs a deliberate answer is the relationship between the money
mercenaries and the CP/AP squads — see [Contractor](#contractor) below.

## Vendors are streamed civilians

A vendor is created by the existing `fnc_civ_spawnUnit` (`server/misc/fnc_civ_spawnUnit.sqf`) with a
new **static "vendor" posture**: no stroll waypoints (`fnc_civ_wp_Tomata`), no traffic, fixed facing
at a chosen building position. Everything else — the `Killed` handler, the client interaction action
remoteExec — reuses what a civilian already gets.

**Placement: assigned once at campaign start, scaled by town size, persistent.** Every town the
civilian selector already picks (`fnc_civ_selectTowns.sqf`) can host vendors, but which types a town
gets is decided a single time at init and then fixed for the campaign — not every town has an arms
dealer or a car dealer. Larger towns carry more vendors; town size is read from the usable-building
count already computed per town (`fnc_usableBuildings.sqf`, the same count that sets the town radius
in `fnc_civ_init_Tomata.sqf`). The assignment lands in the persistent vendor registry and is replayed
on load, never re-rolled, so a town's shops do not shuffle across a save. Vendor spots within a town
are picked from that same building survey.

**Service is gated, not spawning.** Vendors stand in every town including enemy-held ones, but a
vendor in a hostile town **refuses to trade** — the menu opens to a refusal line ("not while they're
watching"), never the shop. Reuse the town-reputation read the disguise already uses to break in an
enemy-held town (`fnc_civ_repAt`, the `<= -10` test in `fnc_disguiseAsCivilian.sqf`). This makes
capturing an area the thing that opens its shops, without needing a separate "friendly town" list.

**Lifecycle: streamed with the crowd, not always-on.** Persistent AI in every town across Altis is a
perf cost the mission cannot pay. Vendors ride the same site poller as the crowd — register them as
occupants of the town's `town_crowd` profile (or a parallel `town_vendors` profile) so they spawn
when a player is near and are deleted when the town sleeps (`fnc_civ_handler.sqf:116-140`).

**Respawn five minutes after a kill.** A killed vendor denies its service until it respawns. The
`Killed` handler stamps a per-town, per-type cooldown; the poller's wake hook recreates the vendor
only once the cooldown has elapsed. Store the cooldown as **remaining seconds, never a
`diag_tickTime` stamp** — the persistence contract forbids absolute timestamps because they do not
survive a save/restore (`campaign_persistence_plan.md`, time-state rule). While the cooldown is
live, the town simply lacks that vendor and its service.

## Map markers

Each vendor type gets a global marker (`createMarker`, server-side, so it replicates and is carried
by a save) with a distinct icon per type. Follow the zone-marker idiom in `fnc_createzone.sqf:47-69`;
do not use the local per-object registry (`kndr_assignMarker`), which is per-machine and would not
survive JIP or a save cleanly. Reveal markers only for towns the player has discovered, keyed on the
same visibility flag the zone markers use (`setMarkerAlpha`), so the map is not pre-populated with
every shop on the island.

## Interaction and menus

A vendor's interactable menu copies the civilian pattern: `fnc_civ_menuAction.sqf` adds one
`ACT_CIVILIAN_INTERACTION` action, distance- and state-gated, whose body opens a dialog. Build a
`fnc_vendor_menuAction` on that shape, opening either the reusable list dialog
(`fnc_open_action_menu.sqf`, `[title,[[label,code,args,color]...]]`) for simple vendors, or a
purpose-built dialog like `civ_menu.hpp` for the ones with a catalogue. The service-refusal check
(hostile town) happens when the menu opens, before any catalogue is shown.

## Vendor types

| Vendor | Offers | Built on |
|---|---|---|
| Car Dealer | civilian vehicles for money | `civ_veh_array` pool; empty-vehicle spawn as in `fnc_veh_drop.sqf` |
| Arms Dealer | weapons/gear for money | virtual arsenal already seeded by `fnc_scanCivilianGear.sqf`; a money-gated pick |
| Contractor | hire AI groups (guerilla/PMC) into High Command | `fnc_HCsquad_spawn.sqf` + `hcSetGroup`; see below |
| Job Office | job board: dispatches jobs | new dispatcher |
| Garbage round | job: collect rubbish around town | new job loop |

### Contractor

The Contractor is where buying groups lives from now on. Two decisions shape it:

- **The existing CP/AP squad buy moves here.** Today squads are bought in the HQ/FOB request menu
  (`fnc_request_squad.sqf`, catalogue `DUWS_bluforSquads` at `fnc_BLUFOR_squad_init.sqf:26-32`,
  spawned by `fnc_HCsquad_spawn.sqf`). That column is pulled out of the request menu
  (`fnc_request_menu.sqf`) and relocated onto the Contractor NPC. The spawn/hand-off machinery
  (`fnc_HCsquad_spawn`, `hcSetGroup`) is unchanged; only where the player triggers it moves.
- **The Contractor also sells money mercenaries in parallel.** Guerilla/PMC-style groups bought with
  the physical money item rather than CP/AP, hired into the player's High Command the same way. Two
  distinct sources of groups then coexist: the relocated military squads (CP/AP) and the merc groups
  (money). Keep them visibly distinct in the menu so the player understands the two costs.

The rework of the request-menu squad column is the one piece here that touches existing balance, so
it is scoped as its own step rather than folded into vendor framework work.

## Jobs

Jobs pay money and are the economy's faucet. **Every job requires an active disguise**
(`player getVariable "DUWS_disguised"`, set by `fnc_disguiseAsCivilian.sqf`) and aborts if the
disguise breaks (firing, drawing a weapon). That keeps a job civilian cover work, not something done
in full kit, and makes jobs vanilla-mode-only like the disguise, disabled in `NONE`/`RAVAGE`/`WBK`.

The disguise gate gives jobs a role past money. A shop refuses service in a hostile town, but a cover
job is the *reason* to be in one: a garbage round through an enemy-held town is a plausible excuse for
a disguised operator to loiter and read the garrison. Jobs are cover plus faucet. The idea is borrowed
from the resistance-economy scenarios (Overthrow, the Life mods) — jobs dispatched by a vendor and
repeatable — reframed so the work funds the war and buys cover rather than being an end in itself.

Under the skins the jobs reduce to three reusable primitives: collect a quota at scattered markers,
transport a passenger or cargo to a destination, and drive to a target for a hold-action then return.
Build the three and each job is a skin on one, which keeps the set cheap to grow.

| Job | What | Built on |
|---|---|---|
| Garbage round | pick up rubbish scattered around a town with a hold-action until a quota is met | rubbish markers around town + `BIS_fnc_holdActionAdd` (as `fnc_intel_search_action.sqf`) |
| Postal courier | deliver a package to another town | traffic road data (`fnc_civ_traffic.sqf`) |
| Taxi / transport | pick up an AI civilian passenger and drop them at a destination, which may be another town | spawn a civ passenger, `moveInCargo`, destination marker |
| Cargo haul | truck crates between towns; slower, more exposed on the road | vehicle + crate cargo, road route |
| Roadside assistance | drive to a broken-down civilian vehicle somewhere and repair it with a hold-action | spawn a damaged `civ_veh_array` vehicle at a marker + hold-action repair |
| Utility repair | restore power or water at a town's infrastructure marker with a hold-action; completion raises the town's reputation | go-fix primitive + `fnc_town_rep_adjust` |
| Farm pickup | drive to a rural farm, collect a crate, and return it to the town | transport primitive: a crate at a rural marker, delivered back |
| Fishing | on foot at a coastal spot, a hold-action rolls a weighted catch table until a quota, then paid | water-spot marker + `surfaceIsWater` check + `BIS_fnc_holdActionAdd`; `selectRandomWeighted` catch table |

Fishing is the one job worth borrowing a mechanic for. The Life "gather" loop it comes from validates
the spot by proximity to a marker, refuses to gather from inside a vehicle, and adds catch on a
repeated timed action until the carry weight caps. The first two map straight onto these jobs (a
marker check, an on-foot hold-action); the third does not — there is no virtual-inventory weight
system here, so the catch is a plain counter and the payout comes through `fnc_money_spend`, not sold
inventory. What is worth taking is the weighted catch table (common fish / rare fish / junk, rolled
with `selectRandomWeighted`): variable pay is the only thing that distinguishes fishing from the
garbage quota. Boats and nets are dropped for a first version — they reintroduce the driving this job
exists to avoid.

Utility repair is the one job that pays in more than money: finishing it nudges the town's reputation
up via `fnc_town_rep_adjust`, and reputation is what opens that town's shops — so the jobs loop feeds
the shop gate, not only the wallet.

Jobs are taken from the Job Office vendor, which is the job board.

**Start with two: garbage round and postal courier** — one static-marker loop, one town-to-town
drive. The rest is variation to layer on once the loop is proven and tuned.

## Persistence contract

Vendors and their state must be rebuildable from plain data, per the campaign-persistence rule that
"a thing is persistable when a single function can build it from numbers and strings"
(`campaign_persistence_plan.md`). Concretely:

- Keep a registry of vendors as plain values in `missionNamespace` — per town, the vendor types
  assigned (decided once at init, see [Placement](#vendors-are-streamed-civilians)) and each one's
  respawn cooldown (remaining seconds). On restore the stored assignment is replayed, not
  regenerated, so towns keep their shops. No unit, group, or Location handles in that registry; the
  live vendor objects are rebuilt by the spawn path, not stored.
- Player money is inventory, so it is carried by whatever saves the player; nothing extra to store.
- In-progress job state (a half-finished garbage round) is not worth persisting in a first version —
  drop the job on load rather than trying to resume it.

## Wiring

Every new client-callable function (`fnc_vendor_menuAction`, the shop handlers, the job dispatchers)
is compiled and `publicVariable`'d in the manifest `server/server_fnc_init.sqf`, so the one place
that lists what reaches clients stays complete. Server-only helpers stay server-only and are marked
as such there, matching the existing convention.

## Open decisions

- **Money faucet size.** Job payouts versus shop prices — untuned. Needs a balance pass once a job
  and a paid shop both exist (P4).
- **Merc roster source.** Which groups the Contractor's money mercenaries draw from (an existing
  independent roster, or a new guerilla/PMC set).

## Phasing

1. **Vendor framework.** New static "vendor" posture, streamed lifecycle, five-minute respawn, global
   marker, hostile-town service refusal, and one menu — start with the Arms Dealer, whose catalogue
   is the seeded arsenal and needs no new spawn path.
2. **Shops.** Car Dealer (civilian-vehicle spawn) and the Contractor: relocate the CP/AP squad buy
   out of the request menu, then add the money mercenaries beside it.
3. **Jobs.** Garbage round and postal courier, disguise-gated — the money faucet.
4. **Balance and persistence.** Tune payouts against prices; wire the vendor registry into the save.
