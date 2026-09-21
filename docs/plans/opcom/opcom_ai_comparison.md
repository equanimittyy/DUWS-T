# OPCOM compared with published game AI

This doc maps each part of the OPCOM design in [`opcom_plan.md`](opcom_plan.md) to the published method it
follows, then compares the design with two real-time strategy (RTS) AIs. Each part has a proven precedent. The
differences below are deliberate, or they are open questions that the plan already holds.

## The method behind each part

| OPCOM part | Published method | Where OPCOM differs |
|---|---|---|
| The pick scores each `[action, target]` pair as a product of factors ([§The pick](opcom_plan.md#the-pick)) | Infinite Axis Utility System (Mark and Lewis, GDC 2015): each decision–target pair scores as the product of its considerations | Every factor stays in AP, not in a 0–1 range, so Value and Cost share one unit |
| The shortlist of `OPCOM_PICK_TOP`, then a weighted draw | Dual-utility reasoning (Dill, *Game AI Pro 2*): keep the best options, then pick among them by weighted random | OPCOM cuts the list by count, not by rank category |
| `OPCOM_PICK_SHARPNESS` | Softmax (Boltzmann) selection: `score ^ k` is a softmax on log-score at temperature 1/k | — |
| Value ÷ Cost | Greedy by value density, the standard knapsack heuristic | The heuristic fails when cheap, dense buys starve one large buy. The savings goal is the standard fix |
| The savings goal ([§Gate and the savings goal](opcom_plan.md#gate-and-the-savings-goal)) | Resource escrow in RTS AI scripts | OPCOM saves for one named action, not a flat share of income |
| The `_fri` / `_ene` grid, and the need, cover and traffic fields | Influence maps (Mark, "Modular Tactical Influence Maps", *Game AI Pro 2*) | — |
| Belief with decay | Last-known-position tracking in AIs that do not read hidden state | — |
| `P(win) = r² / (r² + 1)` | The Lanchester square law. Stanescu, Barriga and Buro (AIIDE 2015) used it in an RTS bot to decide attack or retreat, and that bot won more games than its simulator-based version | Their unit strengths are learned from recorded battles. OPCOM's come from the hand-set force table (`belief/fnc_opcom_force.sqf`). The `r² / (r² + 1)` form is the Bradley–Terry model with strength = force² |
| The commit `hold` ([§Commitment](opcom_plan.md#commitment-intents-are-sticky)) | Inertia: a score bonus for the action already in progress | OPCOM uses a hard lock, which cannot break for an emergency |
| Templates and the runner ([§Templates](opcom_plan.md#templates-phase-5)) | Plays in STP (Browning, Bruce, Bowling and Veloso, 2005): a play is a set of roles with preconditions, an abort rule and a termination rule | — |
| The muster to 1.5:1 | Rally-then-attack in RTS bots | The military rule of thumb for an attacker is 3:1. OPCOM musters lower on purpose, because a sighted player already counts as 4 force |
| The archetype ([§Archetype](opcom_plan.md#archetype)) | Personality weights on a utility score | — |
| The commander as a whole | ALiVE's Military AI Commander for Arma 3, also named OPCOM: virtual unit profiles, and objectives ranked by a strategy rule | ALiVE ranks objectives by a fixed rule. OPCOM scores them against an economy |

## Two RTS AIs

The open-source RTS Beyond All Reason ships BARbarian, a fork of CircuitAI. Its managers are C++ with AngelScript
hooks, and its tuning is JSON (`luarules/configs/BARb/stable/` in the game's repository). The second column
describes a commercial RTS: its built-in AI, and the open competition bots written for it, such as Steamhammer.

| Topic | BARbarian | Commercial RTS | OPCOM |
|---|---|---|---|
| Who decides | Separate managers (economy, factory, builder, military), each with its own rules. Nothing weighs one manager's spend against another's | Built-in AI: a fixed build order and attack waves, set by a personality. Competition bots: an opening book and squads | One commander that scores every spend in AP |
| Spending | Spends whenever it has resources. Flags for empty or full metal and for an energy stall steer what it builds | Follows the build order | A scored pick, the savings goal and Bank |
| Fight odds | Attacks the nearest enemy group whose threat, scaled by `thr_mod.attack` (0.6–0.8), is below the squad's power. This is a yes/no gate | Competition bots: a combat simulator decides attack or retreat | Lanchester `P(win)` inside the score, and `OPCOM_PWIN_FLOOR` |
| Gathering | An attack squad waits for a fixed minimum power (`quota.attack`, 60) | Built-in AI: a wave fills, then goes | A muster to 1.5:1 over believed enemy force, and 0.75:1 at expiry |
| Retreat | Each unit pulls back below 50% health (a builder below 85%) | Competition bots: retreat when the simulator says the fight is lost | None ([engine gotcha](../../info/architecture/arma_engine_gotchas.md#a-group-in-combat-behaviour-ignores-a-commanded-move-order)) |
| Anti-flap | A factory switch waits for a randomised threshold of time and income | A retreat timer that resets while the simulator still says retreat | The commit `hold` |
| Unseen enemies | The enemy manager keeps each unit's last known position | Competition bots count remembered units that are out of sight | Belief with decay |
| Pathing | The threat map is a path cost | — | The foot cell chain costs step + λ × `_ene` (`taskings/fnc_opcom_route.sqf`), but every caller passes λ 0 and road routes carry no threat term. Phase 5 adds threat to road segments and off-road flanking legs ([§Templates](opcom_plan.md#templates-phase-5)) |
| Counter builds | `response.json`: the odds of building a counter role rise with enemy strength in the role it counters and fall as its own counter force grows, capped at a share of the army | Fixed in each build order | Open in 4C.2: whether belief carries a threat category |
| Personality and difficulty | Whole config sets per level, including `hard_aggressive` | Built-in AI: personalities. The top levels cheat with map vision and extra income | Archetype weights. OPCOM reads belief and never cheats |

## Where OPCOM differs, and why

- **Central scoring suits a slow income.** An RTS earns quickly and never holds resources for long, so its managers
  spend as money arrives. OPCOM earns roughly 40–80 AP per 30 min ([§What AP buys](opcom_plan.md#what-ap-buys)),
  so each spend must win against every other one.
- **Both RTS AIs correct a bad fight by retreat.** BARbarian scales enemy threat by 0.6–0.8, so it accepts fights
  up to about 1.7 times its own weight because it can pull out. An OPCOM group in combat cannot withdraw, so every
  commit is a fight to the end. OPCOM accepts that risk on purpose: its muster bars (1.5:1 ideal, 0.75:1 minimum)
  aim at fights the players can win, not at safe ones.
- **The square law also gives the survivors, and OPCOM does not price them.** A win at ratio `r` keeps
  √(1 − 1/r²) of the force. The expected share of the stake lost is (1 − `P(win)`) + `P(win)` × (1 − √(1 − 1/r²)):
  1.0 at parity, 0.31 at 2:1 and 0.15 at 3:1. A Cost of expected losses would score a 3:1 attack 12 times above an
  even one, so [§Cost](opcom_plan.md#cost) prices the whole stake at every ratio to keep OPCOM from attacking only
  at crushing odds.
- **The counter-build table is prior art for the open threat-category question.** Counter weight = importance ×
  enemy force in the countered role ÷ own force in the counter role, capped at a maximum share. `fnc_classifyVehicle`
  already sorts a class into the force table's categories. A belief stamp keeps only the summed force
  (`DUWS_fnc_opcom_sightStr`), so a typed counter needs the stamp to keep force per category.
- **Attack waves on a timer are the shape OPCOM rejects.** A built-in AI that sends waves on a cadence is the
  pattern that [§Rejected](opcom_plan.md#rejected-the-opfor-spawners-this-replaces) removes.
- **Two methods are not adopted.** A learned policy needs millions of self-play games. A combat simulator
  duplicates the engine, which resolves every fight. The Lanchester law is the proven low-cost stand-in.

## Sources

- [Infinite Axis Utility System](https://www.gameai.com/iaus.php)
- [Dill, "Dual-Utility Reasoning", *Game AI Pro 2*](https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter03_Dual-Utility_Reasoning.pdf)
- [Stanescu, Barriga and Buro, AIIDE 2015](https://ojs.aaai.org/index.php/AIIDE/article/view/12780)
- [Browning, Bruce, Bowling and Veloso, "STP: Skills, tactics and plays"](https://publications.ri.cmu.edu/stp-skills-tactics-and-plays-for-multi-robot-control-in-adversarial-environments)
- [ALiVE Military AI Commander](http://alivemod.com/wiki/index.php/Military_AI_Commander)
- [CircuitAI](https://github.com/rlcevg/CircuitAI)
- [Beyond All Reason](https://github.com/beyond-all-reason/Beyond-All-Reason)
- Steamhammer's development blog (satirist.org)
