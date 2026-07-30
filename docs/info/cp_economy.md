# Command-point economy

Command Points (CP, the global `commandpointsblu1`) are the single currency the player
spends — on support unlocks, reinforcements, vehicles, FOBs, operatives, and transport.
Army Power (AP, `WARCOM_blufor_ap`) is a separate war-momentum score the WARCOM director
reads; it is not spent from menus. The two economies meet at one place: the AP→CP
converter (`fnc_convertAPtoCP.sqf`). This doc covers CP: where it comes from, where it
goes, and the balance properties worth knowing. Faction-specific purchase prices live in
the `blufor_RQST_*` variables and `fnc_evalVehicleCost` — see
[`faction_system.md`](faction_system.md).

## Authority: one server-side writer per pool

`commandpointsblu1` is a networked global, so every change routes through a single
server-side function, `fnc_cp_adjust` (`src/duws/server/server_fnc_init.sqf`), invoked as
`[delta] remoteExec ["fnc_cp_adjust", 2]`. Callers send a signed *delta*; nothing else
assigns or `publicVariable`s the pool, and the result is floored at 0 — the purchase gates all
ask *"can I afford this"*, so a negative pool behaves like an empty one and the floor only
keeps the HUD honest. The writer also **rounds the running total**, which is what makes CP an
integer currency: the HUD prints the pool raw, so any fraction reaching it renders as `32.05`.
Rounding the total rather than the delta additionally normalises a pool that already holds a
fraction. A caller that wants to pay out sub-point amounts must therefore accumulate whole
points itself — the writer would swallow a `0.05` delta silently, so it logs one to the RPT
instead. This is a hard concurrency requirement, not a style
choice: mutating a networked global as `x = x - c; publicVariable "x"` from a client drops
concurrent co-op changes and can duplicate CP — see the gotchas entry *"A shared global
mutated as `x = x - c; publicVariable` loses concurrent writes"* in
[`arma_engine_gotchas.md`](arma_engine_gotchas.md). The only absolute assignments left are
the pre-game starting value (`server_var_init.sqf:85`, default 20; campaign menu offers
0–400 in `fnc_process_campaign_menu.sqf:210-218`), which run on the host before play.

Army Power carries the same contract. `fnc_ap_adjust` (same file) is the sole writer of both
`WARCOM_blufor_ap` and `WARCOM_opfor_ap`, invoked as `[side, delta] remoteExec
["fnc_ap_adjust", 2]` with side `"BLU"` or `"OPF"`; its pre-play absolutes are
`server_var_init.sqf:178-179`, `fnc_WARCOM_init.sqf:22-28`, and the campaign-menu presets in
`fnc_process_campaign_menu.sqf:277-348`. Both pools floor at 0 as CP does; losing a zone sheds
the same AP swing that taking one pays, so an unclamped pool could sit deeply negative, and every
WARCOM wave threshold reads *"above N"* anyway. Two deliberate differences from `fnc_cp_adjust`: an
unrecognised side drops the delta and logs it rather than crediting the wrong pool, so a bad
call shows up in the RPT instead of corrupting a pool or throwing; and there is no display
refresh, because AP has no HUD counter and no `publicVariableEventHandler` — which is why
`fnc_convertAPtoCP.sqf` paints control 1002 from its own expected post-spend total instead of
re-reading the pool, whose local copy is still pre-spend at that point.

**Reputation is territory, and `fnc_town_rep_adjust` is its only writer.** It follows the same
contract with one addition: the writer owns the rounding as well as the write. Reputation is the
only pool taking fractional deltas (`+0.5`, `-1`), so callers send a plain delta and never
normalise, or two of them would round differently; the writer snaps to two decimals, zeroes
anything below `0.01`, and clamps each town to `[-20, 20]`.

There is no campaign-wide figure to sum into. Every caller resolves its town through
`fnc_civ_townAt`, which answers `-1` for open country, a civilians-off campaign and RAVAGE/WBK
alike, and a `-1` delta is dropped: harm done where no town can see it costs nothing. Consumers
that only need a number read `fnc_civ_repAt`, which answers neutral for the same three cases —
a consumer that has to tell "neutral" from "not modelled" reads `civ_town_rep` directly, the way
`fnc_civ_townQuery` and `fnc_sitrep_fanout` do.

**No call site prints a reputation total, and neither does the map.** A caller computes its figure
before the write lands, and the clamp means the writer may apply less than was asked, so any number
a caller names is a prediction. A town's standing reaches the player as marker *colour* alone —
`fnc_civ_townRender` sets colour and alpha, the markers are created without text
(`fnc_civ_init_Tomata.sqf:262-279`), and `civ_town_rep` is never broadcast. SITREP prints the
standing of the town the reading player is stood in, resolved per player by `fnc_sitrep_fanout`
because that array never leaves the server.

## Authority: the server decides a purchase, not the buyer

Owning the arithmetic is not the same as owning the decision. A client testing
`commandpointsblu1 >= cost` against its own copy is reading a broadcast snapshot that is a
network round trip out of date, so two players buying at once both pass a gate the pool funds
once. The debits are then applied in full and the floor absorbs the overshoot, which makes the
second purchase free.

Every purchase therefore routes through a request/reply handshake, both halves in
`server/server_fnc_init.sqf`. `fnc_pool_spend` runs on the buyer, sends the request and blocks;
`fnc_pool_try_spend` runs on the server, tests and debits as adjacent statements against the
one server copy, and replies with the verdict. Call sites read as a guard clause:

```sqf
if !(["CP", _cost] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};
```

Three properties are load-bearing:

- **The debit is `call fnc_cp_adjust`, not `remoteExec [..., 2]`.** Even on the server,
  remoteExec queues a scheduled job for a later frame, which would split the test from the
  debit and reopen the gap. The same applies to the server-side purchase paths that never used
  the handshake — `server/misc/fnc_redeployHQUnits.sqf`, `server/supports/fnc_activateBaseRepairStation.sqf`,
  `server/supports/fnc_uav_scanner.sqf`, `fnc_pylon_set_with_cost`.
- **The caller blocks, so it must be scheduled.** `waitUntil` throws in unscheduled code. Every
  purchase entry point is `spawn`ed today — the dialog `action =` fields, the comm-menu
  `expression =` fields, `addAction` bodies — so any new one must be too.
- **A timeout refuses.** Silence must not let an effect through. It logs, because a dropped
  reply is otherwise indistinguishable in-game from a genuine refusal.

Three client-side comparisons survive as *advisory* pre-filters, and are commented as such:
`client/supports/fnc_mapclickarty.sqf`, `client/supports/fnc_mapclickuav.sqf`,
`client/misc/fnc_addRedeployAction.sqf`, plus the opening check in `client/supports/fnc_request_fob.sqf`.
Each spares the player a wait — a 45 s map-click window, a 10 s site survey — that they
provably cannot pay for. None of them decides anything; the charge happens later, on the
server, against a balance the pre-filter's read has long since stopped describing.

Where a comm-menu support passes `_cost = 0` the charge already happened at unlock time, so the
handshake short-circuits and the site is left alone: `client/dialog/fnc_MHQ_select.sqf` and both taxis
in `supports/taxi/` spend nothing.

## Escalation scales every price

`fnc_escalation_cost` (`server/server_fnc_init.sqf`) multiplies a base cost by
`escalation_multiplier` and rounds up, so a scaled price is never cheaper than the base one.
`fnc_pool_try_spend` applies it on entry, which covers every `fnc_pool_spend` site at once; the
four paths listed above as handshake exceptions each apply it themselves, and are the only
places that have to remember to. It is defined beside the pool writers rather than in
`fnc_escalation.sqf` so the purchase path does not depend on whether escalation ever started —
with no multiplier published it is the identity.

The multiplier is `publicVariable`d because the request menu displays it. Base costs are baked
into each row's stringtable label (`"Supply Drop (5CP) Radio"`), so
`client/dialog/fnc_HQ_Request_Menu.sqf` appends the scaled figure rather than substituting it,
against a cost table it keeps for that purpose. Stripping the numbers out and re-formatting from
a `%1` placeholder is the tidier shape and is rejected on localisation grounds: a placeholder
added to English but not to the other four languages leaves them printing the stale baked
figure, which is a wrong number rather than an untranslated one.

## Faucets

| Source | File | Amount |
|---|---|---|
| Zone capture (first time) | `server/init_zones/fnc_captured.sqf:46` | the zone's bounty — ≈50 for a 1000 m zone |
| Zone recapture (after loss) | `server/init_zones/fnc_blufor_cap.sqf:61` | the bounty as decayed by prior captures — ≈17, then ≈6, … |
| Passive territory hold | `server/misc/fnc_zonesundercontrol.sqf:54-56` | `zones_held × 6`, every 30 min |
| Side-mission reward | `server/missions/fnc_mission_reward.sqf` | `reward × cp_reward_multiplier` (multiplier default 1) |
| Town Army Power | `server/misc/fnc_zonesundercontrol.sqf:32-46` | AP, not CP: each banded town's worth of 1–3 to whichever side holds it, every 30 min |
| Recruit rescued civilian | `server/misc/fnc_recruit_civilian_server.sqf` | +5 (+8 in WBK mode) |
| Intel analysis (terminal) | `server/misc/fnc_intelAnalysis.sqf` | 1.5–8 per item; `FileTopSecret`/`FilesSecret` = 8 |
| Enemy corpse loot | `server/misc/fnc_addRandomLoot.sqf` → analysis | ~80% of enemies carry 0–2 of Money/Files/Wallet |
| Corpse search | `client/misc/fnc_corpse_search_action.sqf` | 20% chance of +1 CP (+1 AP) per corpse |
| Vehicle recycle | `server/supports/fnc_activateBaseRecycleStation.sqf` | `DUWS_fnc_calculateVehicleValue` per empty vehicle, summed then rounded |
| Kill income | `server/server_init.sqf:257-276` | +1 per 10 hostile kills, swept on the economy tick; the remainder carries |
| Killhouse training | `server/misc/fnc_createKillhouse.sqf:1072` | +1 (targets) or +10 (challenge), once, on clearing all 100 |
| Rare-zombie kill (WBK) | `server/misc/fnc_civ_handler_wbk.sqf:359` | +10, or +30 for the Goliath |
| AP→CP conversion | `client/dialog/fnc_convertAPtoCP.sqf` | 15 AP → 10 CP, one-way |

**A zone carries two figures, and they behave differently on purpose.** Both ride the capture
triggers — `fnc_createzone.sqf:280` → `fnc_captured.sqf` → `fnc_opfor_cap.sqf` →
`fnc_blufor_cap.sqf` and round again — as arguments 2 and 7:

| Figure | Set by | Behaviour |
|---|---|---|
| **Worth** (`_points`) | zone radius at generation, also stored in `zone_meta_array` | Never reassigned. AP is measured against it, so a zone swings the same momentum however often it changes hands |
| **Bounty** (`_bounty`) | `round(worth × zone_cp_capture)` at generation | The CP the next capture pays. Multiplied by `zone_cp_recapture` on every capture, so it decays as the zone flips |

The split is the design: ground fought over repeatedly has been looted already and should stop
being a payday, but it has not become less strategically valuable, so the AP swing must not
decay with it. Tuning constants are grouped in `server/server_var_init.sqf` — `zone_cp_capture`,
`zone_cp_recapture`, `zone_ap_swing`, `zone_ap_consolation`.

Losing a zone pays no CP, so `fnc_opfor_cap` passes the bounty through untouched; only a capture
decays it. Once it rounds to 0 the CP award and its notification are skipped rather than
announcing a payday of nothing.

Deriving both from one variable is what the earlier code did, and it compounded around the
ownership loop: a contested zone decayed toward paying nothing in *either* currency while
`zone_meta_array` still recorded its original worth.

The passive-hold loop is spawned exactly once (`server/warcom/fnc_init_OPFOR_WARCOM.sqf:20`), so
territory income does not stack per zone captured. It is also the campaign's single economy
clock: territory CP, town AP and kill income are all paid from the same 30-minute iteration.
Equal nominal periods are not one clock — a suspended thread resumes when the scheduler reaches
it, so separate loops accrue their own slop and walk apart. The tick reports itself in one
Overlord line carrying the territory take, CP and AP. Kill income is paid on the same tick but
kept out of that figure and announced only to the player who earned it: naming attrition in a
campaign-wide report would advertise kill farming as an income route. Only the territory CP is
gated on `zoneundercontrolblu > 0` — AP pays unconditionally, since the enemy banking its towns
while the player holds nothing is the case the town economy exists to model.

Each iteration bumps `econ_tick`, the clock's sequence number. Anything wanting a "once per
payout window" cap keys off that rather than starting a timer of its own — `fnc_civ_healed.sqf`
is the one caller today, capping what a town can pay out for treating its wounded. Server-local
and unbroadcast: only server-side caps read it.

## Sinks

| Category | Where | Cost |
|---|---|---|
| Radio-support unlocks | `client/dialog/fnc_request_support.sqf` | 5–25 (supply 5 … CAS/CAP 25) |
| Reinforcement units | `dialog/fnc_request_unit*.sqf` | 2–4 (from `blufor_RQST_UNIT_*`) |
| Vehicles | `dialog/fnc_request_vehicle*.sqf` | 5–100 (from `fnc_evalVehicleCost`, clamped) |
| Squads | `dialog/fnc_request_squad*.sqf` | per squad table |
| FOB deploy | `client/supports/fnc_request_fob.sqf` | fixed |
| Operatives | `client/operative/fnc_operator_recruit.sqf:29` | 8 (re-deploying a healed one is free) |
| Mobile HQ | `client/dialog/fnc_MHQ_select.sqf` | 10 |
| Heli / boat taxi | `supports/taxi/` | fixed |
| Base repair, HQ and FOB redeploy, sitrep | `server/supports/fnc_activateBaseRepairStation.sqf`, `server/misc/fnc_redeployHQUnits.sqf`, `fnc_redeployFOBUnits.sqf`, `server/supports/fnc_sitrep_support.sqf` | 2 / 2 / 2 / 1 |
| Death | `client/client_init.sqf:194` | `DUWSMP_CP_death_cost` (0–10) |

## Who may spend

Two permission lists of playable slot names, defined together at
`server/server_var_init.sqf:225-258` and checked as `(vehiclevarname player) in <list>`:

| List | Owns |
|---|---|
| `game_master` | campaign-level control — the setup flow, side-mission requests (`client/missions/fnc_stratmap.sqf:24`), the global heal |
| `Squad_Leaders` | everything that spends CP — request menus, radio supports, MHQ, FOB redeploy — plus High Command |

`Squad_Leaders` lists every playable slot as shipped, so it restricts nothing today. It exists to
be trimmed: on a dedicated server, cutting it to the real squad-lead slots restricts all of the
above in a single edit.

That only holds while **nothing outside a permission check reads it**. Personal kit — the medic,
engineer and UAV traits — is granted unconditionally at `client/client_init.sqf:199-201` for exactly
this reason. Gating a *capability* rather than a *privilege* on this array would mean trimming it
silently removed revives from the rest of the team, with no error to point at.

## Balance concerns

Open observations from an economy review. Each is a design or correctness property, not a
crash; none is currently scheduled.

**Territory income snowballs with no upkeep.** Passive hold pays `zones_held × 6` every
30 min (`fnc_zonesundercontrol.sqf:55`) on top of lump capture rewards, and holding a zone
costs nothing thereafter. That is a positive feedback loop — hold → CP → buy → hold more —
with no attrition pulling the other way, so late-game CP outruns anything to spend it on.
This is the central design lever, not a bug: if a demanding economy is the goal, the levers
are per-zone/garrison upkeep, diminishing per-zone passive scale, or a CP cap. Paying it in AP
instead was considered and rejected — a holdings-scaled AP faucet feeds the escalation ladder,
and the enemy starts holding the map ([`../ap_economy_plan.md`](../ap_economy_plan.md)).

**Enemy-loot → intel-analysis is an unbounded, cooldown-free faucet.**
`fnc_addRandomLoot.sqf` puts `Files` (2 CP) / `Wallet_ID` (1.5 CP) on ~80% of spawned
enemies, and terminal analysis (`fnc_intelAnalysis.sqf`) converts them with no cap and no
cooldown; HVT missions add `FileTopSecret` at 8 CP each. Because a zone re-garrisons every time it
is left and re-approached, and patrols keep spawning, this taps ≈1 CP per kill scaling with playtime
rather than difficulty. A per-visit cap or a cooldown on the terminal action bounds it.

**Recycle pays for vehicles the player never bought.**
`fnc_activateBaseRecycleStation.sqf:88-101` deletes every empty, non-excluded vehicle near
the HQ pad and credits its computed value with no ownership check — captured or found
vehicles convert to free CP. It is *not* a buy-then-recycle loop: purchase cost
(`fn_factionAutoDetect.sqf:161`, clamped `[5,100]`) always exceeds recycle value
(`DUWS_fnc_calculateVehicleValue`, small and uncapped), so buying to recycle always loses.
The two formulas are simply not on the same scale, and recycle has no floor tying reward to
what a vehicle cost.

**AP is a threshold ladder with almost nothing spending it, so town income is inflationary.** The
WARCOM director reads it as gates — BLUFOR wave tiers at 10, 40, 65, 100 and 136
(`fnc_WARCOM_blu_assault.sqf:11-25`), OPFOR air above 150 (`fnc_WARCOM_opf_air.sqf:11`), OPFOR
patrols above 100 (`fnc_missionPatrols.sqf:18`) — and the only subtractions are losing a zone and
the AP→CP converter below. Turning it into a currency both sides spend, without breaking the
ladder, is [`../ap_economy_plan.md`](../ap_economy_plan.md). A 20-town campaign averaging 2 AP
pays at most 40 AP per 30 min with every town banded, against 25 for capturing a 500 m zone and
50 for a 1000 m one — worth is `round(radius/10)` (`fnc_locatorzones_random.sqf:56`), halved by
`zone_ap_swing`. So at its ceiling civilian income substitutes for a capture rather than
supplementing one; how far below that ceiling a real campaign sits is the untested part. The
ladder only goes up, so escalation is permanent once earned; the 1–3 scale sets how long it
takes.

**The two routes into a band are not symmetric, and the negative one is far shorter.** Both
bands sit ten points from neutral, but the travel costs are nothing alike. Going negative is
incidental and cheap: a civilian death at `-1`, charged three times in ten and only with a
player inside 200 m, is about thirty-three kills; a building at `-2` under the same proximity
guard gets there in five, with no rate roll at all; a failed IDAP at `-5` covers half the
distance alone. Going positive is deliberate and slow: healing is worth `+1` but caps at one
credit per town per economy tick (`fnc_civ_healed.sqf`), so the BLUFOR band is hours of visits
away on healing alone, against IDAP success at `+5`.

That gap is the mechanic rather than an oversight. Ordinary fighting drags a town toward the
enemy and no amount of ordinary fighting drags it back, so the routes out of the OPFOR band are
the ones built for it: clearing the garrison, which discharges the debt at once, and the aid
missions. The rate roll on deaths can sit as low as 30 % precisely because reputation is
localised — a bad engagement costs the campaign nothing outside the town it happened in.
Deliberate demolition carries no such excuse, which is why it is charged every time.

**AP→CP merges the two economies.** `fnc_convertAPtoCP.sqf` trades 15 AP → 10 CP,
repeatable with no cooldown. It is one-way (there is no CP→AP path), so it cannot loop, but
it means any AP income route — mission rewards, corpse search — ultimately feeds CP.
