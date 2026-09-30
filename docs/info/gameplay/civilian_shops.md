Vendors are shopkeeper civilians that stand in towns and sell gear and vehicles to the player. The
currency is the `Money_roll` inventory item, not CP or AP, so the shop economy is separate from the
war economy. Money is per-player, because each co-op player carries a separate stack of the item.
Every count and every charge goes through `fnc_money_count` and `fnc_money_spend`
(`server/warcom/fnc_economy_init.sqf:240,254`); there is no second money path. Paths are relative
to `src/duws/`.

Vendors are a vanilla-mode feature, like the disguise. `fnc_vendor_init` does nothing when
`CIV_PRESENCE` is `NONE`, `RAVAGE` or `WBK`, and no vendor code runs on the RAVAGE or WBK path.

| Part | File |
|---|---|
| Draft, markers and streaming | `server/vendors/fnc_vendor_init.sqf` |
| Type table and shared helpers | `server/vendors/fnc_vendor_state_init.sqf` |
| Spawn and death | `server/vendors/fnc_vendor_spawn.sqf`, `fnc_vendor_killed.sqf` |
| Stock lists and prices | `server/vendors/fnc_vendor_stock.sqf`, `fnc_vendor_price.sqf` |
| Purchase | `server/vendors/fnc_vendor_buy.sqf` |
| Scroll action | `shared/vendors/fnc_vendor_menuAction.sqf` |
| Catalogue | `client/dialog/fnc_vendor_catalogue.sqf`, `shared/includes/vendor_catalogue.hpp` |
| Gear hand-over | `client/vendors/fnc_vendor_grant.sqf` |

## Types

`DUWS_vendorTypes` (`fnc_vendor_state_init.sqf:10`) holds one row per type. An unknown type resolves
to the name "Vendor" and the `c_unknown` marker, so one bad row cannot fault a pass over every
vendor.

| Type | Marker | Sells | Building |
|---|---|---|---|
| Arms Dealer | `loc_Rifle` | Weapons and gear | A random surveyed building |
| Car Dealer | `loc_car` | Every `LandVehicle` that is not a `StaticWeapon`, tanks included | The building nearest a `"FUELSTATION"` terrain object; a random one in a town with none |
| Boat Dealer | `loc_boat` | Every `Ship` | The building nearest water. Only a town with water inside its radius can host one |

## Placement

The draft runs once, when `fnc_civ_init_Tomata.sqf:305` calls `fnc_vendor_init`, and never runs
again. Its result is the [vendor registry](#vendor-registry), and every later spawn replays it, so a
town's shops stand in the same buildings for the whole campaign.

A town has one vendor slot, or two when its `civ_pop_<n>` is `BIG_TOWN` (30) or more
(`fnc_vendor_init.sqf:18`). `civ_pop_<n>` is the town's usable-building count. The draft fills the
slots in two passes:

1. The seed pass puts each type into one town: the largest town that has a free slot and can host
   that type. Independent rolls could field a type zero times in a campaign, or only in towns that
   start enemy-held and refuse to sell. A type that no town can host is absent, so a landlocked map
   has no Boat Dealer.
2. The fill pass rolls each remaining slot. The wheel holds each type that the town can host and
   does not already have, plus "empty" at three times their total weight (`EMPTY_SHARE`,
   `fnc_vendor_init.sqf:24`). The empty share is relative, so 75% of fill slots stay empty however
   many types exist.

Each vendor gets its own building from the town's survey (`civ_buildings_<n>`). The vendor stands at
a random building position. A building with no positions puts the vendor on clear ground beside it,
because the model origin of most houses is inside a wall. The vendor faces the town centre, and the
facing is stored so the vendor faces the same way after each respawn.

## A vendor is a civilian

`fnc_vendor_spawn` creates the unit through `fnc_civ_spawnUnit` with its vendor flag set. The unit
keeps the `civ_locIndex` tag and the shared `Killed` reputation handler, so a dead shopkeeper costs
the town reputation like any other civilian. The flag removes the two things that a plain civilian
gets:

| Removed | Why |
|---|---|
| The `FiredNear` panic hook (`fnc_civ_spawnUnit.sqf:41`) | A panicking civilian runs 200 m and stays calm-locked for a minute, which abandons the shop. `fnc_civ_panic.sqf:38` also refuses a vendor, because its alarm sweep reaches civilians that did not hear the shot |
| `fnc_civ_clientActions` | A vendor answers none of the talk, intel, arrest and call-over actions. It carries `fnc_vendor_menuAction` instead |

`fnc_vendor_spawn.sqf:23` also disables `PATH`, so the vendor stays at the building its marker
points at.

## Streaming and respawn

Vendors are an occupant kind of their own, `vendors`, on each town's site, with the `town_crowd`
presence profile (`fnc_vendor_init.sqf:233`). They appear and disappear on the crowd's clock, but
they do not count against the crowd: `fnc_civ_liveTarget` sizes the crowd from `civ_pop_<n>` and the
density setting, never from live units.

The kind is separate because only a kind of its own can declare a `tick` hook
(`fnc_vendor_init.sqf:237`). A `tick` hook runs on every poller pass, where a wake or sleep hook runs
only on a transition. On each pass the hook:

1. Counts down each vendor's cooldown by the elapsed time.
2. While a player is in the town, spawns each slot that has no cooldown and no live vendor. This
   covers the first arrival and a respawn while the player is still in the town.
3. When the town is empty past the crowd's grace period, collects the vendors.

`fnc_vendor_killed` sets the cooldown to 300 s (`VENDOR_RESPAWN`) and greys the marker. While the
cooldown runs, the town has no vendor of that type. The cooldown is stored as remaining seconds, not
as a `diag_tickTime` stamp, because an absolute stamp does not survive a save and restore.

## Markers

`fnc_vendor_init.sqf:215` creates one global marker per vendor, named `civ_vendor_<town>_<slot>`,
with the type's icon and the type's name as its text. The text identifies the shop, because the
task-glyph icons are only close to each trade.

Alpha is the reveal channel. The marker starts at 0 and `fnc_civ_town_reveal.sqf:26` sets it to 1
with the town, so the map does not show every shop on the island at start, and hardcore mode needs no
separate path.

Colour is the state channel. `fnc_vendor_markerPaint` (`fnc_vendor_state_init.sqf:74`) paints
`ColorGrey` during a cooldown, and otherwise the town's band colour from `fnc_civ_townBand`, so a
shop in an enemy-held town shows the OPFOR red that explains its refusal. The paint reads the stored
cooldown and the town's reputation, never a unit handle, so it stays correct while the town sleeps.
`fnc_town_rep_adjust` repaints a town's shops when the town crosses a band
(`fnc_economy_init.sqf:184`). The two channels stay separate: a dimmed closed shop would make alpha
mean both "undiscovered" and "closed".

## Service

The vendor carries one scroll action, **Browse Stock**, in the `ACT_CIVILIAN_INTERACTION` bucket. Its
condition is `alive` and a range of 3 m only. The civilian action's call-over state and
one-exchange budget (`DUWS_civ_stopped`, `DUWS_civ_closed` and the rest) do not apply, so a shop opens
as often as the player walks up to it.

A shop refuses to sell in a hostile town, which is a town at reputation -10 or lower. So a capture
opens a town's shops. The check runs twice:

| Where | Reads | Role |
|---|---|---|
| Catalogue open (`fnc_vendor_catalogue.sqf:26`) | The town centre in the broadcast `DUWS_enemy_town_pos` | Advisory. `civ_town_rep` is server-only, so `fnc_civ_repAt` returns 0 on a client |
| Purchase (`fnc_vendor_buy.sqf:37`) | `fnc_civ_repAt` | Authoritative |

The refusal is a hint that names the town (`STR_DUWS_T_VENDOR_HOSTILE`). No catalogue shows behind
it.

## Catalogue

The `vendor_catalogue` dialog uses idc block 8900-8914. Its layout is the faction class browser's
(`startup_faction_key_edit` in `faction_confirm.hpp`), because it does the same job: it picks one
class out of thousands. The two dialogs share the row build and the filter in
`shared/functions/fnc_class_rows_fill.sqf`. The browser's left combo is the stock picker. The
preview shows `editorPreview` for a vehicle and the `picture` icon for gear.

The catalogue greys what the server would refuse, but only as advice: the money count is a local
snapshot, and `fnc_vendor_buy` tests everything again.

The client fetches each stock list when the player picks it (`fnc_vendor_ask`). The server does not
broadcast the lists, because the Everything list is a whole-config sweep, too large to send to every
client for a shop that most never open. The server builds a list on its scheduler, so the sweep does
not hold a frame. The ask gives up after 30 s, because a server-side error sends no reply.

## Stock

An Arms Dealer offers three lists. A Car or Boat Dealer offers four, filtered to its hulls by
`fnc_vendor_hullFits`.

| List | Arms Dealer | Car and Boat Dealers |
|---|---|---|
| Civilian | — | The town's own traffic: `civ_veh_array` or `civ_boat_array` |
| BLUFOR | The config kit of every BLUFOR man key | Every BLUFOR `vehicle` key and its spawn pool, plus the request menu's vehicles |
| OPFOR | The config kit of every OPFOR man key | Every OPFOR `vehicle` key and its spawn pool |
| Everything | Every scope-2 class in `CfgWeapons`, `CfgMagazines` and `CfgGlasses`, plus `Bag_Base` backpacks | Every scope-2 class in `CfgVehicles` |

Each class appears on one list only. OPFOR drops the classes that BLUFOR sells, and Everything drops
the classes that every other list sells (`fnc_vendor_stock.sqf:25-32`), so one item never shows at
two prices.

The side lists come from `fnc_faction_unit_keylist`. A man key's kit is read from config:
`weapons[]`, `magazines[]`, `items[]`, `linkedItems[]`, `backpack` and the `uniformList`,
`vestList`, `headgearList` and `facewearList` random lists. The attachments on its weapons come from
`fnc_faction_class_loadout`, because a faction made with the ORBAT Creator of ALiVE names bare weapons
in `weapons[]` ([ALiVE ORBAT Creator factions](faction_system.md#alive-orbat-creator-factions)). Other
sources were rejected:

| Rejected source | Why |
|---|---|
| Spawning each key to read its live kit | A shop needs both sides, and a spawn per class costs more than a config read |
| `blufor_ammobox_weapons`, `opfor_ammobox_weapons` | Sampled from three hardcoded role keys per side, so a thin slice of what a side fields |
| `DUWS_friendlyArsenal` | Carries curated extras and the disguise gear, so it is not the mirror of the OPFOR list |

The request menu joins the BLUFOR vehicle list because the role keys name only what the AI fields,
and BLUFOR's unarmed transports exist only in the request menu.

The server builds each list once and caches it in `DUWS_vendorStock_<kind>_<list>`, because every
input is fixed at campaign start. The build is on the server because a class that the server cannot
resolve must not be sellable, which is the rule `fnc_faction_query` applies to the faction browser.
Everything is the config as installed, so a modded server sells its mods.

The arsenal mode does not gate the stock. A foreign or heavy class costs more instead, which keeps
the shops apart from the captured-materiel rules of `DUWS_arsenalLimited`.

## Prices

`fnc_vendor_price` prices a class by what it is, not by a per-class table, so a modded class needs
no entry. It returns -1 for a class that no vendor may sell, and the stock build drops every such
class, so it is the one sellability gate. `Money_roll` itself is never sellable.

| Class | Base price |
|---|---|
| Magazine, glasses, other `CfgWeapons` item | 1 |
| Handgun, backpack with a load | 2 |
| Backpack with no load (`maximumLoad` 0): a static weapon part or a UAV | 6 |
| Primary weapon | 3 |
| Launcher | 5 |
| Vehicle | 1.2 × its request-menu CP price (`DUWS_fnc_vehPrice`) |

The OPFOR and Everything lists carry a markup: 1.1 on a vehicle and 1.5 on gear. A smaller gear
markup would round away to nothing on single-digit prices.

Town reputation gives a discount at every shop in the town (`fnc_vendor_discount`): 10% at 10 and
20% at 20, the reputation cap. The server sends the discount with each stock list, and the
catalogue shows it on the price line in BLUFOR blue.

The price is `max(1, floor(base × markup × (100 − discount) / 100))`. One rounding covers every
rate, so a marked-up, discounted vehicle does not round down twice, and the floor of 1 stops a
discounted item from going free.

## Purchase

`fnc_vendor_buy` runs on the server. It asks every question that can refuse the sale before the money
moves, because a charge that cannot be delivered needs a refund, and a refund is a second place for
the price to be wrong. It refuses on the first check that fails:

1. The vendor is dead, or the buyer is more than 4 m away.
2. The town is hostile.
3. The list is not one of this vendor's lists, or the class is not on it. So a hand-made
   `remoteExec` cannot buy a tank from an Arms Dealer, or name the BLUFOR list to skip the markup.
4. The class has no price.
5. The destination is the arsenal and the arsenal does not count the class.
6. The destination is the garage and that domain's pool is full. Land, air and boat have separate
   caps.
7. `fnc_money_spend` finds too little money.

Each purchase offers two destinations:

| Bought | Stored at base | Taken now |
|---|---|---|
| Gear | The arsenal: the pack size is added to the captured-materiel pool, then `publicVariable "DUWS_capturedPool"`, because the setter does not broadcast | `fnc_vendor_grant` on the buyer's machine, one piece at a time: the item's own empty equipment slot, then the first worn container with room, then a ground holder at the buyer |
| Vehicle | The garage: a spec pushed onto `DUWS_garage_stored` | `fnc_depot_carry_spawn` at the buyer, then the R3F carry of a garage retrieval (`fnc_depot_place_r3f`) |

A magazine sells as a pack (`fnc_vendor_buy.sqf:67`). Every other gear class sells as one piece.
The price is for the whole pack.

| Magazine | Pack |
|---|---|
| Rocket or missile, read from the ammo `simulation` | 2 |
| Grenade (hand or 40 mm) or explosive, read from the ammo `simulation` | 3 |
| 100 rounds or more, the belt-fed line of `fnc_IsMG` | 3 |
| Every other magazine | 5 |

The arsenal counts a class only in Limited mode, or when the class is not on `DUWS_friendlyArsenal`.
A friendly class is already unlimited on the shelf, so storing one buys nothing.

A disguised buyer never gets gear in an empty equipment slot, because that empty slot is the cover.

The ground holder comes from `fnc_money_drop`, which puts a weapon or a backpack into weapon or
backpack cargo. Item cargo accepts both but never renders them, so a dropped rifle disappeared.

A bought vehicle has no live original, so its garage spec is built in factory state
(`fnc_vendor_buy.sqf:94`). The hitpoints field is `[[],[],[]]` and never `[]`, because
`DUWS_fnc_vehSpecApply` destructures it into three arrays.

The carry for a vehicle taken now passes `_baseBound` as false: the buyer stands in a town, not
inside the base-keep ring.

## Vendor registry

`DUWS_vendors` holds one array per town and one record per vendor: `[type, position, direction,
cooldown seconds]`. The records are plain values only, with no unit, group or terrain-object handle,
because a persistable thing must rebuild from numbers and strings. The building is stored by
position. `fnc_vendor_live` finds a live vendor on the site roster by its `DUWS_vendor_slot`.
The campaign snapshot saves the registry and a load replays it over the fresh draft, so every shop stands
where it stood ([`campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#world-and-placement)).

The unit broadcasts `DUWS_vendor_type`, `DUWS_vendor_town` and `DUWS_vendor_townName`, because the
catalogue on the buyer's machine needs them and `civ_locations` is server-only.

## Wiring

`server/server_fnc_init.sqf:38` loads `fnc_vendor_state_init` after the civilian state and the site
store, because vendors are civilians registered on each town's site. Every client-called vendor
function is compiled and `publicVariable`'d in that manifest, so it stays the one list of what
reaches clients.
