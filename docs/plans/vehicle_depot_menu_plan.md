# Unified vehicle depot menu: design plan

Fold the vehicle depot's two scroll-wheel actions into one dialog built on the REQUESTS-menu
framework, and add a vehicle storage garage as a third section alongside the existing modification
and recycling features.

Today the depot at HQ exposes two separate actions on `HQ_repairDepot`: "Vehicle Customization"
(repair, skin swap, pylon mounting) and "Vehicle Recycling" (scrap empty vehicles for CP). Both are
switched on together when the player buys the `vehicle_depot` support
(`client/supports/fnc_supports_init.sqf:307-309`), and both operate on the empty vehicles standing
inside a 5×5 trigger on the HQ helipad (`server/supports/fnc_activateBaseRepairStation.sqf:114-115`,
`fnc_activateBaseRecycleStation.sqf:118-119`). The result is a scroll menu that fans out into two
top-level entries and several nested lists.

The new shape is a single dialog with three sections — **Vehicle modification**, **Vehicle storage
garage**, **Vehicle recycling** — presented like the REQUESTS interface.

Three decisions govern everything below:

- **Reuse the REQUESTS framework, do not rebuild the pylon UI.** The unified menu is a new `.hpp`
  dialog filled imperatively, matching `request_menu.hpp` / `fnc_request_menu.sqf`. The modification
  section's buttons relaunch the existing skin and pylon sub-dialogs rather than reimplementing the
  two-listbox pylon mounting inline.
- **The garage stores full vehicle state.** A stored vehicle is captured to serializable data, then
  deleted from the world. Capture covers class, textures, pylon loadout, per-hitpoint damage, fuel,
  and cargo — so a vehicle the player has paid to modify and has half-wrecked comes back exactly as
  it was left.
- **Garage capacity is a radio-tower-style ladder.** Extra slots are bought in the new menu with CP,
  each tier gated on an AP rung and on owning the tier below it — the same shape as the three radio
  towers, not a flat purchasable counter.

## The REQUESTS framework being reused

The REQUESTS interface is the mission's canonical multi-panel purchasing GUI and the template here.

- Dialog `ressourceheader` is defined in `shared/includes/request_menu.hpp`, `#include`d from
  `description.ext:47`, with base controls (`RscListBox`, `RscButton`, `RscText`, `RscFrame`) and the
  `GUI_GRID_*` layout macros from `shared/includes/defines.hpp`.
- Driver `client/dialog/fnc_request_menu.sqf` creates the dialog, stashes its open context in
  `uiNamespace`, and fills every panel imperatively after `createDialog`. Row identity rides in
  `lbData` (not the row index, because tier-locked rows get sorted to the bottom). A list is refreshed
  by clearing and rebuilding it inside `isNil {}` so both land in one frame
  (`client/dialog/fnc_support_list_fill.sqf`).
- Selection triggers an action through a button whose `action` string spawns a handler
  (`request_menu.hpp:223` → `fnc_request_unit`, etc.); the SUPPORTS listbox relabels its buy button
  via `onLBSelChanged` (`fnc_support_sel_changed.sqf`).

Reusable helpers the new menu leans on:

- `DUWS_fnc_tierListFill` (`shared/functions/fnc_ap_gate.sqf:87`) — fills a listbox from tier-tagged
  rows, sorting unlocked first, greying locked rows and appending their tier. The single most useful
  row-builder for the garage ladder.
- `DUWS_fnc_ap_unlocked` (`fnc_ap_gate.sqf:9`) — whether a side has earned the AP rung a tier sits
  behind, reading `WARCOM_blufor_ap_earned` against `DUWS_ap_tier_rungs`.
- `fnc_support_cost_bracket` (`client/supports/fnc_supports_init.sqf:99`) — formats a price suffix,
  `" (N CP)"` or `" (N CP, M AP)"`, escalation-scaled.
- `fnc_pool_spend` (`server/warcom/fnc_economy_init.sqf:358`) — the client-side entry every purchase
  calls to spend CP or CP+AP with server authority; `fnc_cp_adjust` / `fnc_ap_adjust` for credits.

## The radio-tower pattern the garage mirrors

The three radio towers are the existing example of a purchase that climbs an AP-gated ladder rather
than being bought outright, and the garage copies its shape.

`radio1/2/3` are PERM supports (`fnc_supports_init.sqf:42-44`) costing 15/40/60 CP with 0/10/20 AP on
the upper two. Each is mapped to an AP rung in `DUWS_support_tiers` (`:112-117`) — radio1 at tier 2,
radio2 at 3, radio3 at 4 — so the rung must be earned before the tier can be bought. Each is also
hidden until the tier below it is owned (`:88-89`). Gating goes through `DUWS_fnc_ap_unlocked`; buying
goes through `fnc_support_buy` (`:226`), which sets a team flag, broadcasts it, and tells the server so
the unlock reaches a campaign save.

The garage ladder reuses this *pattern* with its **own** data table rather than adding rows to the
supports catalogue, so garage tiers never leak into the REQUESTS supports listbox or the comm menu.

## The unified dialog

A new dialog class `vehicledepotmenu` in `shared/includes/vehicle_depot_menu.hpp`, `#include`d from
`description.ext` next to `request_menu.hpp`, `idd = -1`, built from the same `defines.hpp` controls on
the `GUI_GRID_*` grid. Header readouts show CP, AP, and garage capacity as "used / total". Three headed
panels sit side by side — Modification, Garage, Recycle — each a `RscFrame` over a `RscListBox` with its
own action buttons, plus one EXIT button. Each button's `action` string spawns its handler, exactly as
the REQUESTS panels do.

The driver `client/dialog/fnc_vehicle_depot_menu.sqf` is the addAction body. It creates the dialog,
stashes the pad-trigger netId in `uiNamespace` (`DUWS_depotMenu_ctx`) for rebuilds, and fills the three
panels. It is compiled and broadcast in `server/server_fnc_init.sqf` alongside `fnc_request_menu`.

**Modification panel.** Lists the empty vehicles currently in the pad trigger area
(`vehicles inAreaArray _trg` with `count crew _x == 0`), each row's `lbData` holding the vehicle's
`netId`. Repair (2 CP) and Check status run inline against the selected vehicle via the existing server
functions (`fnc_veh_repair_action`, `fnc_veh_repair_check_status`). Appearance and Pylons open the
hoisted sub-dialogs (below) on the selected vehicle. The skin and pylon UIs themselves are untouched.

**Garage panel.** Lists stored-vehicle rows (display name plus a short state summary, `lbData` = stored
index) and, below them, the garage-tier ladder rendered with `DUWS_fnc_tierListFill` — owned tiers
green, an affordable next tier orange, AP-locked tiers greyed. Buttons: Store the selected pad vehicle,
Retrieve the selected stored vehicle, Buy the next slot tier.

**Recycle panel.** Lists the empty pad vehicles with each one's value from
`DUWS_fnc_calculateVehicleValue`, with a Recycle button. The existing bulk behaviour — recycle every
empty vehicle on the pad through `fnc_veh_recycle_action` — is preserved as the button's action; the
per-vehicle values are shown so the payout is legible before committing.

Any purchase, store, retrieve, or recycle refills the affected list by clearing and rebuilding inside
`isNil {}`, following `fnc_support_list_fill.sqf`.

## Entry point: one action replaces two

The `vehicle_depot` case in `fnc_supports_init.sqf:307-309` keeps activating the depot server-side and
gains the garage activation. The server activators already build the shared pad trigger; the trigger
stays. What changes is the client registration: the two current registrations — `fnc_client_addRepairActions`
adding "VEHICLE_CUSTOMIZATION" (`fnc_client_addRepairActions.sqf:305`) and `fnc_client_addRecycleActions`
adding "VEHICLE_RECYCLING" (`fnc_client_addRecycleActions.sqf:14`) — are replaced by a single new
`client/supports/fnc_client_addDepotActions.sqf` that adds one "Vehicle Depot" scroll action opening
`fnc_vehicle_depot_menu`, passing the pad-trigger netId. The JIP-id suffix convention that keeps the
depot's remoteExec registrations from evicting each other
(`fnc_activateBaseRepairStation.sqf:117-119`) is kept.

## Hoisting the modification sub-dialogs

`_fnc_appearance` (`fnc_client_addRepairActions.sqf:15`) and `_fnc_pylons` (`:94`) are private closures
that resolve their target vehicle from the pad trigger. They are promoted to named client functions —
`fnc_veh_appearance_dialog` and `fnc_veh_pylons_dialog` — compiled in `server_fnc_init.sqf` and taking
an explicit **target vehicle** instead of the trigger, so the new menu can call them on the specific
vehicle the player selected. The dialogs' internals do not change.

## Garage subsystem

A new server module `server/supports/fnc_garage_init.sqf`, compiled and `publicVariable`'d in
`server_fnc_init.sqf` the way `fnc_pylon_init.sqf` is (`:691-694`) — a client-called support function is
undefined on non-host clients unless it is broadcast. The garage is server-authoritative; clients call
in with `remoteExec [..., 2]`.

- `fnc_garage_store [_caller, _vehNetId]` refuses a crewed vehicle or a full garage, captures the spec,
  `deleteVehicle`s the vehicle, pushes the spec onto `DUWS_garage_stored`, broadcasts, and hints the
  result.
- `fnc_garage_retrieve [_caller, _index, _spawnPos]` creates the vehicle from its spec on the pad,
  applies the spec, removes the entry, and broadcasts.
- `fnc_garage_buy_slot [_caller, _tierKey]` validates that the previous tier is owned and the AP rung is
  earned (`["BLU", _apTier] call DUWS_fnc_ap_unlocked`), spends CP (and any AP) through `fnc_pool_spend`,
  sets the tier flag (broadcast and persisted), and hints.

The capture and apply logic lives in two reusable helpers in `shared/functions/`,
`DUWS_fnc_vehSpecCapture` and `DUWS_fnc_vehSpecApply`, whose output is plain serializable data. Full
state means class, `getObjectTextures`, pylon loadout (`getPylonMagazines` / `setPylonLoadout`),
`getAllHitPointsDamage` plus overall `damage`, `fuel`, and the four cargo channels (weapon, magazine
with ammo counts, item, backpack). Cargo and pylon round-tripping is the substantive engineering here;
any engine quirk found while implementing it is logged in `arma_engine_gotchas.md` in the same change.

## Garage capacity ladder

A data table (for example `DUWS_garage_tiers` in `shared/functions/`) of rows
`[_key, _addCapacity, _cpCost, _apCost, _apTier, _flagVar, _labelKey]`, with a base-capacity constant.
Ownership is a per-tier team flag persisted like a PERM support; capacity is the base plus the added
capacity of every owned tier. Rows render through `DUWS_fnc_tierListFill`, price through
`fnc_support_cost_bracket`, and gate sequentially and by AP rung through `DUWS_fnc_ap_unlocked` — the
radio-tower shape, kept out of the supports catalogue.

## Persistence

`fnc_autoSave.sqf` is a plain `saveGame`, which serializes the mission namespace. Garage state is
therefore held as server-set, broadcast **data arrays only**: `DUWS_garage_stored` (an array of spec
arrays) and the garage-tier flags. No object handle ever enters the mission namespace — the engine
rejects non-serializable globals on assignment or at the next save
(`docs/info/architecture/arma_engine_gotchas.md:85`). A stored vehicle is captured to data and then
deleted; its object reference is never kept across the store.

If the campaign writes team unlocks to the separate save container described in
[campaign_save_format.md](../info/architecture/campaign_save_format.md) rather than relying on engine
`saveGame` alone, the garage flags and `DUWS_garage_stored` are registered there in the same change.

## Strings

New keys in `stringtable.xml`, English only — the DE/ES/ZH tags lag on purpose and are retranslated
later. Use a per-topic prefix (`STR_DUWS_T_DEPOT_*`, `STR_DUWS_T_GARAGE_*`): the menu title, three
section headers, garage-tier labels, the Store / Retrieve / Buy-slot button labels, the capacity
readout, and the success and error hints (garage full, nothing selected, cannot afford, AP-locked,
stored, retrieved). Player text keeps terminal periods on hints and none on button labels, and names
each action and its cost without scene-setting.

## Files

New:

- `shared/includes/vehicle_depot_menu.hpp` — the dialog definition
- `client/dialog/fnc_vehicle_depot_menu.sqf` — the driver
- `client/supports/fnc_client_addDepotActions.sqf` — the single scroll action
- `server/supports/fnc_garage_init.sqf` — store, retrieve, buy-slot
- `shared/functions/` — `DUWS_fnc_vehSpecCapture`, `DUWS_fnc_vehSpecApply`, and the garage-tier table

Changed:

- `description.ext` — `#include` the new dialog header
- `server/server_fnc_init.sqf` — compile and broadcast the new functions; register the hoisted
  appearance and pylon functions
- `client/supports/fnc_client_addRepairActions.sqf` — hoist the sub-dialogs, remove its addAction block
- `client/supports/fnc_client_addRecycleActions.sqf` — retire its action block (folded into the menu)
- `server/supports/fnc_activateBaseRepairStation.sqf`, `fnc_activateBaseRecycleStation.sqf` — register
  the single depot client action and add garage activation
- `client/supports/fnc_supports_init.sqf:307-309` — activate the garage with the depot
- `stringtable.xml` — the new keys
- `tests/unit/functions.txt` — add any new function that gets a unit test (the path list is hardcoded)

## Verification

After repacking (see [`README.md`](../../README.md)), load on Altis, buy the `vehicle_depot` support,
and at the HQ helipad:

- Park an empty vehicle on the pad. A single "Vehicle Depot" scroll action opens the new dialog, and
  the two old actions are gone.
- In Modification, Repair spends 2 CP, Check status hints, and Appearance and Pylons open their existing
  dialogs and apply to the selected vehicle.
- Skin the vehicle, mount a pylon, damage it, and drop its fuel, then Store it: it despawns and capacity
  used increments. Retrieve it: it returns on the pad with the same class, skin, pylon, damage, fuel, and
  cargo. Storing at full capacity is refused.
- The next garage slot tier is greyed until its AP rung is earned and the tier below it is owned, then
  costs CP (and any AP) and raises capacity when bought.
- Recycle still credits CP for empty pad vehicles and matches the shown value.
- After a `saveGame` and reload, the stored vehicles and the purchased capacity both survive.
