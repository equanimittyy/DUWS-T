# Command Points: the logistics budget

Command Points become the player's logistics budget rather than "the standard currency", and
the distinction is what makes the two-currency split legible. **Army Power is two-sided; CP is
one-sided.** Both belligerents hold an AP pool and read the same ladder from it
([`ap_economy_plan.md`](ap_economy_plan.md)); there is no OPFOR CP anywhere in the mission —
every one of the 60 references is to `commandpointsblu1`. The enemy director has no logistics
budget because it does not need one, and that asymmetry is the definition:

- **AP decides what either side may field.** A ladder, ratcheting, held by both.
- **CP decides how much of it the player can put and keep in the field.** A throughput, spent
  down and earned back, held by the player alone.

Where the shipped CP economy is documented — pools, writers, faucets, sinks, the purchase
handshake — see [`info/cp_economy.md`](info/cp_economy.md). This plan covers what changes.

## The pool is shared, so abundance is a requirement

`commandpointsblu1` is one pool spent by every slot in `Squad_Leaders`
(`server/server_var_init.sqf:225-258`), which as shipped is every playable slot. Four squad
leads drawing on one wallet is the reason CP has to sit in relative abundance: a scarce shared
pool means the first player to open a request menu spends the team's afternoon.

That is a design constraint, not a nicety, and it is why the answer to "make CP matter" is never
"make CP scarce".

## Two tiers, one price format

| Tier | Pays | Examples |
|---|---|---|
| Regular support | CP only | UAV recon, supply drop, taxis, paradrop |
| Advanced support | CP **and** AP | Artillery, mortar, cluster, napalm, attack helicopter, CAS |
| Utility vehicle | CP only | Unarmed cars, transport trucks, boats, transport helicopters |
| Combat vehicle | CP **and** AP | Tanks, tracked APCs, armed helicopters, artillery pieces |

**Both halves are charged; the AP half is not a gate the player merely passes.** An AP-only
price for the top of the catalogue was rejected: it leaves CP with nothing expensive to buy,
which is the abundance problem in a sharper form, and it makes the player learn two price
formats instead of one. Every purchase reads the same way — logistics plus authority.

### The dual price needs an atomic handshake

`fnc_pool_spend` takes one pool per call (`server/server_fnc_init.sqf:426-441`). Charging CP and
then AP as two sequential calls is not one purchase: the first can succeed and the second fail,
leaving the player charged for nothing, and in co-op another player's spend can land between
them. That is the same race the single-pool handshake was written to close
([`info/cp_economy.md`](info/cp_economy.md#authority-the-server-decides-a-purchase-not-the-buyer)),
reopened one level up.

`fnc_pool_try_spend` therefore needs a dual case that tests both pools and debits both as
adjacent statements against the one server copy, replying with a single verdict. Partial success
must be impossible rather than merely unlikely.

**Escalation scales the CP half only.** `fnc_pool_try_spend:412` applies `fnc_escalation_cost` on
entry to whatever it is given; the AP component opts out, for the reasons already settled in
[`ap_economy_plan.md`](ap_economy_plan.md#spending-authority) — AP purchases are permanent, so
scaling them makes buying early strictly better than buying well.

### The two label formats are opposites

| Catalogue | Label built | Consequence |
|---|---|---|
| Vehicles | At runtime, `_typeDisplayName + ' (' + str(_typeCost) + 'CP)'` (`shared/factions/MODERN/AUTODETECT_blufor.sqf:219`) | English-only, generated. Free to reformat into a dual price |
| Supports | Baked into stringtable text across five languages | The AP figure must be **appended**, never substituted |

The support constraint is the one that already forced escalation to append its surcharge rather
than rewrite the row (`client/dialog/fnc_HQ_Request_Menu.sqf:159-164`): a `%1` placeholder added
to English but not to the other four languages leaves them printing a stale baked number, which
is a wrong figure rather than an untranslated one. A dual price inherits that exactly.

## The AP half is both a rung and a payment

AP does not stop being the escalation ladder when it starts buying supports. Reaching a threshold
debits nothing and is never rescinded, so **spending AP delays the next rung and never costs a
rung already held**. The decision the design wants is therefore real and continuous: bank toward
the tier that upgrades BLUFOR's own waves, or spend on a support now.

Two things have to exist before that decision is playable.

**The tier globals are a prerequisite, not a refinement.** Eight sites currently derive capability
by reading the AP pool live rather than reading a tier — on the player's side, the wave vehicle
steps at `server/warcom/fnc_WARCOM_blu_patrol.sqf:96,100,104`. Buying a support today would
silently downgrade the player's own patrols, which is the ratchet breaking in the direction the
player can least explain. The published tier globals that only ever rise
([`ap_economy_plan.md`](ap_economy_plan.md#the-ratchet-is-structural-today-and-only-in-half-the-read-sites))
must land first.

**The player has to see the next rung.** Banking versus spending is not a decision if the distance
to the threshold is invisible. The map-view readout
([`ap_economy_plan.md`](ap_economy_plan.md#reading-the-war-from-the-map)) is where that goes.

The known consequence is a hovering incentive: because thresholds are free to reach and permanent
once reached, the efficient pattern is to bank just past a rung and then spend down. That is
legible rather than degenerate — the player is choosing when to cash in — but it means the
thresholds function as savings targets, and their spacing decides how often the player faces the
choice at all.

## Vehicles split on a classifier that already exists

`shared/factions/MODERN/AUTODETECT_blufor.sqf:35` unpacks 26 categorised arrays from
`fnc_parseFaction` — `_tank`, `_apcTracked`, `_apcWheeled`, `_carArmed`, `_carTransport`,
`_heliArmed`, `_heliTransport`, `_arty`, `_antiAir` among them — and lines 197-215 flatten every
one of them into a single `requestAssets` list, discarding the category one line later.

The split is therefore a test against arrays that already exist at build time, not a new taxonomy
and not a per-classname table that would have to be maintained against every faction mod on the
Workshop. Keeping it derived from `fnc_parseFaction` is what preserves faction auto-detection: a
hand-authored list of tank classnames would silently mis-price any mod the list has not heard of.

The cost figure itself stays `fnc_evalVehicleCost` (`shared/factions/MODERN/fn_factionAutoDetect.sqf:84`),
which already reads armour, threat and type multipliers from config. What changes is which pool
the resulting figure is drawn from, and what the AP component alongside it is.

## The eight slots

`support_count` starts at 0 (`client/client_init.sqf:236`); every comm-menu unlock refuses when
`support_count > 7` and then increments it. The campaign-long budget is eight radio supports, and
the slate is messier than the 21 menu rows imply:

| Category | Rows | Behaviour |
|---|---|---|
| Slot-consuming | 17 | Tests the cap, increments it |
| Exempt | 4 — armory, HALO, vehicle recycle, vehicle repair | Neither tests nor increments; base facilities, not radio supports |
| Half-in | 1 — Mobile HQ | Tests the cap at `fnc_request_support.sqf:464`, never increments |

**Advanced supports draw on the same eight slots.** A second currency that bought its own slots
would raise the campaign-long budget while appearing to be bookkeeping, and the cap would stop
meaning anything the moment AP could bypass it.

Mobile HQ's half-in state is an inconsistency to resolve rather than a design: it can be blocked
by a full slate while contributing nothing to one.

## Refunding the slate

Eight permanent slots against 17 competing rows means a player commits at hour one to a shape they
cannot evaluate until hour six. A refund is the escape hatch.

**Decided: the refund returns 100% of both currencies and resets the slate wholesale.** No
percentage tax. A partial refund falls hardest on the inexperienced player the mechanic exists for,
and a tax on correcting a mistake teaches players to research the mission outside it rather than
play it.

**Recommended: the refund is available only at HQ or a FOB.** Unrestricted, a free and repeatable
total refund does not fix the cap, it deletes it — the slate becomes a loadout selector, refunded
into artillery before an assault and back into transport afterwards, and eight slots that never
forgo anything are not a constraint. Gating on place rather than on price keeps the full refund,
costs the player a trip instead of points, and needs no invented number. This is the one line here
most likely to be read as friction for its own sake; it is what stops the cap from becoming
decoration.

Once the slate is full, purchases that would consume a slot are refused with a message naming the
refund as the remedy. The refusal already exists — it currently reports only that the slate is
full, which tells the player they are stuck rather than what to do.

### A true 100% means recording what was charged

`fnc_pool_try_spend:412` scales every price by `escalation_multiplier` on entry and **nothing
stores the scaled figure**. The `_cost` local at each `fnc_request_support.sqf` case is the base
price, pre-escalation. So a refund computed from the base price under-pays a player who bought
late, and a refund computed at the current multiplier over-pays one who bought early — buy the
slate at 1.0x, refund at 2.0x, and the difference is minted from nothing.

The refund therefore pays back the recorded charge, per unlock, in both currencies. That record is
new state and it is the substance of the feature; the reset itself is bookkeeping.

### Scope: slots, not facilities

The refund clears the 17 slot-consuming unlocks. The four exempt rows are excluded: refunding a
vehicle repair station is dismantling infrastructure for cash, which is a different mechanic
(recycling already exists and has its own rules) and has nothing to do with slot pressure. Mobile
HQ follows whichever way its half-in status is resolved.

## The unlock state model has to be settled first

`client/includes/supports_init.hpp:2` asserts *"Supports are local to players. No need for
publicVariable"*, and five flags in `fnc_request_support.sqf` contradict it — armory (48), HALO
(143), vehicle recycle (228), vehicle repair (241), Mobile HQ (476) are all broadcast. Within the
include itself the handling is split: `support_armory_available`, `support_halo_available` and
`support_FOB_available` are `isNil`-guarded (26, 30, 34) so a broadcast value survives, while
`support_veh_recycle_available`, `support_veh_repair_available` and `support_mobile_HQ_available`
are assigned unconditionally (8, 25, 24) and clobber it.

**This is already a live co-op fault.** A client joining in progress runs line 24, sets
`support_mobile_HQ_available = true` over a team that has already bought the Mobile HQ, passes the
`!support_mobile_HQ_available` test at `fnc_request_support.sqf:465`, spends a second 10 CP and
broadcasts `false` again. The team pays twice for one Mobile HQ.

A refund cannot be built on this. It must clear roughly 21 flags of mixed and inconsistent
locality, reset a counter that is client-local and never broadcast, and remove comm-menu items
that `BIS_fnc_addCommMenuItem` added per player. The server-side unlock mirror that
[`campaign_persistence_plan.md`](campaign_persistence_plan.md) already calls for is the
prerequisite: one authoritative record of what the team owns and what it paid, which the refund
reads, the persistence snapshot saves, and a joining client is told rather than guesses.

## Abundance is the question this plan does not answer

Moving the expensive catalogue behind a dual price does not make CP scarcer, and the dual price is
not itself a meaningful sink. Eight permanent unlocks at 10–25 CP is roughly 200 CP across an
entire campaign, against passive territory income of `zoneundercontrolblu * 6` every 30 minutes
(`server/misc/fnc_zonesundercontrol.sqf:54-56`) — a player holding five zones out-earns the whole
support catalogue in under three hours, and that is before capture bounties, side missions,
reputation income, intel analysis and kill income. A one-time unlock cost cannot absorb a
recurring faucet at any price.

So the shipped observation stands and this plan sharpens it: territory income snowballs with no
upkeep ([`info/cp_economy.md`](info/cp_economy.md#balance-concerns)), and taking the largest sinks
behind an AP component removes purchasing decisions from the pool that had the fewest.

**The lever that fits CP's definition is a recurring cost that scales with force size**, not a
higher shopping list. If CP is what keeps a force in the field, then a standing army has a running
cost and the interesting question becomes how much the player can sustain rather than whether they
may have a thing. That is the complement to AP's ladder: capability is gated, volume is metered.
It is also the single largest behavioural change in either plan, which is why it is stated here as
the open question rather than as a decision.

## Open questions

- Whether CP gains a recurring, force-scaled sink, and if so what it meters — squads, vehicles,
  FOBs, or holdings. Everything else here is tuning; this decides what CP means.
- The AP component of each advanced support and combat vehicle, which cannot be set before the
  BLUFOR threshold spacing is settled: the AP price and the distance to the next rung are the two
  halves of one decision, and pricing either alone produces a number with no referent.
- Whether the refund is gated at HQ/FOB, and whether it has a cooldown on top or instead.
- Where the boundary falls for armed cars and wheeled APCs. Tanks and unarmed transport are clear;
  the middle of the catalogue is where a rule stated as "armed costs AP" starts pricing an armed
  offroad like a main battle tank.
- Whether Mobile HQ takes a slot. It currently tests the cap without consuming one, and either
  answer is defensible — but the refund needs it settled.
- The fate of the AP→CP converter (`client/dialog/fnc_convertAPtoCP.sqf`). Under this plan selling
  AP costs the player both support purchasing power and tier progress to buy the currency they
  have most of, which argues for deleting it. A CP→AP path must never exist in either case, or the
  abundant pool launders into the scarce one and the split collapses.
- Whether regular supports should cost CP at all once advanced ones exist, or whether the cheap
  tier is better as a slot cost alone — the 2 CP boat taxi is already closer to free than to a
  decision.
