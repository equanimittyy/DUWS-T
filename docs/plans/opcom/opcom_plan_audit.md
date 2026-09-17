# Audit: opcom_plan.md

A full-document review of [`opcom_plan.md`](opcom_plan.md) and its Phase 4a spec
[`phase_4_decision_loop.md`](phase_4_decision_loop.md), cross-checked against the shipped code under
`src/duws/server/warcom/opcom/`. It tracks what the plan still has to settle; each item folds into the plan
once it is decided.

## Verdict

**The mechanism is sound; the Phase 4a scoring is decided but not yet folded into the plan.** Perception is strictly separated from
truth, state is serialisable by construction, locality and no-retreat follow documented engine gotchas, and the
phase order is forced by read dependencies. Phases 1–3 (perception, force weighting, tasking / movement / ferry)
ship and match the plan's Shipped table, except the contested draw-lock
([below](#plan-out-of-step-with-code)); the Phase 3 live playtest is pending.

The score's shape (`archWeight × P(win) × Value / Cost`, Value and Cost both in AP) holds, but several Value and
Cost definitions broke it, and the Phase 4a spec leaned on prices, wrappers and a candidate table that did not
exist. Every item below is now decided, the prices as first-pass defaults; what remains is folding the decisions
into the plan and the Phase 4a spec.

## Vocabulary

Two terms, each with one meaning.

| Term | Applies to | Meaning |
|---|---|---|
| **Contested** | a zone or a town | BLUFOR are assaulting the site: OPFOR belief holds a BLUFOR sighting within one grid cell (K=1) of its edge. The set is rebuilt once per tick (`fnc_opcom_contested.sqf`, read through `DUWS_fnc_opcom_zoneContested`). Built for zones only: the rebuild sweeps the `zone_` sites and skips the `town_` sites (`fnc_civ_garrison.sqf:75`) |
| **Engaged** | a unit | The unit is live and fighting BLUFOR: its leader is in `COMBAT`, or knows the nearest player above 1.5 (`fnc_opcom_task_step.sqf:69-77`). Built. A virtual unit is never engaged |

A zone or a town is never engaged. When this folds into the plan, the two rows go at the head of §Shipped and
replace the inline definition of contested at `opcom_plan.md:47`. The plan's other loose uses change too:
"the contested towns" (`opcom_plan.md:254`) becomes "the towns", and "uncontested economics"
(`phase_4_decision_loop.md:30`) becomes "economics".

## Blocking — Phase 4a

- **Defensive Value is not in AP and reads the wrong signal.** Build, Reinforce and Fortify multiply worth by
  threat (`opcom_plan.md:134-137`). Threat is `_ene`, a force magnitude, so Value comes out in AP × force (AP ×
  force² for Fortify); and threat shifts tick to tick, while the truck runs and tier buys it would drive take
  minutes and stand for the campaign. Decided:
  - Threat drives only the fast actions: Intercept (QRF) and attack staging. Build, Reinforce and Fortify never
    read it.
  - Defensive Value = **worth × exposure × gain**, all read from slow state:
    - **worth** is the holding's fixed AP worth. A zone's is `_points`, its radius ÷ 10 (35–50 at the default
      radii). A town's is its level `civ_town_ap` (1–5, a rank by building count within the campaign's towns,
      `fnc_civ_init_Tomata.sqf:199`, the same figure its income pays) × a tunable 5, so 5–25: always below a zone.
    - **exposure** (0–1) is how close the holding sits to BLUFOR-held ground. OPCOM knows the owner of every zone
      and town for free, a territorial fact like the grid's nominal BLU-zone deposit, so exposure moves only when
      ground changes hands. Exposure is 1 within 5 km of BLUFOR-held ground and falls in a straight line to a
      floor of 0.2 at 10 km (tuning values).
    - OPCOM holds the player HQ's position from the start behind a hidden flag, and a hidden HQ counts toward
      nothing. The first sighting of a BLUFOR group within K = 2 cells of the HQ flips the flag for good, and the HQ
      counts as BLUFOR ground from then on. Every sensor writes through `fnc_opcom_belief_upsert`, so the flip
      check sits there once. BLUFOR holds no zone or town at campaign start, so exposure sits at its floor
      everywhere until the first capture or the HQ's reveal, and OPCOM defends evenly until then.
    - **gain** (0–1) is the force the purchase adds ÷ the force the holding fields at full strength and top tier.
  - Build splits by where the hardpoint stands:
    - A **zone hardpoint** is scored as above, with gain the emplacement's force share, gated by the zone's
      hardpoint cap (`fnc_hardpoint_zone_cap`), and placed by the existing in-zone draw. It builds on AP alone the
      tick it commits, with no supply truck. Nothing else constrains it.
    - A **standalone hardpoint** needs a supply truck and has no contested gate: it builds the moment its truck
      arrives, players near or not. It takes its own Value from coverage of the whole map, not
      of any one zone: weighted toward OPFOR's holdings, and rewarding cover over sparse sectors between zones. A
      zone's ring already defends the zone. Two layers span every land cell; candidate sites are band cells only:
      - **need** (AP) is each OPFOR holding's `worth × exposure` spread over the 5 × 5 block around its cell
        (K = 2), with weights that fall with distance and are normalised so the block sums to exactly that
        figure. Every band cell also carries a flat base for the sparse sectors: a zone's average pull per cell
        (its worth ÷ 25) ÷ a tunable ratio starting at 2–3×, × the cell's exposure. A holding pulls harder than an
        open gap, but not so hard that hardpoints cluster around zones. Because the spread conserves worth, a
        first hardpoint at a frontline zone worth 40 earns about 10, beside that zone's Reinforce at 15.
      - **Asset hardpoints emit need.** A standing radio tower, artillery battery, mortar pit or OP spreads its
        build price (tuned later) over its 5 × 5 block the same way, so it becomes an asset worth
        protecting. Radios and OPs site out in the wilderness by their own placement logic, and the network of
        other hardpoints builds up around them; they are what drives cover into the gaps between zones. An asset
        never stands in a zone's ring, which fields only the offensive types it already rolls
        (`DUWS_hardpointWeightZone`: MG, AT, GMG, ROADBLOCK).
      - **cover** (0–1) is how well standing OPFOR hardpoints protect the cell, zone rings included. Each
        hardpoint within K = 2 cells (Chebyshev, a 5 × 5 block) covers half of what is left: 0, 0.5, 0.75, 0.875.
        Every hardpoint type shares that one reach.
      - A candidate cell's Value is the sum over its 5 × 5 block of need × the rise in cover the new hardpoint
        makes, so a hardpoint beside others earns little. `fnc_hardpoint_spawn_sited` then sites it within that
        cell. Both layers change only when a hardpoint is built or cleared, or ground changes hands.
  - When this folds into the plan, also fix `opcom_plan.md:231` and `:263-264` (Build targets and sites off
    threat), `phase_4_decision_loop.md:79` (`fnc_opcom_grid_read`; 4a no longer reads the grid) and `:246-247`
    (the verification expects a Fortify or Build answer to a believed BLUFOR build-up), and add the HQ flag to
    the [§Persistence](opcom_plan.md#persistence) contract.
- **The two docs disagree on the truck flow.** The plan counts a truck as on hand when one is idle *or affordable
  this tick* (`opcom_plan.md:252`), which makes hire and dispatch one commit. Phase 4a gates on a truck that
  exists, hires through a separate Recruit(supply) commit and dispatches on a later tick
  (`phase_4_decision_loop.md:156-165`), and its Rapport section hires inline as well
  (`phase_4_decision_loop.md:190`). Recruit(supply) is valued by the best delivery the gate dropped, so a gated
  delivery still needs its Value computed before the gate removes it.
  - Decided: the plan's flow. A supply-gated action takes an idle `supply` truck on hand, or hires one and tasks it
    in the same commit. It drops only when no truck idles and the wallet cannot cover both prices.
  - A truck is spent on delivery: it despawns once its errand lands, as the plan says. A truck killed en route
    fails its order with no refund.
  - The truck source is weighted: each candidate costs its acquisition (the hire price, or 0 for an idle truck on
    hand) plus a tunable AP-per-km term on its route to the target, and the lowest wins. An idle truck wins
    unless it is much farther than the nearest zone that can hire one. That source cost is part of the action's
    Cost.
  - A truck is also cheap infantry transport, so Recruit may hire one on its own; that hire is scored by the
    transport demand group, which lands in Phase 4b with land-taxi and the offensives that give a truck riders.
- **The zone-side garrison wrappers are missing from Phase 4a.** The plan lists them as not built
  (`opcom_plan.md:341-345`), but the Phase 4a file list omits them. Decided:
  - Phase 4a's file list takes both wrappers: one applies the reinforcement step to a zone key, one writes a zone's
    tier with a clamp and re-stamps the garrison's full potential (`DUWS_fnc_garrisonSetFull`), as a town tier buy
    does. Zone Reinforce, Fortify and hardpoint Build all resolve on AP alone the tick they commit, calling the
    zone wrapper or builder at once; only the town and standalone versions wait on a supply truck.
  - None of the three zone actions can be ordered while the zone is contested (`DUWS_fnc_opcom_zoneContested`);
    each drops from the candidates until the contest clears.
  - A town Reinforce or Fortify whose truck arrives while the town is contested still lands, through the garrison
    thread's existing hold: the strength or tier is owed at once, and the men arrive only once BLUFOR leave the
    arrival radius (`zones_and_civilians.md`, "Buying a tier and the men arriving are separate acts"). A town that
    falls first loses the purchase: clearing files it back to tier I (`fnc_civ_garrison.sqf:200`), and leaving
    the OPFOR band forgets the garrison.
  - When this folds into the plan, the supply-gated set becomes Rapport, standalone Build and town Reinforce /
    Fortify: fix `opcom_plan.md:249-254` and `phase_4_decision_loop.md:135-136`, `:168` ("Always supply-gated")
    and `:197-199`.
  - Fortify raises a zone's tier up to IV, whatever tier it rolled at generation; the roll decides only where a zone
    starts. Zones roll tier 1–4 weighted toward IV (`fnc_zone_tier_roll`), so zone Fortify pays mostly on the
    low-tier zones. Each tier also adds a hardpoint slot to the zone's cap (`fnc_hardpoint_zone_cap`), opening room
    for a zone Build.
  - When this folds into the plan, drop the open question at `opcom_plan.md:344-345`; its tier-cap half is
    answered here and its price half by [the cost sweep](#the-opcom-cost-sweep).
- **A standalone Build cannot site at chosen ground with the helpers Phase 4a names.** `fnc_hardpoint_seed_radio`,
  and `fnc_hardpoint_lay` with `fnc_hardpoint_band_anchor` / `_band_cand`, sample random band ground and take no
  target. The directed builder is `fnc_hardpoint_spawn_sited` (type and anchor, `fnc_hardpoint_place.sqf:184`); a
  zone Build keeps the existing in-zone draw.
  Every builder must run spawned — an emplacement registered near a player crews inline and sleeps
  (`fnc_hardpoint_place.sqf:212`) — so a build called straight from the tick stalls it: a standalone build from
  `fnc_opcom_deliver` in `fnc_opcom_task_step`, and a zone build at commit alike.
- **Build's type choice reads the wrong ladder.** Phase 4a picks the errand type `tower` / `band` / `topup` "by
  the earned-AP ladder" (`phase_4_decision_loop.md:169`), but those are siting modes; the plan's ladder unlocks
  weapon types, and keys them off 40 / 100 / 136 AP (`opcom_plan.md:271-276`, `:299`) where the economy now gates
  on `DUWS_ap_tier_rungs = 60, 150, 350, 600` (`fnc_economy_init.sqf:39`) through `WARCOM_opfor_tier`. Decided:
  - Once a Build has its zone or cell, the type is rolled from the existing weight table
    (`DUWS_hardpointWeightZone` or `DUWS_hardpointWeightSolo`), limited to the types OPFOR's tier has unlocked.
    Campaign generation still rolls from the full list.

    | Tier (rung) | Unlocks |
    |---|---|
    | 1 Infantry (0) | OP, MG, ROADBLOCK |
    | 2 Motorised (60) | + AT |
    | 3 Mechanised (150) | + GMG, AA, mortar pit |
    | 4 Armour (350) | + artillery battery |
    | 5 Jets (600) | nothing new |

  - Hardpoint garrisons stay fixed per type (`DUWS_hardpointGarrison`). The ladder's garrison column is dropped,
    not built.
  - When this folds into the plan, rewrite the ladder table and its notes (`opcom_plan.md:268-283`) and the
    indirect-fire unlocks (`:299`) on the tiers. Drop the garrison column, the "garrison column applies to all"
    note and the composition-table instruction. Drop the "build tick every 20–30 min" knob too, since no sink runs
    on its own clock.
- **The candidate enumeration table is gone.** The trim of the plan to the forward spec deleted the per-action
  "targets swept" table, but `phase_4_decision_loop.md:134` still sends the reader to it, and `:123` cites a loop
  description (score inside `isNil`, execute outside) that the plan no longer holds. Rapport's target is left as
  "a town in reach", with no reach defined. Decided:
  - Phase 4a's candidate table, rebuilt on this audit's decisions:

    | Action | Targets swept |
    |---|---|
    | Bank | one null |
    | Zone Reinforce | each uncontested OPFOR zone below full strength |
    | Zone Fortify | each uncontested OPFOR zone below tier IV |
    | Zone hardpoint Build | each uncontested OPFOR zone with a free hardpoint slot |
    | Town Reinforce | each OPFOR-band town below full strength and not regrouping |
    | Town Fortify | each OPFOR-band town below tier IV and not regrouping |
    | Standalone hardpoint Build | the band cells with the highest coverage Value |
    | Rapport | each town above −15 and below +10 that OPFOR's area of influence covers (`fnc_aoi_opfor_covers`) |

  - Rapport's Value favours a neutral town over one that is almost flipped either way. That reverses the plan's
    "progress the −3 step makes toward the −10 turn" (`opcom_plan.md:136-137`), which favours the nearly turned
    town. A town near −10 turns anyway on the free area-of-influence drift, and a −3 step barely moves a town
    near +10.
  - Rapport's Value is town worth × skew × 3/10, with skew = max(0.1, 1 − |rep| / 10). The 3/10 is Rapport's
    gain: a courier moves reputation 3 of the 10 points a flip needs, as a Reinforce step earns 0.3 of a zone. The skew is 1.0 at 0, 0.5 at
    ±5 and 0.1 from ±9 out, so a town between −10 and −15 scores at the floor. A town at +10 or more is
    BLUFOR-held (`fnc_civ_state_init.sqf:233`) and is not a Rapport target.
  - Phase 4a's loop description is its own (`phase_4_decision_loop.md:118-130`); drop the cross-reference to the
    plan at `:123`.

## The OPCOM cost sweep

The plan priced almost nothing OPCOM buys: Rapport spent only its truck (2 AP, a score of 3.75 against the 0.2–1
of a defensive buy), unit hires cost their combat force at 1 AP each (a tank 12, under ten minutes of income),
Reinforce and Fortify had no price, and hardpoints carried the retired director's flat errand prices. Decided, as
first-pass defaults that tune in play, against OPFOR's income of roughly 40–80 AP per 30 min
(`fnc_zonesundercontrol.sqf`) and the Values settled above:

| Purchase | Price |
|---|---|
| Unit hire | force × `OPCOM_AP_PER_FORCE`, raised from 1 to 2: truck 4, APC 8, IFV 18, tank 24, helicopter 30 |
| Zone Reinforce | the force the 0.3 step adds × `OPCOM_AP_PER_FORCE` |
| Zone Fortify | the force the next tier adds × `OPCOM_AP_PER_FORCE` |
| Town Reinforce / Fortify | as the zone versions, plus the truck's source cost |
| Zone hardpoint (MG, AT, GMG, roadblock) | the hardpoint's force (emplacement and fixed garrison) × `OPCOM_AP_PER_FORCE` |
| Standalone hardpoint | as a zone hardpoint, plus the truck's source cost |
| Radio tower | `OPCOM_AP_TOWER` 30, unchanged, plus the truck's source cost |
| OP / mortar pit / artillery battery | `OPCOM_AP_OP` 15 / `OPCOM_AP_MORTAR` 25 / `OPCOM_AP_ARTY` 50, plus the truck's source cost |
| Rapport | `OPCOM_AP_RAPPORT` 10 (the goods the courier carries), plus the truck's source cost |
| Truck source | the hire price (4), or 0 for an idle truck on hand, plus `OPCOM_AP_PER_KM` 0.5 × distance, so an idle truck up to 8 km away beats a hire |

- Pricing garrison force at the hire rate makes a zone or town buy score `worth × exposure ÷ (full force × rate)`
  whatever the step's size, about 0.5 at a frontline zone worth 40 with a full force of 40. A town fields less
  force, so it costs less than a zone without a separate price.
- A neutral level-5 town's Rapport scores 7.5 ÷ 14 ≈ 0.5, inside the defensive range instead of above it.
- One rate prices force everywhere, so the rise to 2 also doubles Arty's Value (`effForce killed × AP-per-force`)
  and `defenseAbandoned`'s rebuy cost.
- An asset hardpoint's own purchase Value is its build price × exposure, a stand-in that favours frontline assets
  until what a radio's reach, an OP's eyes and a gun's fire missions are worth is designed. Its need emission
  stays its build price.
- `OPCOM_AP_BAND` 12 and `OPCOM_AP_TOPUP` 8 retire, and `phase_4_decision_loop.md:107` stops reusing them.

## Plan out of step with code

- **The contested draw-lock is listed as shipped.** The Shipped table says a contested zone locks its garrison
  units off any offensive draw (`opcom_plan.md:47`). No code does: `DUWS_fnc_opcom_zoneContested` gates only the
  ferry pool, the freed hull's home pick and the garrison settle, and Phase 4a defers the lock to 4b. Decided:
  - One shared lock: a unit garrisoned in a contested zone (`DUWS_fnc_opcom_zoneContested`) is not drawable. A
    draw while BLUFOR close in unseen, before the zone is contested, is accepted.
  - The lock lands in Phase 4a, because taking an idle truck on hand draws it out of garrison. Each pool filters on it: the
    ferry pool (already inline at `fnc_opcom_ferry.sqf:47`), the 4a truck-source picker and the 4b offensive pool.
    The filter sits in the pool, not in `fnc_opcom_task`, because the source picker prices the truck into the
    action's Cost at scoring time.
  - When this folds into the plan, `opcom_plan.md:47` marks the lock as not built, and
    `phase_4_decision_loop.md:31`, `:60-62` and `:225` move the lock into 4a.
- **Phase 4a cites stale line numbers:**

| Cited | Now |
|---|---|
| `fnc_opcom_task_step.sqf:56-60,124-131` (supply stub) | `:79-85`, `:174-179` |
| `task_step:56` / `task_step:127` (delivery sites) | `:80` / `:175` |
| `task_step:39-41` (dead sweep) | `:58-60` |
| `fnc_opcom_task.sqf:52-58` (draw-lock) | no draw-lock; the lines strip a drawn garrison's reserve defender |
| `fnc_opcom_perception_run.sqf:16-39` (fault wrap) | `:17-67` |
| `fnc_createzone.sqf:129` (`selectRandomWeighted`), also cited at `opcom_plan.md:117` | `:117` |

## Resolved — Phase 3 (shipped)

The tasking-wiring phase is built and its plan-doc items are closed:

- **Router** shipped as **A\*** (octile heuristic, early exit on target, one search per tick); the plan says A\*.
- **Fast-airborne streaming gap** closed by a de-virt entry buffer
  ([§Shipped](opcom_plan.md#shipped-the-substrate-the-loop-drives)): a player must be within K on two
  consecutive ticks before a unit spawns live, so a jet crossing a ring never streams, whether or not a tick
  sample lands inside it. Recon detection keeps its single per-tick sample and the accepted blind spot
  ([§Open questions](opcom_plan.md#open-questions)).

## Remaining — deferred to a later phase

- **OPCOM's purchase valuation model:** the plan had no general model for valuing OPCOM's purchases against each
  other — unit hires, builds and spends alike — and unit hires had only a rule ("the best action that group
  unlocks", `opcom_plan.md:137`). Decided, as a first pass whose constants tune in play:
  - **Saving.** An unaffordable action is scored with the rest; the `Cost > wallet` gate
    (`opcom_plan.md:148-149`) no longer drops it before scoring. When the top scorer is unaffordable and its ETA,
    `(price − wallet) / income rate`, is inside `OPCOM_SAVE_HORIZON`, it is the savings goal and OPCOM banks that
    tick. An action that outscores the goal later, such as a QRF, still commits. An unaffordable action past the
    horizon drops out, and the weighted pick runs over the affordable top few as before. Without this, cheap
    actions spend every refill and a better, dearer action never becomes affordable. The horizon is per
    archetype: a patient commander saves longer.
  - **Recruit.** A specialist (`supply`, `transport`, `recon`) is worth only the Value of the best action
    blocked for want of it: a supply-gated action with no truck on hand, a Scout with no recon unit. A combatant
    is worth the larger of that demand and its home zone's defensive Value, since it joins the zone's reserve
    wave on hire (`fnc_opcom_garrison.sqf:14-15`). The defensive Value is Reinforce's `worth × exposure × gain`,
    with `gain = unitForce / (zone's current force + unitForce)` so each extra unit at one zone counts for less
    and exposure cannot stack a single zone without end. The larger, not the sum, because one unit serves one
    role at a time. Combatants therefore gather where exposure is high, and a QRF pool forms there with no
    roster table.
  - **One scale.** Every partial action multiplies its target's worth by its gain, the share of the full result it
    delivers, so Rapport takes the 3/10 step share ([candidate table](#blocking--phase-4a)): a neutral level-5
    town is worth 7.5, beside a frontline zone Reinforce's 15. Its courier fee ([the cost sweep](#the-opcom-cost-sweep))
    holds its score in the defensive range.
  - **The need field is in AP.** A holding's or asset's spread conserves its worth, and the field spans every land
    cell, so QRF and Scout can read it inside zones ([defensive Value](#blocking--phase-4a)).
  - **QRF.** Value = Σ need over the sighting's 5 × 5 block × min(1, sighting force ÷ (Σ `_fri` over its 3 × 3
    + 1)). The need is what OPFOR stands to lose there; the share is how much of the local defense the group
    can overwhelm, the fast threat signal the QRF is allowed. `P(win)` in the score says whether the QRF can win,
    so a platoon is worth stopping but a small QRF will not be thrown at it.
  - **Scout.** Value = Σ over the unique cells within the recon unit's K of its route of need × staleness ×
    `OPCOM_SCOUT_SHARE`. Staleness is min(1, ticks since the cell's last sweep in `DUWS_opcom_grid_seen` ÷
    `OPCOM_BELIEF_EXPIRE`). The share (a tunable, starting at 0.2) holds Scout below the ground it reveals,
    because scouting informs a later decision and takes or protects nothing itself.
  - **Delay.** Value that lands later counts for less: Value × 0.5 ^ (ETA ÷ `OPCOM_VALUE_HALFLIFE`), with ETA in
    ticks from the route length and the unit's per-cell speed (`DUWS_opcom_speed`). A zone action resolves the
    tick it commits, so its ETA is 0. The half-life is per archetype: a patient commander discounts less.
  - **No route-risk discount.** A truck's odds of dying en route would read `_ene`, the threat signal that never
    drives Build, Reinforce or Fortify. The risk stays with the player as counterplay: a killed truck fails its
    order with no refund.
  - **No emergency AP reserve.** A QRF stakes roster units, not AP, and Recruit's exposure term keeps combatants
    at the exposed zones, so OPCOM holds a QRF pool without banking AP for one.
  - When this folds into the plan, `opcom_plan.md:133-138` takes these Values and `:148-149` the savings goal.
- **`defenseAbandoned` threat term (Phase 4b):** the plan's "forfeits the Value it was covering"
  (`opcom_plan.md:141-143`) reads as a counterfactual grid rebuild per unit per candidate, which a 5 s tick
  cannot afford. Decided:
  - The term is read off the grid at the unit's home cell, with no rebuild:
    `homeWorth × min(1, 1 / r_home) × min(1, unitForce / fri_home)`.
  - `homeWorth` is the home zone's `_points`, and 0 for a unit that holds no zone. `r_home` is the 3×3 force
    ratio at the home cell, so a safe backline costs almost nothing to draw from and a threatened one costs its
    full worth. `unitForce / fri_home` is the share of the local OPFOR force that leaves; every tasking deposits
    its `effForce` at its position (`fnc_opcom_grid_rebuild.sqf:77-82`), and the cap covers a deposit that spreads
    past the 3×3 block.
  - A draw takes only OPCOM-recruited units, never the zone's base garrison, so the term prices a thinned zone,
    never an empty one. A `noncombat` unit covers nothing, so its term is 0, and so is every Phase 4a action's.
  - When this folds into the plan, `opcom_plan.md:141-143` states the formula.
- **Capture on an AI-only attack (Phase 4b):** the plan hands an Attack's capture to the zone trigger and asks
  that the trigger be verified for a fight with no player near (`opcom_plan.md:208-211`). The code rules it out:
  the `EAST SEIZED` trigger (`fnc_captured.sqf:72-74`) counts live units only, and every de-virt path spawns a
  tasking live only when a player is within K (`fnc_opcom_task_step.sqf:141`, `:152`, `:184`, and the ferry). A
  virtual attacker at a zone with no player near never trips it. Decided — a unit renders only when it has
  something to engage, every engagement runs live, and OPFOR flips a zone by the mirror of BLUFOR's rule:
  - A virtual tasking de-virts within K of any live BLUFOR group, player or not, and stays virtual while nothing
    is there to engage. It does not de-virt merely for reaching its target.
  - A live unit stows only when no player and no live BLUFOR group is within K, so it cannot flap between live and
    virtual beside an AI squad.
  - A BLUFOR-held site wakes when an OPCOM attacker, live or virtual, closes within K, not only for BLUFOR or air
    (`fnc_site_bluforOrAir`). Its purchased BLUFOR garrison renders, and those live BLUFOR render the attacker.
    BLUFOR buy garrisons for zones and towns as OPFOR do; they are not built (`opcom_plan.md:344-348` covers only
    towns).
  - OPFOR take a zone by the mirror of `fnc_zone_capture_ready`: the zone's BLUFOR garrison is beaten, and live
    OPFOR outnumber live BLUFOR in the radius. A zone with no purchased garrison counts as beaten. The mirror
    replaces `EAST SEIZED` at the two sites that re-arm the retake trigger (`fnc_captured.sqf:72`,
    `fnc_blufor_cap.sqf:56`), and `zones_and_civilians.md:297-299` changes with it.
  - The contact report needs no new code for zones: a live attacker inside the radius trips the zone's
    `EAST PRESENT` trigger and `fnc_enemy_contact`. Towns have no contact trigger; the plan's Attack targets zones
    only.
  - A BLUFOR zone with no garrison and no BLUFOR near renders nothing, so a virtual attacker there trips neither
    the retake trigger nor the contact report. OPCOM evaluates the same mirror rule on the tick against stored
    state, counting a virtual attacker's force in the radius as OPFOR present, and calls `fnc_opfor_cap` when it
    holds. It sends `fnc_enemy_contact` itself when a virtual attacker arrives.
  - An attacker that takes a zone garrisons it once virtual: a live attacker guards the zone until it stows, so it
    never vanishes in front of a player. A retaken zone restarts on a thin 0.3 garrison (`fnc_opfor_cap.sqf`), so
    the unit that took it becomes its defender and joins its reserve wave. The retake takes no hold: a zone flips
    with players still inside it.
  - Order: 4b builds the de-virt, the no-stow rule, the mirror (with the no-garrison case) and relies on the
    contact report; the BLUFOR garrison work adds the site wake and the garrison ledger the mirror reads.
  - When this folds into the plan, `opcom_plan.md:46` takes the target and live-BLUFOR de-virt, `:208-211` takes
    the mirror rule and drops the verification note, and `:344-348` covers BLUFOR zone garrisons too.
- **Muster livelock (Phase 5):** a player who keeps reinforcing keeps raising the muster bar
  (`opcom_plan.md:172-176`), and nothing ends the muster — the plan has no abandon rule. Decided — a muster
  has a force ideal, a force minimum and an expiry, all read as the force ratio `r` over the target:
  - The ideal is 3:1. A muster launches the tick its bound force reaches it.
  - The minimum is 1:1. At `OPCOM_MUSTER_EXPIRY` ticks, a muster at or above the minimum launches, and one below
    it is abandoned: its units return to rest.
  - Both ratios read believed BLUFOR force, so a player who reinforces mid-muster raises both bars.
  - The ideal, the minimum and the expiry are the commander's personality, set per archetype
    ([§Archetype](opcom_plan.md#archetype-phase-6)). 3:1 and 1:1 are the Balanced baseline and apply until
    Phase 6. A patient commander musters longer for a well-executed manoeuvre; an aggressive one launches sooner
    at lesser odds. The archetype table gains the three as columns beside `archWeight`.
  - A mustering action checks `OPCOM_PWIN_FLOOR` at launch, not at commit, against its archetype's minimum. A
    commit-time check would drop most musters before they gather anything, since a muster commits below the odds
    it launches at. An action that does not muster keeps the commit-time check.
  - The band picks the template once, at commit, and a muster launches that template whatever `r` it reaches, so
    a plan never flips mid-muster. A `flank` committed at 1.5 that musters to 3:1 still launches as a flank, not
    an `assault`.
  - When this folds into the plan, `opcom_plan.md:143-144` and `:172-176` take the ideal, minimum, expiry and
    launch-time floor, `:146` and `:192` state that the band picks once at commit, and §Archetype takes the three
    columns.
  - The ideal replaces the plan's "until the ROI-optimal force has converged" (`opcom_plan.md:172-174`).
- **Belief persistence:** belief is keyed by group `netId` (`fnc_opcom_sense.sqf:68`), which resolves to nothing
  after a restart, so a restored row never matches its group again and a re-sighting counts that group twice.
  Decided:
  - The save keeps no BLUFOR sightings. A restart also loses the headless clients and returns players to HQ, so
    the sightings would describe a battlefield that no longer exists. The grid, its coverage layer and the
    contested set rebuild from the first sensor pass.
  - The HQ reveal flag and `DUWS_opcom_tick` do persist. The tick is the count of ticks since the campaign
    began, not the 5 s period, and every stored time counts against it: a restored tasking's commit `hold`
    (`fnc_opcom_task.sqf:51`) against a counter reset to 0 would hold that unit for hours. `fnc_opcom_belief_init`
    sets the tick to 0 today, so it must initialise both only when they are nil, or a restore resets them.
  - OPCOM stores one row per unit: its world position, its order (order, target, home and return zone, route
    mode), its `strength`, and its class where it has one. The class is the tasking's composition tokens plus
    `spawnClass`, the hull model drawn once at hire (`fnc_opcom_recruit.sqf:37-38`), so a restored vehicle keeps
    its hull. A saved `spawnClass` the loaded mods no longer define is rerolled from its token against the current
    faction settings (`DUWS_fnc_tokenClass`), with a WARN in the log. A token the current faction cannot field at
    all drops the unit, with a WARN. The plan's contract
    (`opcom_plan.md:371-373`) already lists position, order and strength; the fold adds the class and the reroll.
  - Zone and town owners persist too, because exposure and the candidate sweep read them. The campaign snapshot
    already holds both: BLUFOR-held zone positions and town reputation, which sets a town's owner
    (`campaign_persistence_plan.md:401`, `:403`). OPCOM's contract lists them as inputs the snapshot owns, as it
    lists the economy's tiers.
  - When this folds into the plan, §Persistence states the decision, and the question leaves
    [§Open questions](opcom_plan.md#open-questions).
- **The front line's zero-balance cells:** the grid row lists a front line (the band where the grid's balance
  changes sign, `opcom_plan.md:45`), with no rule for a cell at exactly zero. Decided: drop the front line. Its
  only reader was Build siting's "thin friendly front-contour" (`:263-264`), which coverage and exposure replace,
  and no code builds it. When this folds into the plan, the grid row at `:45` loses it.
- **Intercept (QRF) targets and resolve (Phase 4b):** the plan targets "a sighted player near own ground" and
  resolves on "threatened ground clear" (`opcom_plan.md:211-212`, `:224`), with no distance for either. Decided:
  - A QRF targets a BLUFOR sighting, never a zone, so it defends all of OPFOR's ground and not only its zones. A
    sighting is a candidate when its position lies inside OPFOR's area of influence (`fnc_aoi_opfor_covers`),
    which covers the zones, the towns, the band and the hardpoints in it.
  - The QRF follows the sighting's latest believed position while it moves.
  - Within its own K cells, a QRF reads truth, whatever unit it is, so it clears ground reliably. The read is a
    sensor, so the belief firewall holds: BLUFOR present refresh the sighting, and an empty block clears it.
  - At the target's last known position, a QRF with no BLUFOR within K drops its order and guards in place,
    waiting for orders. A QRF that finds BLUFOR fights them live and guards in place once none remain within K.
    A QRF never returns to garrison.
  - When this folds into the plan, `opcom_plan.md:211-212` takes the resolve, and the action table at `:224`
    takes the area-of-influence gate.

## Watch items — not defects

- **Grid rebuild cost.** Zeroing both layers over the play box plus depositing every source each 5 s tick runs in
  scheduled space and should be fine, but the plan budgets wall-clock only to the scoring pass. Measure the
  rebuild once under a full map before the decision loop stacks scoring on the same tick.
- **Nominal enemy deposit on empty BLU zones** (`OPCOM_GRID_ZONE_ENEMY_FORCE`, 8) means OPCOM never sees an
  undefended zone as empty. Belief-consistent (territorial facts are free, strength is not); the constant is the
  knob that sets baseline OPCOM caution.

## What is right and should not be reopened

- The belief/truth firewall, with sensors as the only truth readers.
- One dimensionless score (`archWeight × P(win) × Value / Cost`) with Value and Cost both in AP.
- Serialisation discipline: positions not handles, numbers-only grid, `DUWS_`/`OPCOM_` prefix split,
  plain-global constants out of preprocessor reach.
- No-retreat derived from the engine's COMBAT-behaviour limitation, and the muster rule that keeps it from
  causing defeat in detail.
- Templates as the single execution form — a simple tasking is the degenerate template; no planner.
- One arbitrated wallet: every sink competes in the appraisal, nothing spends on its own clock.
- The build order, which tracks read dependencies exactly.
