# Civilian shops: design plan

Grow the living-population civilian system into a small economy: named vendor NPCs stand in towns
and sell to the player for money. The theme is borrowed from the "shops and jobs" life scenarios — a
car dealer, a boat dealer, an arms dealer, a mercenary contractor — but every piece is built on the
mission's existing plumbing rather than a parallel one: vendors are ordinary streamed civilians and
purchases move the physical money item.

This plan also owns the vendor framework. The paid jobs, and the employer
vendors that dispatch them, are in [`civilian_jobs_plan.md`](civilian_jobs_plan.md).

Two rules govern both plans:

- **Money is the currency, not CP/AP.** The player already carries `Money_roll` inventory items
  spent at the black market and on civilian bribes. Shops and job payouts move that same item, so
  the shop economy is separate from the CP/AP war economy and needs its own faucets and sinks
  (shops) to balance. It is per-player: co-op players each have their own wallet, and a bought
  vehicle or hired group belongs to the buyer.
- **A vendor is a civilian, and the vendor system is a vanilla-mode feature.** Vendors spawn through
  the same path as the town crowd and are disabled in `NONE`, `RAVAGE`, and `WBK`, exactly as the
  disguise is. None of the new code runs on the RAVAGE/WBK path; the deliberate separation behind
  `fnc_civ_mode_spawnGate` stays intact.

## Currency and balance

Money today is earned from enemy loot (`fnc_addRandomLoot.sqf`), searches (`fnc_search_claim.sqf`),
civilian missions (`fnc_civ_mission_finish.sqf`), and random events, and spent only on black-market
micro-purchases (`fnc_addHQBuildingActions.sqf:29-31`) and civilian bribes. The shops are new sinks
on that existing income, so they do not wait on jobs; jobs
([`civilian_jobs_plan.md`](civilian_jobs_plan.md)) are one more faucet.

Money is counted and spent through the two existing server functions — `fnc_money_count`
(`fnc_economy_init.sqf:237`) and `fnc_money_spend` (`fnc_economy_init.sqf:251`). Every shop purchase
and job payout goes through those; no second money path.

The one economy question that needs a deliberate answer is the relationship between the money
mercenaries and the CP/AP squads — see [Contractor](#contractor) below.

## Vendors are streamed civilians

A vendor is created by the existing `fnc_civ_spawnUnit` (`server/civilian/fnc_civ_spawnUnit.sqf`) with a
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
are picked from that same building survey. Some vendors are location-gated as well as size-scaled — a
fishmonger only in a coastal town — so a town's mix reflects where it is, not only how big it is.

**The farmer is the one rural vendor.** It stands at an isolated farmhouse outside every town and
streams off its own position rather than the town-crowd poller; its placement is in
[`civilian_jobs_plan.md`](civilian_jobs_plan.md#farmer-placement).

**Service is gated, not spawning.** Vendors stand in every town including enemy-held ones, but a
**shop** in a hostile town **refuses to sell** — the menu opens to a refusal line ("not while they're
watching"), never the catalogue. Reuse the town-reputation read the disguise already uses to break in
an enemy-held town (`fnc_civ_repAt`, the `<= -10` test in `fnc_disguiseAsCivilian.sqf`). This makes
capturing an area the thing that opens its shops, without needing a separate "friendly town" list.
**Job employers are the exception**: mundane labour is plausible cover, so an employer still dispatches
its job in a hostile town — that is exactly the reason a disguised operator has to be there (see
[`civilian_jobs_plan.md`](civilian_jobs_plan.md#jobs)).

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

## Map markers and icons

Each vendor gets a global marker (`createMarker`, server-side, so it replicates and rebuilds cleanly)
with an icon per type. Follow the zone-marker idiom in `fnc_createzone.sqf:47-69`; do not use the
local per-object registry (`kndr_assignMarker`), which is per-machine and survives neither JIP nor a
rebuild. Reveal a town's markers only once the player has discovered it, keyed on the same visibility
flag the zone markers use (`setMarkerAlpha`), so the map is not pre-populated with every shop on the
island.

**Icons.** Drawn from the stock `CfgMarkers` task-glyph set (the `simpletasks` icons), which carries a
car, boat, truck, rifle, box, wrench, and container — a closer fit than the location pins, so the
mapping is deliberate rather than a nearest guess. Those classes were added by the Apex platform
update, but their textures live in the base `\a3\ui_f\` PBO and platform-update configs ship to every
owner, so they render on a mod-free client; the wiki's "Apex" tag marks the update that introduced the
class, not a runtime gate. Every marker also carries the vendor's name as text (`setMarkerText`),
so an approximate glyph is never ambiguous — the label reads "Fishmonger" even where the icon is only
water. No *listed* vendor falls back to the bare `c_unknown` question mark; a vendor type with no row
in the table below or in the [employer table](civilian_jobs_plan.md#employer-markers) defaults to
`c_unknown`. The **No.** column is the contact-sheet number in the marker reference
([`../info/external/arma3_markers.md`](../info/external/arma3_markers.md)).

| Vendor | Icon | No. | Reads as |
|---|---|---|---|
| Car Dealer | `loc_car` | 157 | car |
| Boat dealer | `loc_boat` | 152 | boat |
| Arms Dealer | `loc_Rifle` | 218 | rifle |
| Contractor | `loc_Attack` | 151 | crossed swords |
| *(unlisted type)* | `c_unknown` | 25 | question mark |

None of these is load-bearing — swap any icon freely, the label is what identifies the vendor. If the
icon shortage grates, the alternative is a few custom `.paa` glyphs declared in `description.ext`
`CfgMarkers`, but that is art and portability cost for a cosmetic win, so it is a later polish.

**Two marker states, driven by the respawn registry.** A live vendor's marker is coloured; a dead one
is grey until it respawns. Use the civilian colour `ColorCIV` (purple, matching the `c_` icons) for
the open state and grey for the down state. On the vendor's `Killed` handler the server sets the
marker grey and stamps the five-minute cooldown (as [remaining seconds](#persistence-contract)); when
the cooldown elapses and the poller respawns the vendor, the server restores `ColorCIV`. Because the
marker state is a function of the registry's cooldown, not of the live unit, it stays correct across a
town sleeping and waking and across a rebuild — the marker is redrawn grey or coloured from the stored
cooldown, never from a unit handle.

Grey needs one check: confirm `ColorGrey` exists in `CfgMarkerColors` on this build. If it does not,
use `ColorBlack` (definitely present, reads as a dead marker) or declare a custom `class ColorDUWS_Grey`
once in `description.ext` `CfgMarkerColors`. Optionally also drop the marker alpha while down
(`setMarkerAlpha 0.5`) so grey plus dim reads unmistakably as "closed."

## Interaction and menus

A vendor's interactable menu copies the civilian pattern: `fnc_civ_menuAction.sqf` adds one
`ACT_CIVILIAN_INTERACTION` action, distance- and state-gated, whose body opens a dialog. Build a
`fnc_vendor_menuAction` on that shape, opening either the reusable list dialog
(`fnc_open_action_menu.sqf`, `[title,[[label,code,args,color]...]]`) for simple vendors, or a
purpose-built dialog like `civ_menu.hpp` for the ones with a catalogue. The service-refusal check
(hostile town) happens when the menu opens, before any catalogue is shown.

## Shops

Vendors come in two kinds: **shops** that sell to the player, and **employers** that dispatch a job.
The employers are in [`civilian_jobs_plan.md`](civilian_jobs_plan.md#employers); they use the
framework above unchanged except for the hostile-town gate. The shops:

| Shop | Sells | Built on |
|---|---|---|
| Car Dealer | civilian vehicles | `civ_veh_array` pool; empty-vehicle spawn as in `fnc_veh_drop.sqf` |
| Boat dealer | civilian boats | civilian boat classes, same empty-vehicle spawn; pairs with deep-water fishing |
| Arms Dealer | weapons and gear | virtual arsenal already seeded by `fnc_scanCivilianGear.sqf`; a money-gated pick |
| Contractor | AI groups (guerilla/PMC) into High Command | `fnc_HCsquad_spawn.sqf` + `hcSetGroup`; see below |

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

## Wiring

Every new client-callable function (`fnc_vendor_menuAction`, the shop handlers, the job dispatchers)
is compiled and `publicVariable`'d in the manifest `server/server_fnc_init.sqf`, so the one place
that lists what reaches clients stays complete. Server-only helpers stay server-only and are marked
as such there, matching the existing convention.

## Phasing

1. **Vendor framework.** New static "vendor" posture, streamed lifecycle, five-minute respawn, global
   marker, hostile-town service refusal, and one menu — start with the Arms Dealer, whose catalogue
   is the seeded arsenal and needs no new spawn path.
2. **Shops.** Car Dealer and Boat dealer (civilian vehicle and boat spawn) and the Contractor:
   relocate the CP/AP squad buy out of the request menu, then add the money mercenaries beside it.
   Settles which groups the money mercenaries draw from: an existing independent roster, or a new
   guerilla/PMC set.
3. **Persistence.** Wire the vendor registry into the save. Shop prices are tuned against job
   payouts in the jobs plan's balance phase.
