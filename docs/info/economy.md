# Economy: CP, AP and reputation

Command Points (CP, the global `commandpointsblu1`) are the single currency the player spends — on
support unlocks, reinforcements, vehicles, FOBs, operatives and transport. Army Power (AP,
`WARCOM_blufor_ap`) is a separate war-momentum score the WARCOM director reads; it is not spent from
menus. Town reputation is a third pool, per town rather than campaign-wide. The three meet in one
place: the AP→CP converter (`fnc_convertAPtoCP.sqf`). Faction-specific purchase prices live in the
`blufor_RQST_*` variables and `fnc_evalVehicleCost` — see [`faction_system.md`](faction_system.md).

## Authority: one server-side writer per pool

`commandpointsblu1` is a networked global, so every change routes through a single server-side
function, `fnc_cp_adjust` (`src/duws/server/misc/fnc_economy_init.sqf`), invoked as
`[delta] remoteExec ["fnc_cp_adjust", 2]`. Callers send a signed *delta*; nothing else assigns or
`publicVariable`s the pool. This is a hard concurrency requirement, not a style choice: mutating a
networked global as `x = x - c; publicVariable "x"` from a client drops concurrent co-op changes and
can duplicate CP — see the gotchas entry *"A shared global mutated as `x = x - c; publicVariable`
loses concurrent writes"* in [`arma_engine_gotchas.md`](arma_engine_gotchas.md).

The result is floored at 0: the purchase gates all ask *"can I afford this"*, so a negative pool
behaves like an empty one and the floor only keeps the HUD honest. The writer also **rounds the
running total**, which is what makes CP an integer currency — the HUD prints the pool raw, so any
fraction reaching it renders as `32.05`. Rounding the total rather than the delta additionally
normalises a pool that already holds a fraction. A caller that wants to pay out sub-point amounts
must therefore accumulate whole points itself; the writer would swallow a `0.05` delta silently, so
it logs one to the RPT instead. The only absolute assignments left are the pre-game starting value
(`server_var_init.sqf:85`, default 20; campaign menu offers 0–400 in
`fnc_process_campaign_menu.sqf:210-218`), which run on the host before play.

Army Power carries the same contract. `fnc_ap_adjust` (same file) is the sole writer of both
`WARCOM_blufor_ap` and `WARCOM_opfor_ap`, invoked as `[side, delta] remoteExec ["fnc_ap_adjust", 2]`
with side `"BLU"` or `"OPF"`; its pre-play absolutes are `server_var_init.sqf:178-179`,
`fnc_WARCOM_init.sqf:22-28` and the campaign-menu presets in `fnc_process_campaign_menu.sqf:277-348`.
Both pools floor at 0 as CP does: losing a zone sheds the same AP swing that taking one pays, so an
unclamped pool could sit deeply negative, and every WARCOM wave threshold reads *"above N"* anyway.
Two deliberate differences from `fnc_cp_adjust`: an unrecognised side drops the delta and logs it
rather than crediting the wrong pool, so a bad call shows up in the RPT instead of corrupting a pool
or throwing; and there is no display refresh, because AP has no HUD counter and no
`publicVariableEventHandler` — which is why `fnc_convertAPtoCP.sqf` paints control 1002 from its own
expected post-spend total instead of re-reading the pool, whose local copy is still pre-spend at that
point.

**Reputation is territory, and `fnc_town_rep_adjust` is its only writer.** Same contract with one
addition: the writer owns the rounding as well as the write. Reputation is the only pool taking
fractional deltas (`+0.5`, `-1`), so callers send a plain delta and never normalise, or two of them
would round differently; the writer snaps to two decimals, zeroes anything below `0.01`, and clamps
each town to `[-20, 20]`.

There is no campaign-wide figure to sum into. Every caller resolves its town through
`fnc_civ_townAt`, which answers `-1` for open country, a civilians-off campaign and RAVAGE/WBK alike,
and a `-1` delta is dropped: harm done where no town can see it costs nothing. Consumers that only
need a number read `fnc_civ_repAt`, which answers neutral for the same three cases — a consumer that
has to tell "neutral" from "not modelled" reads `civ_town_rep` directly, the way `fnc_civ_townQuery`
and `fnc_sitrep_fanout` do.

**No call site prints a reputation total, and neither does the map.** A caller computes its figure
before the write lands, and the clamp means the writer may apply less than was asked, so any number a
caller names is a prediction. A town's standing reaches the player as marker *colour* alone —
`fnc_civ_townRender` sets colour and alpha, the markers are created without text
(`fnc_civ_init_Tomata.sqf:262-279`), and `civ_town_rep` is never broadcast. SITREP prints the standing
of the town the reading player is stood in, resolved per player by `fnc_sitrep_fanout` because that
array never leaves the server.

## Authority: the server decides a purchase, not the buyer

Owning the arithmetic is not the same as owning the decision. A client testing
`commandpointsblu1 >= cost` against its own copy is reading a broadcast snapshot that is a network
round trip out of date, so two players buying at once both pass a gate the pool funds once. The debits
are then applied in full and the floor absorbs the overshoot, which makes the second purchase free.

Every purchase therefore routes through a request/reply handshake, both halves in
`server/misc/fnc_economy_init.sqf`. `fnc_pool_spend` runs on the buyer, sends the request and blocks;
`fnc_pool_try_spend` runs on the server, tests and debits as adjacent statements against the one
server copy, and replies with the verdict. Call sites read as a guard clause:

```sqf
if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};
```

Three properties are load-bearing:

- **The debit is `call fnc_cp_adjust`, not `remoteExec [..., 2]`.** Even on the server, remoteExec
  queues a scheduled job for a later frame, which would split the test from the debit and reopen the
  gap. The same applies to the server-side purchase paths that never used the handshake —
  `server/misc/fnc_redeployHQUnits.sqf`, `server/supports/fnc_activateBaseRepairStation.sqf`,
  `server/supports/fnc_uav_scanner.sqf`, `fnc_pylon_set_with_cost`.
- **The caller blocks, so it must be scheduled.** `waitUntil` throws in unscheduled code. Every
  purchase entry point is `spawn`ed today — the dialog `action =` fields, the comm-menu `expression =`
  fields, `addAction` bodies — so any new one must be too.
- **A timeout refuses.** Silence must not let an effect through. It logs, because a dropped reply is
  otherwise indistinguishable in-game from a genuine refusal.

The reply carries the figure that was actually debited as well as the verdict, and `fnc_pool_spend`
leaves it in `duws_last_charge` rather than returning it: the forty existing call sites read the
function as a guard clause and none of them wants a second value. Only the support ledger reads it
([below](#supports-permanent-and-consumable)), and it has to — the escalation multiplier is applied
inside `fnc_pool_try_spend`, so the base price the caller passed is not what left the pool.

Three client-side comparisons survive as *advisory* pre-filters, and are commented as such:
`client/supports/fnc_mapclickarty.sqf`, `client/supports/fnc_mapclickuav.sqf`,
the redeploy row in `client/dialog/fnc_base_menu_fill.sqf`, plus the opening check in
`client/supports/fnc_request_fob.sqf`.
Each spares the player a wait — a 45 s map-click window, a 10 s site survey — that they provably cannot
pay for. None of them decides anything; the charge happens later, on the server, against a balance the
pre-filter's read has long since stopped describing.

Where a comm-menu support passes `_cost = 0` the charge already happened at unlock time, so the
handshake short-circuits and the site is left alone: `client/dialog/fnc_MHQ_select.sqf` and both taxis
in `supports/taxi/` spend nothing.

## Escalation scales every price

`fnc_escalation_cost` (`server/misc/fnc_economy_init.sqf`) multiplies a base cost by
`escalation_multiplier` and rounds up, so a scaled price is never cheaper than the base one.
`fnc_pool_try_spend` applies it on entry, which covers every `fnc_pool_spend` site at once; the four
paths listed above as handshake exceptions each apply it themselves, and are the only places that have
to remember to. It is defined beside the pool writers rather than in `fnc_escalation.sqf` so the
purchase path does not depend on whether escalation ever started — with no multiplier published it is
the identity.

The multiplier is `publicVariable`d because the request menu displays it. Base costs are baked into
each row's stringtable label (`"Supply Drop (5CP) Radio"`), so `client/dialog/fnc_request_menu.sqf`
appends the scaled figure rather than substituting it, against a cost table it keeps for that purpose.
Stripping the numbers out and re-formatting from a `%1` placeholder is the tidier shape and is rejected
on localisation grounds: a placeholder added to English but not to the other four languages leaves them
printing the stale baked figure, which is a wrong number rather than an untranslated one.

## Supports: permanent and consumable

One catalogue, `fnc_support_defs` in `client/supports/fnc_supports_init.sqf`, holds every row of the
request menu's support list in display order, and the `PERM`/`CONS` column decides everything the two
mechanisms differ in:

| | Permanent (6 rows) | Consumable (17 rows) |
|---|---|---|
| Bought for | the whole team, once | the buyer alone |
| Slot | none | one of `support_max_slots` |
| Flag | broadcast, and recorded in `DUWS_support_permanent` | client-local |
| Refund | never | 100% of what it charged |
| On death | untouched | lost, `support_death_refund` of the slate returned |

The split is not new; it was latent and unnamed. The four base facilities — arsenal, HALO, vehicle
repair, vehicle recycle — already broadcast their flag and already sat outside the slot cap, while
the radio supports already took a slot and already handed the buyer a per-player comm-menu item.
Mobile HQ and the FOB unlock moved to permanent because both are capabilities rather than
deliveries: each still charges per use (10 CP a FOB, and the MHQ token is re-issued rather than
re-bought when its vehicle is released or destroyed), so team ownership costs nothing it was
collecting before.

**Row order is the catalogue's, not a literal.** Both the list build (`fnc_support_list_fill`) and
the buy/refund handler read the same array and index it the same way, and the listbox keeps a
row → definition map in `uiNamespace`. The previous shape agreed a row number between two files by
hand, so a row added anywhere but the end repointed every row below it at another support's price
and flag — which had already happened once, to the colour pass.

**A refund pays back the recorded charge, not the price.** `fnc_pool_try_spend` scales every cost by
`escalation_multiplier` on entry, so a refund computed from the base under-pays a player who bought
late, and one computed at the current multiplier mints the difference for a player who bought early:
buy the slate at 1.0x, refund at 2.0x, and the difference comes from nowhere. What the server
debited is what comes back.

**It refunds unlocks, never uses.** Every comm-menu support charges again when it is called
(`fnc_mapclickarty` and the five drops all spend on use), so buying, calling and refunding around a
single fire mission costs exactly that fire mission — which is what stops the refund from being a way
to replay a campaign's worth of supports for free.

**A support that is not in hand cannot be refunded.** The fourteen comm-menu classes with
`removeAfterExpressionCall = 1` are absent from the player's menu for as long as their mission is
running, and `fnc_supports_init` tracks presence for its own reasons
([`arma_engine_gotchas.md`](arma_engine_gotchas.md#a-comm-menu-item-id-goes-stale-the-moment-the-item-is-used)),
so that one test covers a fire mission in flight, a taxi in transit and a High Command aircraft in
the air without a guard per support.

Both constants are in `server/server_var_init.sqf` and broadcast because clients read them:
`support_max_slots` (8, unchanged) and `support_death_refund` (0.1). The death share is deliberately
small — a generous one makes dying a cheaper way to liquidate a slate than walking back to a base,
which inverts what the death penalty is for.

## Faucets

| Source | File | Amount |
|---|---|---|
| Zone capture (first time) | `server/init_zones/fnc_captured.sqf:46` | the zone's bounty — ≈50 for a 1000 m zone |
| Zone recapture (after loss) | `server/init_zones/fnc_blufor_cap.sqf:61` | the bounty as decayed by prior captures — ≈17, then ≈6, … |
| Passive territory hold | `server/misc/fnc_zonesundercontrol.sqf:54-56` | `zones_held × 6`, every 30 min |
| Side-mission reward | `server/missions/fnc_mission_reward.sqf` | `reward × cp_reward_multiplier` (multiplier default 1) |
| Town Army Power | `server/misc/fnc_zonesundercontrol.sqf:32-46` | AP, not CP: each banded town's worth of 1–3 to whichever side holds it, every 30 min |
| Recruit rescued civilian | `server/misc/fnc_recruit_civilian_server.sqf` | +5 (+8 in WBK mode) |
| Intel analysis (terminal) | `server/misc/fnc_intelAnalysis.sqf` | 1–2 for the two corpse-loot items, 4–6 for the four a search drops, 8 for either secret file |
| Enemy corpse loot | `server/misc/fnc_addRandomLoot.sqf` → analysis | ~80% of enemies carry 0–2 of Money/Files/Wallet |
| Search payout (`pool` kind) | `server/misc/fnc_search_claim.sqf` | +1–3 CP, on a flagged body or objective whose payout draw lands on `pool` |
| Vehicle recycle | `server/supports/fnc_activateBaseRecycleStation.sqf` | `DUWS_fnc_calculateVehicleValue` per empty vehicle, summed then rounded |
| Kill income | `server/server_init.sqf:257-276` | +1 per 10 hostile kills, swept on the economy tick; the remainder carries |
| Killhouse training | `server/misc/fnc_createKillhouse.sqf:1072` | +1 (targets) or +10 (challenge), once, on clearing all 100 |
| Rare-zombie kill (WBK) | `server/misc/fnc_civ_handler_wbk.sqf:359` | +10, or +30 for the Goliath |
| AP→CP conversion | `client/dialog/fnc_convertAPtoCP.sqf` | 15 AP → 10 CP, one-way |
| Support refund | `client/supports/fnc_supports_init.sqf` | the recorded charge in full; `support_death_refund` of the slate when its holder dies |

**A zone carries two figures, and they behave differently on purpose.** Both ride the capture triggers
— `fnc_createzone.sqf:280` → `fnc_captured.sqf` → `fnc_opfor_cap.sqf` → `fnc_blufor_cap.sqf` and round
again — as arguments 2 and 7:

| Figure | Set by | Behaviour |
|---|---|---|
| **Worth** (`_points`) | zone radius at generation, also stored in `zone_meta_array` | Never reassigned. AP is measured against it, so a zone swings the same momentum however often it changes hands |
| **Bounty** (`_bounty`) | `round(worth × zone_cp_capture)` at generation | The CP the next capture pays. Multiplied by `zone_cp_recapture` on every capture, so it decays as the zone flips |

The split is the design: ground fought over repeatedly has been looted already and should stop being a
payday, but it has not become less strategically valuable, so the AP swing must not decay with it.
Deriving both from one variable is what the earlier code did, and it compounded around the ownership
loop — a contested zone decayed toward paying nothing in *either* currency while `zone_meta_array`
still recorded its original worth. Tuning constants are grouped in `server/server_var_init.sqf`:
`zone_cp_capture`, `zone_cp_recapture`, `zone_ap_swing`, `zone_ap_consolation`.

Losing a zone pays no CP, so `fnc_opfor_cap` passes the bounty through untouched; only a capture decays
it. Once it rounds to 0 the CP award and its notification are skipped rather than announcing a payday
of nothing.

**The passive-hold loop is the campaign's single economy clock.** It is spawned exactly once
(`server/warcom/fnc_init_OPFOR_WARCOM.sqf:20`), so territory income does not stack per zone captured,
and territory CP, town AP and kill income are all paid from the same 30-minute iteration. Equal nominal
periods are not one clock — a suspended thread resumes when the scheduler reaches it, so separate loops
accrue their own slop and walk apart. The tick reports itself in one Overlord line carrying the
territory take, CP and AP. Kill income is paid on the same tick but kept out of that figure and
announced only to the player who earned it: naming attrition in a campaign-wide report would advertise
kill farming as an income route. Only the territory CP is gated on `zoneundercontrolblu > 0` — AP pays
unconditionally, since the enemy banking its towns while the player holds nothing is the case the town
economy exists to model.

Each iteration bumps `econ_tick`, the clock's sequence number. Anything wanting a "once per payout
window" cap keys off that rather than starting a timer of its own — `fnc_civ_healed.sqf` is the one
caller today, capping what a town can pay out for treating its wounded. Server-local and unbroadcast:
only server-side caps read it.

## Sinks

| Category | Where | Cost |
|---|---|---|
| Support unlocks | `client/supports/fnc_supports_init.sqf` | 2–25 (boat taxi 2 … CAS/CAP 25); refundable if consumable, see [above](#supports-permanent-and-consumable) |
| Reinforcement units | `dialog/fnc_request_unit*.sqf` | 2–4 (from `blufor_RQST_UNIT_*`) |
| Vehicles | `dialog/fnc_request_vehicle*.sqf` | 5–100 (from `fnc_evalVehicleCost`, clamped) |
| Squads | `dialog/fnc_request_squad*.sqf` | per squad table |
| FOB deploy | `client/supports/fnc_request_fob.sqf` | fixed |
| Operatives | `client/operative/fnc_operator_recruit.sqf:29` | 8 (re-deploying a healed one is free) |
| Mobile HQ | `client/dialog/fnc_MHQ_select.sqf` | 10 |
| Heli / boat taxi | `supports/taxi/` | fixed |
| Base repair, HQ and FOB redeploy, sitrep | `server/supports/fnc_activateBaseRepairStation.sqf`, `server/misc/fnc_redeployHQUnits.sqf`, `fnc_redeployFOBUnits.sqf`, `server/supports/fnc_sitrep_support.sqf` | 2 / 2 / 2 / 1 |
| Death | `client/client_init.sqf:172,187` | `DUWSMP_CP_death_cost` (0–10), plus the holder's consumable slate |

Open balance questions — the territory snowball, the loot-to-analysis faucet, recycle ownership, AP
inflation and the bribe figures — are in
[`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#economy-balance); the redesign that would spend AP is
[`../economy_plan.md`](../economy_plan.md).

## Who may spend

Two permission lists of playable slot names, defined together at `server/server_var_init.sqf:225-258`
and checked as `(vehiclevarname player) in <list>`:

| List | Owns |
|---|---|
| `game_master` | campaign-level control — the setup flow, side-mission requests (`client/missions/fnc_stratmap.sqf:24`), the global heal |
| `Squad_Leaders` | everything that spends CP — request menus, radio supports, MHQ, FOB redeploy — plus High Command |

`Squad_Leaders` lists every playable slot as shipped, so it restricts nothing today. It exists to be
trimmed: on a dedicated server, cutting it to the real squad-lead slots restricts all of the above in a
single edit.

That only holds while **nothing outside a permission check reads it**. Personal kit — the medic,
engineer and UAV traits — is granted unconditionally at `client/client_init.sqf:199-201` for exactly
this reason. Gating a *capability* rather than a *privilege* on this array would mean trimming it
silently removed revives from the rest of the team, with no error to point at.
