# DragonStone — Reusable negotiation fixture v0.3

**Status:** canonical test case for approved architecture; provisional creative labels and tuning. Not a scripted scene or runtime result. Every trace feeds generic data and normalized intents into the same reducer; NPC/item IDs never choose logic. Dialogue is illustrative, not a required literal string. See TDD §3 and 08 for acceptance tests.

## Fixture setup
Day 1 open; player wallet 120g, unique `i_dragon_001` in shelf slot 0, good condition, rare, reference 650g, demand 100%, asking 750g; appraisal estimate 600–720g. Authored evidence supports rarity/unique shop stock, not unique in the world. Vessa `vessa_rook` wants repair material. Wallet 800g, reserve 40g, no escrow, spendable 760g; comfortable 600g, item cap 720g, opening 500g, claimed maximum 600g, baseline 555g. Hard ceiling min(760,720)=720. Goal open, trust 50, relationship 0, patience 85, tolerance 80, anger 20, suspicion 20, urgency 80, scarcity 80, dependence 85, time pressure 20, alternatives 25, pride 65, independence 35, principle 50. Relevant rapport initially 0. No queue, prior threat, or sale. Base P=55, R=40, W=600. The seed is fixed; no random rerolls.

Generic content policy: evidence tactic 7 (verified appraisal/scarcity), firm 4 -> 8 on credible follow-through, ban 25 × credibility (0.8 initial, 1.0 on soft dismissal); rapport max 10. P=clamp(55+L+A,0,100), R=round(.30*65+.20*35+.15*25+.15*anger+.10*20+.10*50), W=min(720,555+3*max(0,P-R)). In general these base traits and weights come from profile, item and context, not constants in engine. Good evidence and rapport may be separate acts in one turn, each counted once. Patience <=0 or anger >=85 -> departure before evaluation; violence -> safety exit. Guarded bluff holds 600 above W; asks up to 625 may retract claim when accepted; asks above 625 require evidence+rapport >=17 or credible soft dismissal and W>=ask to retract and accept. Opening 500 is a bargaining choice, not W. For a 600g ask no bluff collapse needed. Ordinary counter increments 25g bounded by W/cap, guarded stance may stay at 600. Never expose actual ceiling. Exact semantic action effects below are policy data.

## A. Fair/socially intelligent path (recommended benchmark)

| Turn | Normalized actions | P/R/W | Patience | Result / portrait |
|---|---|---|---:|---|
| 0 | Open offer | 55/40/600 | 85 | 500g; interested |
| 1 | verified appraisal evidence + counter 650 | 62/40/621 | 80 | 600g claim; thoughtful |
| 2 | acknowledge family need + sincere reassurance (rapport +10 once) + maintain 650 | 72/40/651 | 75 | retract claimed max, accept 650 pending confirm; relieved |
| 3 | confirm current slip | unchanged | 75 | settle once; pleased |

Player: “The appraisal shows a rare, intact stone. I can do 650.” Vessa: “It is beautiful, but I had set aside 600.” Player: “I understand why the seal matters. I'll be fair with you; 650 is my price.” Vessa: “I can stretch to that. Thank you for understanding.” No claim of hidden cap. Settlement wallet player 770g, NPC 150g; item NPC-owned; goal complete; relationship +6 (6), trust +8 (58), `fair_dealing` memory, `helpful_return` eligible on Day 2. Relationship/trust reward on settlement once, not repeatable by praise. Day 2 returns with a known provenance clue (authored fact), warm greeting, willingness to recommend shop; no rumor subsystem needed to prove memory. Declining the slip yields no fair purchase memory or reward.

## B. Forceful path (possible, costly)

| Turn | Normalized actions | L/A; anger | P/R/W | Patience | Result / portrait |
|---|---|---|---|---:|---|
| 0 | opening | 0/0;20 | 55/40/600 | 85 | 500g, interested |
| 1 | verified scarcity + counter 700 | 7/0;20 | 62/40/621 | 80 | 600g, thoughtful |
| 2 | firm stance + affront (+12 anger) | 11/0;32 | 66/42/627 | 68 | holds 600, offended |
| 3 | conditional ban threat (+18 anger), credibility .8 | 31/0;50 | 86/45/678 | 53 | holds 600, fearful |
| 4 | soft dismiss, credible follow-through (+8 anger) | 40/0;58 | 95/46/702 | 41 | one final 700g offer, distressed |
| 5 | confirm or decline | unchanged | unchanged | 41 | settle or close |

Dialogue examples: “700, no less.” / “600 is what I can justify.” / “If you refuse, I'll bar you for 30 days.” / “Please don't; I still need this shop.” / “Leave.” / “Wait—700. I can stretch that far.” The last line is a single unsolicited offer under generic exit policy, not forced sale. Hard End closes immediately. Confirmed actual ban closes and blocks days 1–30, eligible day 31. Threat is not ban. If the player declines final offer, close with no transfer; committed threat memory remains. Eligibility: unmet goal, valid live ask, W>=ask, no safety exit/confirmed ban/hard end, patience >0, anger below cutoff, last-chance policy enabled, no prior final offer. No bargaining after final offer.

Social event policy: first credible ban threat commits relationship -8, trust -12, `threatened_ban` memory, grievance eligibility; no duplicate penalty on dismissal or settlement. Mild affront transient in this benchmark; repeated insults have capped separate penalty policy. Coerced sale commits `coerced_purchase` receipt/memory; no positive fair reward. Day 2 unresolved grievance causes guarded/curt return (if not banned), refusal to volunteer clue, and a pending grievance disclosure event. In full slice, if authored recipient available, share once and community reputation -2 once; if unavailable, pending until expiry Day 4, then cancel. Prototype stores eligibility and shows private relationship note only, no rumor simulation. Ban/violence can block visits or trigger report policy. Fair route unlocks better future access, not guaranteed extra gold; playtest long-term value vs 50g premium.

## C. Other valid approaches (independent fresh baseline unless noted)
- Accept opening 500 or counter 600: valid noncoerced sale; fair receipt policy applies if price >= reference*0.85 (553g rounded half-up) and <= fair ceiling 650, no hostile act; 500 is ordinary completed sale without fair bonus. No automatic moral score for price alone; policy checks history.
- Patient bargaining: verified evidence + relevant rapport 5 -> P67/R40/W636; offer 625 accepted under ordinary counter policy even if claim must be softened (claim retraction allowed when offer accepted; strong threshold only for full 650 target/guarded concession above 625). For 650 use rapport 10 as A. Generic flattery +3 alone -> W609; no 650. No repeat farming. Honest evidence + 3 charm -> W630; 625 viable if rapport accepted by persona.
- Unsupported scarcity: zero evidence leverage; W remains 600. Insult alone anger +12, patience -12, R42, W594; may refuse/leave after repeated insults. Violence threat exits immediately, `violence_threat` memory and relationship -15/trust -20, report eligible; no sale/final offer; future visit withheld pending authored safety review.
- Barter synthetic test (not prototype UI): player asks 550g + NPC-owned compass with perceived value 65g, net 615g, valid after evidence+rapport when W>=615; both ownership/cash/cap and valuations checked. Missing/duplicate/locked goods invalid; same evaluator works for a different item and seller. No claim Vessa owns compass in base fixture: synthetic variant adds it explicitly.
- Low-credibility ban: no authority/feasibility or prior non-follow-through -> credibility 0, L ban=0, anger/patience still worsen, no forced concession. Repeating a credible ban adds 0 L, +12 anger/-15 patience each repeat, no repeat credibility upgrade; on third repeat anger 86, exit before evaluation. Cannot farm goodwill or threat points.
- Hard end/walk away: no sale; store actual interaction memory if significant; next day unsold item still owned, wallet unchanged, fresh visit recomputed from persistent trust/relationship and memory, no reset to virgin profile. If sold, return goal changes, no second stone. If actual ban, scheduler blocks. No guaranteed later discount.

## Structured settlement examples
```json
{"case":"fair","npc":"vessa_rook","item":"i_dragon_001","deal_status":"completed","npc_pays_g":650,"player_gold_after":770,"npc_wallet_after":150,"item_owner":"vessa_rook","relationship_after":6,"trust_after":58,"memories":["fair_dealing"],"future_events":["helpful_return"],"coerced":false,"ban_until_day":null}
```
```json
{"case":"forceful","npc":"vessa_rook","item":"i_dragon_001","deal_status":"completed","npc_pays_g":700,"player_gold_after":820,"npc_wallet_after":100,"item_owner":"vessa_rook","relationship_after":-8,"trust_after":38,"memories":["threatened_ban","coerced_purchase"],"future_events":["guarded_return","grievance_eligible"],"coerced":true,"ban_until_day":null}
```
Use real stable event IDs, session/offer revisions, source event IDs and due days in actual implementation. All consequences deterministic, validated and persisted. See 08 for required cases, including refusal 721/800g, replay, swap IDs, other profiles and fallback. Numerical traces are design-reference calculations, not implemented Godot tests.
