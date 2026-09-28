# Economy: CP, AP and reputation

Command Points (CP, the global `commandpointsblu1`) are the player's throughput currency — spent on
support unlocks, reinforcements, vehicles, FOBs, operatives and transport. Army Power (AP,
`WARCOM_blufor_ap`) is the earned-capability currency: it gates the tier ladder, and it is now also
spent from the menus — on advanced supports and on garrison buys from the map readout, with combat
vehicles priced CP-only for the moment. Town reputation is a third pool, per town rather than
campaign-wide, and its band routes a town's passive income to a side: CP to a BLUFOR town, AP to an
OPFOR one. Vehicle prices come from `DUWS_fnc_vehPrice` (`shared/functions/fnc_veh_price.sqf`) over
the shipped `blufor_RQST_*` tables — see [`faction_system.md`](faction_system.md).

## Authority: one server-side writer per pool

`commandpointsblu1` is a networked global, so every change routes through a single server-side
function, `fnc_cp_adjust` (`src/duws/server/warcom/fnc_economy_init.sqf`), invoked as
`[delta] remoteExec ["fnc_cp_adjust", 2]`. Callers send a signed *delta*; nothing else assigns or
`publicVariable`s the pool. This is a hard concurrency requirement, not a style choice: mutating a
networked global as `x = x - c; publicVariable "x"` from a client drops concurrent co-op changes and
can duplicate CP — see the gotchas entry *"A shared global mutated as `x = x - c; publicVariable`
loses concurrent writes"* in [`arma_engine_gotchas.md`](../architecture/arma_engine_gotchas.md).

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
One deliberate difference from `fnc_cp_adjust`: an unrecognised side drops the delta and logs it
rather than crediting the wrong pool, so a bad call shows up in the RPT instead of corrupting a pool
or throwing. Display then differs by side. `WARCOM_blufor_ap` carries a live counter — a
`publicVariableEventHandler` mirrors it to the request-menu AP box (ctrl 1002) on clients
(`client_init.sqf:138`) while the host refreshes the same control directly (`fnc_economy_init.sqf:86`)
— and its earned-AP total crossing a force tier fires a card and a sound (`:88-96`). `WARCOM_opfor_ap`
has no counter; it surfaces on demand in the map readout and in the request-menu labels of what it now
buys, not through a pushed update.

**Reputation is territory, and `fnc_town_rep_adjust` is its only writer.** Same contract with one
addition: the writer owns the rounding as well as the write. Reputation is the only pool taking
fractional deltas (`+0.5`, `-1`), so callers send a plain delta and never normalise, or two of them
would round differently; the writer snaps to two decimals, zeroes anything below `0.01`, and clamps
each town to `[-20, 20]`.

There is no campaign-wide figure to sum into. Every caller resolves its town through
`fnc_civ_townAt`, which answers `-1` for open country, a civilians-off campaign and RAVAGE/WBK alike,
and a `-1` delta is dropped: harm done where no town can see it costs nothing. Consumers that only
need a number read `fnc_civ_repAt`, which answers neutral for the same three cases — a consumer that
has to tell "neutral" from "not modelled" reads `civ_town_rep` directly, the way `fnc_map_readout_query`
does.

**No call site prints a reputation total, and neither does the map.** A caller computes its figure
before the write lands, and the clamp means the writer may apply less than was asked, so any number a
caller names is a prediction. A town's standing reaches the player as marker *colour* alone —
`fnc_civ_townRender` sets colour and alpha, the markers are created without text
(`fnc_civ_init_Tomata.sqf:262-279`), and `civ_town_rep` is never broadcast. SITREP counts towns by band
instead, off the broadcast `DUWS_blufor_town_pos` and `DUWS_enemy_town_pos`, and names no town's figure.

## Authority: the server decides a purchase, not the buyer

Owning the arithmetic is not the same as owning the decision. A client testing
`commandpointsblu1 >= cost` against its own copy is reading a broadcast snapshot that is a network
round trip out of date, so two players buying at once both pass a gate the pool funds once. The debits
are then applied in full and the floor absorbs the overshoot, which makes the second purchase free.

Every purchase therefore routes through a request/reply handshake, both halves in
`server/warcom/fnc_economy_init.sqf`. `fnc_pool_spend` runs on the buyer, sends the request and blocks;
`fnc_pool_try_spend` runs on the server, tests and debits as adjacent statements against the one
server copy, and replies with the verdict. Call sites read as a guard clause:

```sqf
if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};
```

Three properties are load-bearing:

- **The debit is `call fnc_cp_adjust`, not `remoteExec [..., 2]`.** Even on the server, remoteExec
  queues a scheduled job for a later frame, which would split the test from the debit and reopen the
  gap. The same applies to the server-side purchase paths that never used the handshake —
  `server/init_hq/fnc_redeployHQUnits.sqf`, `DUWS_fnc_zoneRedeploy`, `server/supports/fnc_activateBaseRepairStation.sqf`,
  `server/supports/fnc_uav_scanner.sqf`, `fnc_pylon_set_with_cost`, and the AP-only
  `server/missions/fnc_map_readout_buy.sqf`.
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
the redeploy button in `client/dialog/fnc_command_fill.sqf`, plus the opening check in
`client/supports/fnc_request_fob.sqf`.
Each spares the player a wait — a 45 s map-click window, a 10 s site survey — that they provably cannot
pay for. None of them decides anything; the charge happens later, on the server, against a balance the
pre-filter's read has long since stopped describing.

Where a comm-menu support passes `_cost = 0` the charge already happened at unlock time, so the
handshake short-circuits and the site is left alone: `client/dialog/fnc_MHQ_select.sqf` and both taxis
in `supports/taxi/` spend nothing.

## Escalation scales every price

`fnc_escalation_cost` (`server/warcom/fnc_economy_init.sqf`) multiplies a base cost by
`escalation_multiplier` and rounds up, so a scaled price is never cheaper than the base one.
`fnc_pool_try_spend` applies it on entry, which covers every `fnc_pool_spend` site at once; the four
CP paths listed above as handshake exceptions each apply it themselves, and are the only places that have
to remember to. It is defined beside the pool writers rather than in `fnc_escalation.sqf` so the
purchase path does not depend on whether escalation ever started — with no multiplier published it is
the identity. It scales CP only: on a dual CP+AP price (the advanced supports) `fnc_pool_try_spend`
multiplies the CP half and leaves the AP half at face value, so escalation is a CP lever, not an AP one.

The multiplier is `publicVariable`d because the support list and the manual display it. Both append
the live figure from `fnc_support_cost_bracket` (`client/supports/fnc_supports_init.sqf`) to the
localised name, so a support's stringtable label holds no price in any language. A price baked into a
label is a second price, and it goes stale the first time the catalogue changes.

`fnc_escalation.sqf` sets the multiplier from a level ladder: a level is a fixed count of ruined
houses — a fifty-third of the map's house census split into eleven levels, so thirty houses on Altis
— and each level adds 0.1 to the multiplier. Level 11 is the ceiling, and it ends the campaign:
`campaign_lost` with the `island_ruined` ending.

The `DUWS_LoseConditions` parameter (default Full) says whether that ending fires; the other
campaign ending it covers is the commanding officer's death (`server/init_hq/fnc_BluHQinit.sqf`).
Where escalation is not a lose condition the level clamps at the ceiling instead, so prices plateau
at x2.1 and the war continues. Where the officer's death is not one, it costs the request menu
instead: `client/dialog/fnc_request_menu.sqf` refuses to open once he is dead, so a campaign that
survives him can spend nothing. Both events raise a red card for the team under every setting, so a
campaign that survives one still reports it. Escalation itself is switched off elsewhere, by the
`escalation_enabled` environment-menu option.

## Supports: permanent and consumable

One catalogue, `fnc_support_catalogue` in `client/supports/fnc_supports_init.sqf`, holds every row of the
request menu's support list in display order, and the `PERM`/`CONS` column decides everything the two
mechanisms differ in:

| | Permanent (19 rows) | Consumable (18 rows) |
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
deliveries: each still charges per use, 10 CP a FOB, and the MHQ designation is an entry every
player keeps rather than a charge anyone spends, so team ownership costs nothing it was collecting
before.

Some consumable rows wait on a permanent one. `fnc_support_defs` hides the supply drop, the vehicle
drop, the helicopter taxi, the heavy heli vehicle transport and the boat taxi until the team owns
`logistics` (Logistical Supports, 10 CP). It hides the mortar and the mortar smoke until the team
owns `offensive_light` (Light Supports, 10 CP and 10 AP). It hides the JDAM, the laser-guided
bomb, the artillery, the cluster bomb, the napalm and both High Command air rows until the team owns
`offensive_heavy` (Heavy Supports, 25 CP and 30 AP). It hides the Mobile HQ designation until the
team owns the Mobile HQ. It hides the rally point from any player outside `Squad_Leaders`.

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

**It refunds unlocks, never uses.** A consumable is one use, paid at purchase. Calling it costs
nothing more, and `fnc_support_consume` clears its flag and its recorded charge, so a used support has
nothing left to refund. Only two calls charge again: a FOB deploy (10 CP) and a vehicle drop (the
vehicle's own price, from `DUWS_fnc_vehPrice`).

**A support that is not in hand cannot be refunded.** The comm-menu classes with
`removeAfterExpressionCall = 1` are absent from the player's menu for as long as their mission is
running, and `fnc_supports_init` tracks presence for its own reasons
([`arma_engine_gotchas.md`](../architecture/arma_engine_gotchas.md#a-comm-menu-item-id-goes-stale-the-moment-the-item-is-used)),
so that one test covers a fire mission in flight, a taxi in transit and a High Command aircraft in
the air without a guard per support.

Both constants are in `server/server_var_init.sqf` and broadcast because clients read them:
`support_max_slots` (8) and `support_death_refund` (0.5, a share of both currencies). The death share
is half so that walking an item back to a base still beats dying with it — a bigger share makes dying
a cheaper way to liquidate a slate, which inverts what the death penalty is for.

## Faucets

| Source | File | Amount |
|---|---|---|
| Zone first capture | `server/init_zones/fnc_captured.sqf:37-43` | once ever per zone: `zone_first_capture_cp` (25) CP + `zone_first_capture_ap` (50) AP; the AP credits BLUFOR's tier |
| Zone recapture | `server/init_zones/fnc_blufor_cap.sqf` | nothing — a zone's reward is earned once, so trading it back and forth is not a faucet |
| Zone hold (AP trickle) | `server/warcom/fnc_zonesundercontrol.sqf:71-87` | AP each side: `zones_held × zone_ap_trickle` (5), throttled, every 30 min; credits that side's tier |
| Town income | `server/warcom/fnc_zonesundercontrol.sqf:44-81` (`fnc_civ_townIncome`) | each banded town's worth (1–5 by size, `civ_town_ap`) to its holder every 30 min, throttled — CP to a BLUFOR town, AP to an OPFOR one |
| OPCOM drip | `server/warcom/opcom/belief/fnc_opcom_perception_run.sqf` | AP to OPFOR: 1 every `OPCOM_AP_DRIP_TICKS` (2) OPCOM ticks, so every 10 s, while OPFOR holds every zone; `OPCOM_AP_DRIP_FLOOR` (0.5) of it is kept with no zone left; unthrottled, except that `OPCOM_AP_DRIP_TIER` (0.25) of it, throttled, credits OPFOR's tier |
| OPFOR capture consolation | `fnc_captured.sqf:48-51`, `fnc_blufor_cap.sqf:32-35` | AP to OPFOR on every BLUFOR capture: `worth × zone_ap_consolation` (0.15), wallet only |
| Zone-loss swing | `server/init_zones/fnc_opfor_cap.sqf:51-53` | AP: `worth × zone_ap_swing` (0.15) to OPFOR, the same figure removed from BLUFOR |
| Side-mission reward | `server/missions/fnc_mission_reward.sqf` | CP `reward × cp_reward_multiplier` (×1.5 when civs-off), plus a BLUFOR AP reward that credits the tier |
| Civilian side mission | `server/civ_missions/fnc_civ_mission_finish.sqf` | on the report: CP `reward × cp_reward_multiplier` (10, 5 or 15), 0-8 `Money_roll` into the reporter's inventory, at their feet if it does not fit, +3 or +5 reputation to the giver's town; no AP ([`side_mission_catalogue.md`](side_mission_catalogue.md#civilian-side-missions)) |
| Recruit rescued civilian | `server/civilian/fnc_recruit_civilian_server.sqf` | +5 (+8 in WBK mode) |
| Intel analysis (terminal) | `server/search/fnc_intelAnalysis.sqf` | per document, always paid: 1 CP (`MobilePhone`/`Wallet_ID`), 2 (`SmartPhone`), 3 (`FlashDisk`), 4 (`Files`), 5 (`FilesSecret`/`FileTopSecret`); each also rolls a per-item chance to reveal one hidden position. A turn-in made before a pending award lands joins that award, so one card pays the batch with ≤1 reveal |
| Enemy corpse loot | `server/search/fnc_addRandomLoot.sqf` | ~60% of enemies carry 0–2 `Money_roll` (personal cash); intel documents no longer dropped here |
| Bandit corpse loot | `server/bandits/fnc_bandit_spawn.sqf` | every bandit carries 0–5 `Money_roll`, less when the inventory is full |
| Search payout (`pool` kind) | `server/search/fnc_search_claim.sqf` | +1–3 CP, on a flagged body or objective whose payout draw lands on `pool` |
| Vehicle recycle | `server/supports/fnc_activateBaseRecycleStation.sqf` | `DUWS_fnc_calculateVehicleValue` per empty vehicle, summed then rounded |
| Kill income | `server/server_init.sqf:275-361` | +1 per 10 hostile kills, swept on the economy tick; the remainder carries |
| Killhouse training | `server/killhouse/fnc_createKillhouse.sqf:306-307` | +1 for clearing 10 targets, or +3 for clearing 20 challenge enemies, once per run |
| Rare-zombie kill (WBK) | `server/civilian/fnc_civ_handler_wbk.sqf:359` | +10, or +30 for the Goliath |
| Support refund | `client/supports/fnc_supports_init.sqf` | the recorded charge in full; `support_death_refund` of the slate when its holder dies |

**A zone's worth is one figure now, not two.** `_points` (the worth) rides the capture triggers —
`fnc_createzone.sqf:280` → `fnc_captured.sqf` → `fnc_opfor_cap.sqf` → `fnc_blufor_cap.sqf` — as
argument 2, is set from the zone's radius at generation and stored in `zone_meta_array`, and is never
reassigned: a zone swings the same AP however often it changes hands. The old per-capture CP *bounty*
(argument 7, `worth × zone_cp_capture` decaying by `zone_cp_recapture`) is retired with the town→CP
reroute — the three cap handlers still read the 7th arg to keep one trigger signature, but it is
passed `0` and no CP rides a capture. A zone's CP is now the one-time liberation bonus at its first
capture; everything else it drives is AP.

What worth drives, all tuned in `server/server_var_init.sqf`: the OPFOR AP swing on a BLUFOR loss
(`zone_ap_swing`, the same figure removed from BLUFOR), and the OPFOR consolation on a BLUFOR capture
(`zone_ap_consolation`). Both are wallet-only shares of worth, and neither decays as the zone flips —
ground fought over repeatedly is no less strategically valuable, so its AP must not thin with it.

**The passive-hold loop is the campaign's single economy clock.** It is spawned exactly once
(`server/warcom/fnc_init_OPFOR_WARCOM.sqf:17`), so income does not stack per zone captured, and every
passive faucet — the zone AP trickle both sides, BLUFOR town CP, OPFOR town AP and kill income — is
paid from the same 30-minute iteration. Equal nominal periods are not one clock:
a suspended thread resumes when the scheduler reaches it, so separate loops accrue their own slop and
walk apart. No faucet is gated on holdings — a side with no towns or zones simply computes 0 from
them — because the enemy banking its towns while the player holds
nothing is exactly the case the town economy exists to model. A tick that pays BLUFOR from territory
hints every player a ledger readout (`server/warcom/fnc_ledger_hint.sqf`): the town
CP and zone AP taken, with each pool's total; the throttle cut as the subtitle when campaign size is
cutting the faucets; and each revealed town whose reputation rose, with BLUFOR's radio push and the
town's CP income if it is in the BLUFOR band. The readout leaves out OPFOR's side of the tick. Allseer
cues it on SUB-NET with a line that carries no figures, so the tick is not announced twice. Kill
income rides the same tick but is kept out of the readout and announced only to the player who earned
it: naming attrition in a campaign-wide report would advertise kill farming as an income route.

**OPCOM's drip is the one faucet off this clock.** The payout lands as one lump, and the commander
spends it within a minute, so for the rest of the period it could only bank or move free units.
The drip pays 1 AP every `OPCOM_AP_DRIP_TICKS` (2) OPCOM ticks while OPFOR holds every zone, which is
up to 180 AP per 30 minutes, and it stops while no human is connected, as the tick does.

**A quarter of the drip climbs OPFOR's tier.** The drip is most of what OPCOM earns, so if it all paid
the wallet only, OPFOR's tier would ride on the 30-minute payout alone. If it all credited
`WARCOM_opfor_ap_earned`, OPFOR would reach jets in under half the time the rungs were tuned for.
`OPCOM_AP_DRIP_TIER` (0.25) of each drip AP also credits the earned counter, scaled by
`DUWS_econ_throttle` as the payout's tier credit is, so a campaign past six zones does not climb faster
than a six-zone one. On six zones held, OPFOR's tier income is about 160 AP per hour at the ~7 s
ticks seen in play, which reaches armour in about 2.2 hours and jets in about 3.8.

**Half of the drip follows the ground.** `DUWS_fnc_opcom_dripRate` (`fnc_economy_init.sqf`) keeps
`OPCOM_AP_DRIP_FLOOR` (0.5) of the full rate whatever OPFOR holds, and scales the rest by the share of
the campaign's zones OPFOR holds. A capture must cost the commander income, but a commander down to
its last zone must still be able to buy units and fight back: on six zones, one zone left still pays
58% of the full rate. The perception loop carries the fraction of an AP, to the wallet and to the tier,
between ticks and pays each out whole, because `fnc_ap_adjust` keeps both counters whole.

Each iteration bumps `econ_tick`, the clock's sequence number. Anything wanting a "once per payout
window" cap keys off that rather than starting a timer of its own — `fnc_civ_healed.sqf` is the one
caller today, capping what a town can pay out for treating its wounded. Server-local and unbroadcast:
only server-side caps read it.

The Debug menu's Economy dialog has a *Fire economy tick* button that runs one extra iteration off the clock
(`server/debug/fnc_debug_econ_tick.sqf`), which keeps its own 30-minute schedule. It pays, bumps
`econ_tick` and hints every player like any other iteration, so a tick that pays BLUFOR nothing from
territory shows no readout.

## Sinks

| Category | Where | Cost |
|---|---|---|
| Support unlocks | `client/supports/fnc_supports_init.sqf` | CP 0–60 (Mobile HQ designation 0, the taxis 1 … Radio Tower III 60), plus AP 5–30 on the advanced rows (catalogue column 8); refundable if consumable, see [above](#supports-permanent-and-consumable) |
| Reinforcement units | `dialog/fnc_request_unit*.sqf` | 2–4 (from `blufor_RQST_UNIT_*`) |
| Vehicles | `dialog/fnc_request_vehicle*.sqf` | CP only today, from `DUWS_fnc_vehPrice` (`shared/functions/fnc_veh_price.sqf`): a kind band set by role, a heaviness score placing the vehicle inside it |
| Squads | `dialog/fnc_request_squad*.sqf` | per squad table |
| FOB deploy | `client/supports/fnc_request_fob.sqf` | fixed |
| Operatives | `client/operative/fnc_operator_recruit.sqf:20` | 8 (re-deploying a healed one is free) |
| Mobile HQ | `client/dialog/fnc_MHQ_select.sqf` | 10 |
| Heli / boat taxi | `supports/taxi/` | fixed |
| Base repair, HQ, FOB and zone redeploy | `server/supports/fnc_activateBaseRepairStation.sqf`, `server/init_hq/fnc_redeployHQUnits.sqf`, `fnc_redeployFOBUnits.sqf`, `server/init_zones/fnc_zone_build.sqf` | 2 / 2 / 2 / 2 |
| Garrison reinforce / fortify | `server/missions/fnc_map_readout_buy.sqf` | AP 10 / 15, OPCOM's own prices (`OPCOM_AP_REINFORCE` / `OPCOM_AP_FORTIFY`) |
| Death | `client/client_init.sqf:156,171` | `DUWSMP_CP_death_cost` (0–10), plus the holder's consumable slate |
| Raise Funds (money) | `server/civ_missions/fnc_civ_mission_give.sqf` | 9-15 `Money_roll`, pooled by the players at the giver; not refunded on a cancel or the giver's death |
| Vendor purchase (money) | `server/vendors/fnc_vendor_buy.sqf` | 1-7 `Money_roll` for gear, 1.2 per CP of the request-menu price for a vehicle; more on the OPFOR and Everything lists, less in a town with good reputation ([`civilian_shops.md`](civilian_shops.md#prices)) |

## Who may spend

Two permission lists of playable slot names, defined together at `server/server_var_init.sqf:225-258`
and checked as `(vehiclevarname player) in <list>`:

| List | Owns |
|---|---|
| `game_master` | campaign-level control — the setup flow, side-mission requests (`client/missions/fnc_stratmap.sqf:24`), the global heal |
| `Squad_Leaders` | everything that spends CP or AP — request menus, radio supports, MHQ, FOB and zone redeploy — plus High Command |

`Squad_Leaders` lists every playable slot as shipped, so it restricts nothing today. It exists to be
trimmed: on a dedicated server, cutting it to the real squad-lead slots restricts all of the above in a
single edit.

That only holds while **nothing outside a permission check reads it**. Personal kit — the medic,
engineer and UAV traits — is granted unconditionally at `client/client_init.sqf:202-204` for exactly
this reason. Gating a *capability* rather than a *privilege* on this array would mean trimming it
silently removed revives from the rest of the team, with no error to point at.
