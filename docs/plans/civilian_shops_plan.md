# Civilian shops: design plan

Grow the living-population civilian system into a small economy: named vendor NPCs stand in towns
and sell to the player for money. The theme is borrowed from the "shops and jobs" life scenarios — a
car dealer, a boat dealer, an arms dealer — but every piece is built on the
mission's existing plumbing rather than a parallel one: vendors are ordinary streamed civilians and
purchases move the physical money item.

This plan also owns the vendor framework. The paid jobs, and the employer
vendors that dispatch them, are in [`civilian_jobs_plan.md`](civilian_jobs_plan.md).

Two rules govern both plans:

- **Money is the currency, not CP/AP.** The player already carries `Money_roll` inventory items
  spent on civilian bribes. Shops and job payouts move that same item, so the shop economy is
  separate from the CP/AP war economy and needs its own faucets and sinks (shops) to balance. It is
  per-player: co-op players each have their own wallet, and a bought vehicle or hired group belongs
  to the buyer. A purchase sent to the garage or the arsenal joins that shared store instead.
- **A vendor is a civilian, and the vendor system is a vanilla-mode feature.** Vendors spawn through
  the same path as the town crowd and are disabled in `NONE`, `RAVAGE`, and `WBK`, exactly as the
  disguise is. None of the new code runs on the RAVAGE/WBK path; the deliberate separation behind
  `fnc_civ_mode_spawnGate` stays intact.

## Currency and balance

Money today is earned from enemy loot (`fnc_addRandomLoot.sqf`), searches (`fnc_search_claim.sqf`),
civilian missions (`fnc_civ_mission_finish.sqf`), and random events, and spent only on civilian
bribes. The black market these vendors replace is deleted, so a shop is the only place money buys
gear. The shops are new sinks on that existing income, so they do not wait on jobs; jobs
([`civilian_jobs_plan.md`](civilian_jobs_plan.md)) are one more faucet.

Money is counted and spent through the two existing server functions — `fnc_money_count`
(`fnc_economy_init.sqf:238`) and `fnc_money_spend` (`fnc_economy_init.sqf:252`). Every shop purchase
and job payout goes through those; no second money path.

**Prices carry the balance, not a gate.** A dealer sells any class it lists whatever the arsenal
mode is; a foreign or high-end class is priced steeply instead. Gating the catalogue on
`DUWS_arsenalLimited` would make the shop a second face of the captured-materiel rules, and the two
economies are deliberately separate.

## Vendors are streamed civilians

A vendor is created by the existing `fnc_civ_spawnUnit` (`server/civilian/fnc_civ_spawnUnit.sqf`) with a
new **static "vendor" posture**: no stroll waypoints (`fnc_civ_wp_Tomata`), no traffic, fixed facing
at a chosen building position.

**A vendor is not an interactable civilian.** It keeps the `civ_locIndex` tag and the shared
`Killed` handler, so shooting a shopkeeper costs the town reputation exactly like any other civilian
death. It gets neither of the two things `fnc_civ_spawnUnit` hands a plain civilian:

- **No civilian action set.** The `fnc_civ_clientActions` remoteExec is skipped. That pair is the
  talk/intel/arrest/recruit menu (`fnc_civ_menuAction`) and the call-over (`fnc_civ_stopCommand`),
  none of which a vendor answers. A vendor carries one action, its own, and nothing else.
- **No panic handler.** The `FiredNear` hook into `fnc_civ_panic` is skipped. A panicking civilian
  runs 200 m and stays calm-locked for 60 s, which for a vendor means abandoning the shop — and the
  fixed building is the entire point of the placement. `fnc_civ_panic` already exempts a surrendered
  civilian and a side-mission giver on the same principle; a vendor is the third case, refused at the
  spawn rather than inside the function, because it never needs the handler at all.

Both come off one vendor flag on `fnc_civ_spawnUnit`, which is also what picks the vendor action set
over the civilian one.

**Placement: assigned once at campaign start, scaled by town size, persistent.** Every town the
civilian selector already picks (`fnc_civ_selectTowns.sqf`) can host vendors, but which types a town
gets is decided a single time at init and then fixed for the campaign — not every town has an arms
dealer or a car dealer. Larger towns carry more vendors; town size is read from the usable-building
count already computed per town (`fnc_usableBuildings.sqf`, the same count that sets the town radius
in `fnc_civ_init_Tomata.sqf`). The assignment lands in the persistent vendor registry and is replayed
on load, never re-rolled, so a town's shops do not shuffle across a save. Each vendor is assigned one
building from that same building survey and stays there for the campaign: it stands at the same spot
whenever the town wakes and after every respawn. Some vendors are location-gated as well as
size-scaled — a boat dealer only where there is water inside the town's radius, a fishmonger only in
a coastal town — so a town's mix reflects where it is, not only how big it is.

**Every type appears at least once, where the map allows it.** The assignment is a draft, not an
independent roll per town: a first pass seeds one of each type listed here and in the jobs plan into
a town that can host it, largest town first and location gates respected; a second pass fills the
remaining slots by weighted roll. Rolling each town independently would let a type come up zero
times across the campaign, or only in towns that start enemy-held and refuse to sell. A type whose
gate no town satisfies — a boat dealer on a landlocked map — is simply absent, since the draft
cannot invent ground for it.

**Building picks are weighted by shop type.** A boat dealer takes a building as close to water as
possible, scored by the distance to the nearest water sampled with `surfaceIsWater`. A car dealer
takes a building near a fuel station where the town has one (`nearestTerrainObjects` with the
`"FUELSTATION"` type), and any surveyed building where it does not. The Arms Dealer takes a random
surveyed building.

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

The check runs twice, because `fnc_civ_repAt` is server-only and returns 0 on a client. The menu
greys its rows from the broadcast `DUWS_enemy_town_pos` list, which `fnc_enemy_towns_refresh`
rebuilds on every band crossing; the server re-tests with `fnc_civ_repAt` when a row is actually
picked — the same advisory-then-authoritative split `fnc_civ_menu` already uses for the money count.

**Lifecycle: streamed with the crowd, not always-on.** Persistent AI in every town across Altis is a
perf cost the mission cannot pay. Vendors ride the same site poller as the crowd, so they spawn when
a player is near and are deleted when the town sleeps (`fnc_civ_handler.sqf:114-138`).

They register as their **own occupant kind** on the town's site, `vendors`, reusing the `town_crowd`
profile's presence numbers so they appear and vanish on the crowd's clock. Reusing those numbers is
not sharing a population: vendors are additive and never count against the crowd. `fnc_civ_liveTarget`
sizes the crowd from `civ_pop_<n>` and the density setting, never from live units, so a town fields
its full crowd plus its vendors — a shop does not cost the town a passer-by. An own kind is not about
the spawn — the crowd's wake hook could raise them, and its sleep hook would collect them off the
same roster. It is about the respawn below: hooks are per kind, and only a kind of its own can
declare the poller's `tick` hook, which fires every pass instead of only on a wake/sleep transition
(`fnc_site_stream_init.sqf:380-382`). The town garrison keeps its own cycle for the same reason
(`fnc_civ_garrison.sqf:239`). Riding the crowd would mean a bespoke timer thread beside the poller.

**Respawn five minutes after a kill.** A killed vendor denies its service until it respawns. The
`Killed` handler stamps a per-town, per-type cooldown; the `tick` hook counts it down each pass and
recreates the vendor once it reaches zero, whether or not the town has slept in between. Store the
cooldown as **remaining seconds, never a `diag_tickTime` stamp** — the persistence contract forbids
absolute timestamps because they do not survive a save/restore (`campaign_persistence_plan.md`,
time-state rule). While the cooldown is
live, the town simply lacks that vendor and its service.

## Map markers and icons

Each vendor gets a global marker (`createMarker`, server-side, so it replicates and rebuilds cleanly)
with an icon per type. Follow the zone-marker idiom in `fnc_createzone.sqf:39-49`; do not use the
local per-object registry (`kndr_assignMarker`), which is per-machine and survives neither JIP nor a
rebuild. Reveal a town's markers only once the player has discovered it. `fnc_civ_town_reveal` is
the sole writer of `civ_visible` and already paints that town's own two markers, so a vendor's marker
alpha is set there too — the map is not pre-populated with every shop on the island, and hardcore
mode needs no separate answer.

**Icons.** Drawn from the stock `CfgMarkers` task-glyph set (the `simpletasks` icons), which carries a
car, boat, truck, rifle, box, wrench, and container — a closer fit than the location pins, so the
mapping is deliberate rather than a nearest guess. Those classes were added by the Apex platform
update, but their textures live in the base `\a3\ui_f\` PBO and platform-update configs ship to every
owner, so they render on a mod-free client; the wiki's "Apex" tag marks the update that introduced the
class, not a runtime gate. Every marker also carries the vendor's name as text (`setMarkerText`),
so an approximate glyph is never ambiguous — the label reads "Fishmonger" even where the icon is only
water. No *listed* vendor falls back to the bare `c_unknown` question mark; a vendor type with no row
in the table below or in the [marker table](civilian_jobs_plan.md#markers) defaults to
`c_unknown`. The **No.** column is the contact-sheet number in the marker reference
([`../info/external/arma3_markers.md`](../info/external/arma3_markers.md)).

| Vendor | Icon | No. | Reads as |
|---|---|---|---|
| Car Dealer | `loc_car` | 157 | car |
| Boat dealer | `loc_boat` | 152 | boat |
| Arms Dealer | `loc_Rifle` | 218 | rifle |
| *(unlisted type)* | `c_unknown` | 25 | question mark |

None of these is load-bearing — swap any icon freely, the label is what identifies the vendor. If the
icon shortage grates, the alternative is a few custom `.paa` glyphs declared in `description.ext`
`CfgMarkers`, but that is art and portability cost for a cosmetic win, so it is a later polish.

**Two marker states, driven by the respawn registry.** A live vendor's marker is coloured; a dead one
is grey until it respawns. Use the civilian colour `ColorCIV` (purple, matching the `c_` icons) for
the open state and grey for the down state. On the vendor's `Killed` handler the server sets the
marker grey and stamps the five-minute cooldown (as [remaining seconds](#vendor-registry)); when the
`tick` hook runs that cooldown out and respawns the vendor, the server restores `ColorCIV`. Because
the marker state is a function of the registry's cooldown, not of the live unit, it stays correct
across a town sleeping and waking and across a rebuild — the marker is redrawn grey or coloured from
the stored cooldown, never from a unit handle. A sleeping town's shops read open, because an
uncooled vendor is simply not simulated, not shut.

`ColorGrey` is stock and already in use (`fnc_arty.sqf:93`), so no custom colour class is needed.
Colour alone carries the closed state: marker alpha is already the reveal channel, set from
`civ_visible` in `fnc_civ_town_reveal`, and dimming a down vendor as well would make one number mean
both "undiscovered" and "closed".

## Interaction and menus

A vendor's menu borrows the *shape* of `shared/civ/fnc_civ_menuAction.sqf`, not its contents: one
`ACT_CIVILIAN_INTERACTION` action whose body opens a dialog, added once behind a duplicate guard and
removed on death. Build a `fnc_vendor_menuAction` on that shape, opening either the reusable list
dialog (`fnc_open_action_menu.sqf`, `[title,[[label,code,args,color]...]]`) for simple vendors, or the
catalogue dialog below for the Arms, Car and Boat dealers. The service-refusal check (hostile town)
happens when the menu opens, before any catalogue is shown.

Its condition is distance and `alive` alone. The civilian action gates on `DUWS_civ_stopped`,
`isSurrendered`, `DUWS_civ_closed` and `DUWS_civ_arrested` — a call-over state machine and a
one-exchange budget that a vendor has no part of. A shop is open as often as the player walks up to
it, so none of those flags is read and none is set.

**The catalogue reuses the faction class browser.** It copies the layout and search of the browser
the faction confirmation screen opens (`startup_faction_key_edit` in `faction_confirm.hpp`, driven by
`fnc_faction_key_edit.sqf`). Rows are sorted by display name and read `Name  --  class`. A text
filter matches a case-insensitive substring of the display name or the classname on every key. A
preview shows the selected class: `editorPreview` for a vehicle, the `picture` icon for a weapon or
gear item. Lift the row build and the filter out of `duws_faction_fill_classes` into one shared
helper that both dialogs call.

That browser's left-hand combo is kept rather than dropped, repurposed from a faction picker to a
**stock picker**. The Arms Dealer fills it with three entries; the Car and Boat dealers fill it with
one, since a dealer with a single list still needs the combo to exist for the shared helper to fill
against.

## Shops

Vendors come in two kinds: **shops** that sell to the player, and **employers** that dispatch a job.
The employers are in [`civilian_jobs_plan.md`](civilian_jobs_plan.md#employers); they use the
framework above unchanged except for the hostile-town gate. The Contractor, which hires guerilla
groups out for money, is an ordinary shop under this framework and lives in that plan too. The shops
here:

| Shop | Sells | Built on |
|---|---|---|
| Car Dealer | land vehicles | four stock lists, [below](#the-vehicle-dealers-stock); [vehicle delivery](#delivery) |
| Boat dealer | boats | four stock lists, [below](#the-vehicle-dealers-stock); [vehicle delivery](#delivery); pairs with deep-water fishing |
| Arms Dealer | weapons and gear | three stock lists, [below](#the-arms-dealers-stock); [gear delivery](#delivery) |

### The Arms Dealer's stock

Three lists on the stock picker. They overlap freely: a class in a side list is also in Everything.

| List | Holds |
|---|---|
| BLUFOR | the kit of every BLUFOR DUWS role key |
| OPFOR | the kit of every OPFOR DUWS role key |
| Everything | every gear class the server's config carries at scope 2 |

The side lists are built from `fnc_faction_unit_keylist`, which already takes a side and returns each
man key's representative plus its spawn pool. Their kit is read **out of config**, never by spawning:
`weapons[]`, `magazines[]`, `items[]`, `linkedItems[]` and `backpack` off the unit class, plus the
`uniformList` / `vestList` / `headgearList` / `facewearList` random lists that
`fnc_create_ammo_lists.sqf:188-220` already walks the same way. Spawning each key to call
`getUnitLoadout` is what that file does for BLUFOR today, at a 0.1 s sleep per class; a shop needs
both sides and cannot pay it twice.

Do not reuse `blufor_ammobox_weapons` / `opfor_ammobox_weapons` for the side lists. Those are
sampled from exactly three hardcoded role keys per side (`fnc_create_ammo_lists.sqf:87-88`), not
from the key list, so they are a thin slice of what a side actually fields.
`DUWS_friendlyArsenal` is the wrong source too: it is a snapshot of the assembled arsenal shelf,
which carries curated extras and the folded-in civilian disguise gear, so a BLUFOR tab built from it
would not be the mirror of the OPFOR one.

Everything is a whole-config sweep at scope 2 — `CfgWeapons` (weapons and items), `CfgMagazines`,
`CfgGlasses`, and `CfgVehicles` classes of `Bag_Base` — so a modded server sells its mods. It is the
one expensive build here, so it is built once and cached rather than per open, and it is built on the
server: a class the server cannot spawn must not be sellable, which is the same rule
`fnc_faction_query` enforces for the faction browser.

### The vehicle dealers' stock

The Car and Boat dealers carry the Arms Dealer's three lists and a Civilian list in front of them.
Each list is filtered to the dealer's hulls: the Car Dealer sells any `LandVehicle` that is not a
`StaticWeapon`, tanks included, and the Boat dealer any `Ship`. No AP tier gates a dealer's stock;
the price carries the balance.

| List | Holds |
|---|---|
| Civilian | the town's own traffic: `civ_veh_array` or `civ_boat_array` |
| BLUFOR | every BLUFOR `vehicle` role key and its spawn pool, plus the request menu's vehicles |
| OPFOR | every OPFOR `vehicle` role key and its spawn pool |
| Everything | every `CfgVehicles` class the server's config carries at scope 2 |

The request menu is added to BLUFOR because the role keys name only what the AI fields; BLUFOR's
unarmed transports exist only in the request menu.

A hull costs 1.5 money per CP of its request-menu price (`DUWS_fnc_vehPrice`), rounded down. The
OPFOR and Everything lists at every dealer, the Arms Dealer included, cost 1.1 times as much, with
one rounding down over both rates.

### Delivery

Every purchase from the Arms, Car and Boat dealers offers two destinations: store it at base, or
take it now.

| Bought | Stored | Taken now |
|---|---|---|
| Weapons and gear | The arsenal: +1 to the captured-materiel pool (`fnc_captured_pool_setCount`, then `publicVariable "DUWS_capturedPool"` — the setter does not broadcast) | Into the buyer's inventory when `canAdd` finds room, otherwise dropped in a ground holder at the buyer |
| Vehicles and boats | The garage: a spec pushed onto `DUWS_garage_stored`, refused when that domain's pool is full (the `fnc_garage_store` cap check) | Spawned at the dealer and hand-placed exactly as a garage retrieval: `fnc_garage_retrieve`'s invulnerable, frozen, locked spawn, the `fnc_depot_place_r3f` carry, then `fnc_depot_place_finish` |

The pool counts only what the arsenal tracks: a friendly class is unlimited outside Limited mode
(`DUWS_arsenalLimited`), so the arsenal destination is offered only for a class the pool counts.

The ground drop reuses `fnc_money_drop`, which is extended to do it. It writes magazine and item
cargo only today, so a dropped rifle or backpack would vanish; it gains `addWeaponCargoGlobal` and
`addBackpackCargoGlobal` on the same `isClass` dispatch it already uses to tell a magazine from an
item. One holder builder for every gear type, rather than the per-slot branching
`fnc_blackMarketPurchase` grew.

A garage spec normally comes from `DUWS_fnc_vehSpecCapture` on a live vehicle; a bought vehicle has
none, so its spec is built from the class in factory state. That spec cannot be sparse:
`DUWS_fnc_vehSpecApply` destructures the hitpoints field into three arrays and then walks the first,
so a factory spec's hitpoints entry is `[[],[],[]]` and never `[]`, which would throw.

## Vendor registry

Vendors and their state must be rebuildable from plain data, per the campaign-persistence rule that
"a thing is persistable when a single function can build it from numbers and strings"
(`campaign_persistence_plan.md`). The registry holds plain values in `missionNamespace`: per town,
each vendor's type, its building (by position, because a terrain object handle is not a plain
value), and its respawn cooldown (remaining seconds). No unit, group, or Location handles; the live
vendor objects are rebuilt by the spawn path, not stored. Saving and replaying the registry is in
[`campaign_persistence_plan.md`](campaign_persistence_plan.md#features-not-built-yet).

## Wiring

Every new client-callable function (`fnc_vendor_menuAction`, the shop handlers, the job dispatchers)
is compiled and `publicVariable`'d in the manifest `server/server_fnc_init.sqf`, so the one place
that lists what reaches clients stays complete. Server-only helpers stay server-only and are marked
as such there, matching the existing convention.

## Phasing

1. **Vendor framework.** New static "vendor" posture, one weighted building per vendor, streamed
   lifecycle, five-minute respawn, global marker, hostile-town service refusal, and one menu — start
   with the Arms Dealer, which needs no new spawn path: its goods go to a pool or an inventory. This
   phase builds the shared catalogue browser, the three stock lists, and gear delivery.
2. **Shops.** Car Dealer and Boat dealer, with vehicle delivery to the garage or the hand-placed
   spawn. Shop prices are tuned against job payouts in the jobs plan's balance phase.
