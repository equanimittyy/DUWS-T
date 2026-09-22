# Civilian jobs and guerilla hires: design plan

Paid jobs dispatched by employer NPCs: one more money faucet for the
[civilian shops](../info/gameplay/civilian_shops.md), beside loot, searches, and civilian missions. The
Contractor, who hires local guerillas out for that money, is here too: both are the resistance side
of the civilian economy. The theme is borrowed from the same "shops and jobs" life scenarios — a
post office, a garbage depot, a taxi rank — and built on the mission's existing plumbing: employers
are vendors on the shops' vendor framework, payouts move the physical money item, and jobs are
gated on the existing civilian disguise.

The shops' two rules hold here ([`civilian_shops.md`](../info/gameplay/civilian_shops.md)): jobs
pay in the `Money_roll` item, never CP/AP, and they run only in vanilla mode.

## Jobs

Jobs pay money. **Every job requires an active disguise**
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

| Job | Employer | What | Built on |
|---|---|---|---|
| Garbage round | Garbage depot | pick up rubbish scattered around a town with a hold-action until a quota is met | rubbish markers around town + `BIS_fnc_holdActionAdd` (as `fnc_intel_search_action.sqf`) |
| Postal courier | Post office | deliver a package to another town | traffic road data (`fnc_civ_traffic.sqf`) |
| Taxi / transport | Taxi rank | pick up an AI civilian passenger and drop them at a destination, which may be another town | spawn a civ passenger, `moveInCargo`, destination marker |
| Cargo haul | Haulage depot | truck crates between towns; slower, more exposed on the road | vehicle + crate cargo, road route |
| Roadside assistance | Mechanic | drive to a broken-down civilian vehicle somewhere and repair it with a hold-action | spawn a damaged `civ_veh_array` vehicle at a marker + hold-action repair |
| Utility repair | Utility works | restore power or water at a town's infrastructure marker with a hold-action; completion raises the town's reputation | go-fix primitive + `fnc_town_rep_adjust` |
| Farm pickup | Farmer | drive to a rural farm, collect a crate, and return it to the town | transport primitive: a crate at a rural marker, delivered back |
| Fishing | Fishmonger | fish at a coastal spot; the catch table shifts with water depth, so deep water reached by boat pays far better than the shore | depth via `getTerrainHeightASL` + `BIS_fnc_holdActionAdd`; depth-banded `selectRandomWeighted` catch table |

Fishing is the one job worth borrowing a mechanic for. The Life "gather" loop it comes from validates
the spot by proximity to a marker, refuses to gather from inside a vehicle, and adds catch on a
repeated timed action until the carry weight caps. The first two map straight onto these jobs (a
marker check, an on-foot hold-action); the third does not — there is no virtual-inventory weight
system here, so the catch is a plain counter and the payout comes through `fnc_money_spend`, not sold
inventory. What is worth taking is the weighted catch table (common fish / rare fish / junk, rolled
with `selectRandomWeighted`), and the variance is driven by depth: the catch band is chosen from the
water depth under the fishing point (`getTerrainHeightASL`, negated to metres of water), so the shore
pays little and the good catches sit offshore in deep water. That is what the boat dealer is for —
shore fishing is the on-foot entry, a bought boat reaches the deep bands, and fishing income scales
with the boat. The Life "no gathering from a vehicle" guard is therefore relaxed for the boat, which
is the deep-water case; nets are still dropped for a first version, since the depth bands plus a
hold-action carry the mechanic.

Utility repair is the one job that pays in more than money: finishing it nudges the town's reputation
up via `fnc_town_rep_adjust`, and reputation is what opens that town's shops — so the jobs loop feeds
the shop gate, not only the wallet.

**Start with two: garbage round and postal courier** — one static-marker loop, one town-to-town
drive. The rest is variation to layer on once the loop is proven and tuned.

## Employers

Each job is started at its own employer NPC (the Employer column in [Jobs](#jobs)), and for fishing
the fishmonger also buys the catch. Employers are vendors: the
[vendor framework](../info/gameplay/civilian_shops.md#placement) places, marks, streams,
respawns, and persists them exactly like the shops. The one behavioural difference is the
hostile-town gate: a shop refuses to sell there, but an employer keeps dispatching, which is the
cover a disguised operator wants. The farmer is the one placement exception.

### Farmer placement

The farmer does not stand in a town: it sits at an isolated farmhouse in open country, 1–2 km out
from a valid zone rather than inside a town's building survey. Place it by sampling a random point in
that 1–2 km ring around the chosen zone centre (`zone_meta_array` carries each zone's position), then
taking the nearest `House` terrain object with **two doors or fewer** — the low door count rejects the
military and industrial complexes that have many, and keeps the pick a plausible farm dwelling.
`fnc_usableBuildings` is the wrong filter here: it selects by building-position count, which favours
exactly the large complexes to avoid. Count the house's door animation sources directly instead.
Because it sits outside every town, the farmer cannot ride the town-crowd poller for streaming — it
streams off its own position (spawn when a player nears the farmhouse, sleep when none is), the one
lifecycle difference from the town vendors.

## Contractor

The Contractor is where buying groups lives from now on: a vendor that hires fighters out, and the
guerilla half of this plan. It is a shop, so it refuses service in a hostile town, and it takes a
random surveyed building like the Arms Dealer. Two decisions shape it:

- **The existing CP/AP squad buy moves here.** Today squads are bought in the HQ/FOB request menu
  (`fnc_request_squad.sqf`, catalogue `DUWS_bluforSquads` at `fnc_BLUFOR_squad_init.sqf:26-32`,
  spawned by `fnc_HCsquad_spawn.sqf`). That column is pulled out of the request menu
  (`fnc_request_menu.sqf`) and relocated onto the Contractor NPC. The spawn/hand-off machinery
  (`fnc_HCsquad_spawn`, `hcSetGroup`) is unchanged; only where the player triggers it moves.
- **The Contractor also sells money mercenaries in parallel.** Guerilla/PMC-style groups bought with
  the physical money item rather than CP/AP, hired into the player's High Command the same way. Two
  distinct sources of groups then coexist: the relocated military squads (CP/AP) and the merc groups
  (money). Keep them visibly distinct in the menu so the player understands the two costs.

The relationship between the money mercenaries and the CP/AP squads is the one economy question that
needs a deliberate answer. The rework of the request-menu squad column is also the one piece here
that touches existing balance, so it is scoped as its own step rather than folded into vendor
framework work.

## Markers

The employers' and the Contractor's markers follow the shops'
[marker rules](../info/gameplay/civilian_shops.md#markers). Two picks are classic base markers
rather than `simpletasks` glyphs — `c_car` (taxi) and `loc_Fountain` (fishmonger, a water stand-in).
The **No.** column is the contact-sheet number in the marker reference
([`../info/external/arma3_markers.md`](../info/external/arma3_markers.md)).

| Vendor | Icon | No. | Reads as |
|---|---|---|---|
| Garbage depot | `loc_help` | 174 | help / assist |
| Post office | `loc_Box` | 153 | package |
| Taxi rank | `c_car` | 22 | car |
| Haulage depot | `loc_Truck` | 231 | truck |
| Mechanic | `loc_repair` | 217 | wrench |
| Utility works | `loc_use` | 232 | cog / service |
| Farmer | `loc_container` | 161 | crate |
| Fishmonger | `loc_Fountain` | 169 | water |
| Contractor | `loc_Attack` | 151 | crossed swords |

## Persistence

In-progress job state (a half-finished garbage round) is not worth persisting in a first version —
drop the job on load rather than trying to resume it. Employers persist through the
[vendor registry](../info/gameplay/civilian_shops.md#vendor-registry).

## Wiring

Job dispatchers are client-callable, so they are compiled and `publicVariable`'d in
`server/server_fnc_init.sqf` like every vendor function ([`civilian_shops.md`](../info/gameplay/civilian_shops.md#wiring)).

## Phasing

1. **Garbage round and postal courier.** Disguise-gated. Their two employers are vendor types
   on the existing framework.
2. **Contractor.** Relocate the CP/AP squad buy out of the request menu, then add the money
   mercenaries beside it. Settles which groups the money mercenaries draw from: an existing
   independent roster, or a new guerilla/PMC set.
3. **Balance.** Tune job payouts against shop prices. Settles the faucet size, which stays untuned
   until a job and a paid shop both exist.
