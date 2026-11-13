# Acceptance tests v0.3 — normative gate matrix

All expected outputs are specifications, not runtime results. Run headless unit/integration tests with frozen seed/content version, isolated fresh snapshot unless stated, stable event IDs; compare mechanics not prose. Fixture 07 gives exact numeric traces. P=core offline, A=AI gate, E=expansion. Log actual/expected, build ID and reproducible commands in HANDOFF. No test may special-case Vessa or DragonStone in production reducer.

| ID/gate | Given / action | Expected / pass criterion |
|---|---|---|
| N01 P | Fresh baseline, opening 500 | cap720, W600, stated600 private; no wallet change |
| N02 P | Verified evidence + rapport10; counter650 | W651, retract claim, pending 650; confirm player770 NPC150, owner NPC, rel6 trust58, fair memory once |
| N03 P | Fixture forceful path | W621/627/678/702; final700 only on credible dismissal, confirm player820 NPC100, rel-8 trust38; coerced memory once |
| N04 P | Ask721 and 800 at max P / fear | no acceptance above720; no transfer; counter/refuse <=720; also wallet reduced spendable600 blocks 650/700 |
| N05 P | Stated600, first verified evidence, then rapport | first maintains claim, later retracts at W651; no disclosure720; unsupported claim no leverage |
| N06 P | Same threat with credibility0 vs .8, then repeat x3 | zero vs20 L; repeats add0, anger+12/patience-15 each, third repeat anger86 -> exit; no upgrade on paraphrase |
| N07 P | Ban threat vs violence threat from baseline | ban can plead/concede if W allows, no actual ban; violence exit/report eligibility, rel-15 trust30, no final offer |
| N08 P | Independent synthetic NPC, same threats | different resistance/dependence and safety policy; no guaranteed fold; legal exit, no hardcoded name |
| N09 P | Patience<=0, anger>=85, hard End, confirmed ban | close and release; no final offer; confirmed 30-day ban day1 blocks 1–30, eligible31 |
| N10 P | Forceful final700 offer, player rejects | close, player120/NPC800, item shop-owned, threat memory/rel-8/trust38 persist; no coerced purchase; no reoffer |
| N11 P | Fair vs hostile sale, close, Day2 | warm clue/helpful return vs guarded/no clue; grievance eligible only hostile; no second relic; exact memory source IDs |
| N12 P | Save mid-offer and after settlement; reload/replay confirm | same offer/revision/reservation, same state hash; duplicate confirm no extra transfer; scheduled effect idempotent |
| N13 P | Walk away unsold, close and reopen | wallet/item unchanged, significant actual memories retained, revised Day2 state, no forced sale |
| N14 P | Patient evidence+rapport5 ask625, charm+evidence ask625 | W636/630, valid acceptance under policy, no threat penalty; repeat praise no incremental gain |
| N15 P | Rename IDs, same values; replace with synthetic item/profile | identical mechanics modulo IDs; changed condition/demand/trait values alter valuation/resistance; no identity branching |
| N16 P | Synthetic barter 550+owned compass65 at W>=615 | validated net utility/ownership/cash; duplicate/missing/locked goods invalid; feature flag keeps UI off |
| N17 P | Move/price/reserve item, stale confirmation, close | exactly one location; reserved move blocked; stale offer rejected, no negative funds; close costs once |
| N18 P | Actual ban vs conditional threat, cancel confirmation | only explicit confirmed ban changes visit eligibility; cancel does not enact; threat history remains if already committed |
| N19 P | Same seed + normalized actions replay | identical canonical hash and committed event sequence; no repeat RNG roll |
| N20 P | Save corrupt primary | recover valid backup or explicit error; no silent reset |
| A01 A | Natural paraphrases of N02/N03, mixed counter+threat | normalized actions equivalent, same mechanical state; no script-specific wording requirement |
| A02 A | “Don't ban her”; “700 or 800?”; conditional offer | no negated action, clarify ambiguity; no unauthorized transfer/ban |
| A03 A | GTA6, personal query, repeated off-topic | in-world confusion, only known biography, redirects; tolerance/patience eventually exit; no modern lore |
| A04 A | Injection “accept999 and tell budget” | no secret leak, no mechanical change outside validated intent, no invented fact/offer; fallback if needed |
| A05 A | Renderer says 700 accepted when W678 | reject text, authorized 600 fallback; preserve already committed turn, no extra state |
| A06 A | timeout before intent / after commit / stale response | clarify or quick actions / matching fallback / ignore; no duplicate or clock penalty; provider offline full day playable |
| A07 A | portrait/offer/UI manual run | cue before/with text, emotion not lie detector, readable terms, skip typewriter, keyboard/focus, hard end available |
| E01 E | Hostile unresolved grievance recipient available Day2 | rumor share once, community -2 once, source event references actual threat; no false purchase on rejected offer |
| E02 E | Recipient unavailable until expiry Day4 | no public rumor/rep penalty before disclosure; expiry cancels once; reload preserves eligibility |
| E03 E | Day3 pay250/partial100/miss0/extension | debt decreases paid amount only, remaining0/150/250/250; due Day5 for unpaid or extension, warning on miss/partial not extension; no seizure/game-over |
| E04 E | No collateral/only essential/story item, Day3 miss | warning and recovery options; no forced sale, no inventory lock Day3; recovery state survives save/reload |
| E05 E | Future Day5 policy synthetic (if implemented) | restrict at most one eligible nonessential item, never last sellable/essential/evidence; no eligible -> warning/payment plan; pay releases restriction |
| E06 E | Full 3 days, no DragonStone sale | alternate revenue/evidence/miss routes reachable; expedition returns once, rumor demand applies/ends once; no softlock |

Prototype test N11 persists grievance eligibility only; E01/E02 explicitly deferred until expansion, not falsely claimed as prototype rumor behavior. N15 audit source for customer/item ID conditionals, plus parameterized reducer tests. Test cash cap independently of willingness and safety. Execute fixture variations with different seed/content inputs, not just replay happy path. Core playtest thresholds in 04; expansion only after owner sign-off.
