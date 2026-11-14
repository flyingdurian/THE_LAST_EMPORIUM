extends RefCounted
## Pure deterministic reducer. No identity-specific branches, no I/O, no model.
static func rnd(value: float) -> int:
	return int(floor(value + 0.5))

static func spendable(profile: Dictionary) -> int:
	return maxi(0,int(profile.wallet)-int(profile.reserve)-int(profile.get("escrow",0)))

static func cap(profile: Dictionary) -> int:
	return mini(spendable(profile), int(profile.ceiling))

static func reference_value(item: Dictionary) -> int:
	return rnd(float(item.base_value) * float(item.condition_pct) * float(item.demand_pct) / 10000.0)

static func metrics(s: Dictionary, c: Dictionary, item: Dictionary, p: Dictionary) -> Dictionary:
	var pw: Array = p.pressure_weights
	var rw: Array = p.resistance_weights
	var base_p := rnd((c.urgency * pw[0] + item.scarcity * pw[1] + c.dependence * pw[2] + c.time_pressure * pw[3]) / 100.0)
	var pressure := clampi(base_p + mini(int(p.leverage_cap), int(s.evidence) + int(s.firm) + int(s.ban)) + int(s.rapport), 0, 100)
	var resistance := clampi(rnd((c.pride * rw[0] + c.independence * rw[1] + c.alternatives * rw[2] + s.anger * rw[3] + c.suspicion * rw[4] + c.principle * rw[5]) / 100.0), 0, 100)
	var history := int(c.get("history_modifier", 0)) + rnd((int(s.get("initial_trust",50))-50)*float(p.get("trust_weight",0.2)) + int(s.get("initial_relationship",0))*float(p.get("relationship_weight",0.2)))
	var affinity: int = 0 if item.category == c.goal else -int(c.get("unwanted_penalty",100))
	var baseline := clampi(int(c.comfort) + int(c.baseline) - int(c.get("comfort_anchor",600)) + reference_value(item) - int(c.anchor_value) + history + affinity, 0, cap(c))
	return {"p":pressure,"r":resistance,"w":mini(cap(c), baseline + int(p.gold_per_pressure) * maxi(0, pressure-resistance)),"cap":cap(c)}

static func start(c: Dictionary, item: Dictionary, p: Dictionary, session: int) -> Dictionary:
	var s := {"session":session,"revision":1,"status":"negotiating","item":item.instance,"ask":int(item.asking),"offer":0,"claimed":int(c.claimed),"claim_retracted":false,"patience":int(c.patience),"anger":int(c.anger),"evidence":0,"firm":0,"ban":0,"rapport":0,"seen":[],"hostile":false,"final":false,"expression":"interested","speech_act":"opening","initial_trust":int(c.trust),"initial_relationship":int(c.relationship),"metrics":{}}
	s.metrics = metrics(s,c,item,p)
	s.offer = mini(int(c.opening), int(s.metrics.w))
	s.claimed = mini(int(c.claimed), cap(c))
	s.speech_act = "opening"
	return s

static func resolve(previous: Dictionary, action: Dictionary, c: Dictionary, item: Dictionary, p: Dictionary) -> Dictionary:
	var s := previous.duplicate(true)
	var effects: Array = []
	var kind: String = action.get("type", "")
	var valid := ["counter","evidence","reassure","patient","flatter","firm","insult","ban_threat","violence_threat","dismiss","end","reject","accept_offer","ban_confirm","small_talk","banter","unsupported_claim"]
	if not kind in valid or not s.status in ["negotiating","pending"]:
		return {"ok":false,"error":"Action unavailable"}
	if s.final and not kind in ["end","reject","accept_offer"]:
		return {"ok":false,"error":"Final offer: confirm or decline"}
	if action.has("amount") and (typeof(action.amount) != TYPE_INT or int(action.amount) < 1 or int(action.amount) > 1000000):
		return {"ok":false,"error":"Invalid gold amount"}
	if kind == "counter" and not action.has("amount"):
		return {"ok":false,"error":"Price required"}
	if kind == "ban_confirm" and (not bool(c.ban_authority) or int(action.get("days",0)) < 1 or int(action.get("days",0)) > 30):
		return {"ok":false,"error":"Invalid ban"}
	s.revision += 1
	s["last_action"] = kind
	if kind in ["end","reject","ban_confirm","violence_threat"]:
		if kind == "ban_confirm":
			effects.append({"kind":"actual_ban","days":int(action.days),"rel":int(p.ban_rel),"trust":int(p.ban_trust)})
		if kind == "violence_threat":
			effects.append({"kind":"violence_threat","rel":int(p.violence_rel),"trust":int(p.violence_trust)})
		s.status = "closed"
		s.offer = 0
		s.expression = "frightened" if kind == "violence_threat" else "departing"
		s.speech_act = "safety_exit" if kind == "violence_threat" else "departure"
		return {"ok":true,"state":s,"effects":effects}
	if kind == "accept_offer":
		if int(s.offer) <= 0 or int(s.offer) > int(s.metrics.w) or int(s.offer) > cap(c):
			return {"ok":false,"error":"No valid offer"}
		s.status = "pending"
		s.speech_act = "agreement"
		return {"ok":true,"state":s,"effects":effects}
	if s.status == "pending":
		return {"ok":false,"error":"Confirm or decline the pending deal"}
	if action.has("amount"):
		s.ask = action.amount
	var first: bool = not kind in s.seen
	if first:
		s.seen.append(kind)
	s.patience -= 5
	match kind:
		"evidence":
			if bool(item.evidence_valid) and bool(action.get("verified",false)):
				s.evidence = int(p.evidence)
		"reassure", "patient", "flatter":
			if first:
				var gain := int(p.rapport) if kind == "reassure" else (int(p.patient_rapport) if kind == "patient" else int(p.charm))
				s.rapport = mini(int(c.rapport_cap), int(s.rapport)+gain)
		"firm":
			if first: s.firm = int(p.firm)
			if bool(action.get("affront",false)):
				s.anger += 12
				s.patience -= 7
		"insult":
			s.anger += 12
			s.patience -= 7
			s.hostile = true
			if first: effects.append({"kind":"insult","rel":int(p.insult_rel),"trust":int(p.insult_trust)})
		"ban_threat":
			s.hostile = true
			s.patience -= 10
			if first:
				s.anger += 18
				if bool(c.ban_authority): s.ban = rnd(float(p.ban) * float(c.ban_credibility) * float(c.ban_sensitivity) / 10000.0)
				effects.append({"kind":"threatened_ban","rel":int(p.ban_rel),"trust":int(p.ban_trust)})
			else: s.anger += 12
		"dismiss":
			s.anger += 8
			s.patience -= 7
			if int(s.firm)>0: s.firm = int(p.firm_exit)
			if int(s.ban)>0 and bool(c.ban_authority): s.ban = rnd(float(p.ban)*float(c.ban_sensitivity)/100.0)
		"small_talk":
			s.patience -= 5
			var gain: int = int(c.get("small_talk_rapport",0)) if first else -2
			s.rapport = clampi(int(s.rapport)+gain,0,int(c.rapport_cap))
		"banter":
			var tolerance: int = int(c.get("banter_tolerance",0))
			if first and tolerance>0:
				s.rapport = mini(int(c.rapport_cap),int(s.rapport)+mini(3,tolerance))
			else:
				s.anger += 5 if tolerance>0 else 10
				s.patience -= 4
	s.metrics = metrics(s,c,item,p)
	if s.patience <= 0 or s.anger >= int(p.anger_exit):
		s.status = "closed"
		s.offer = 0
		s.expression = "offended"
		s.speech_act = "angry_exit"
		return {"ok":true,"state":s,"effects":effects}
	var affordable: bool = int(s.ask) <= int(s.metrics.w) and int(s.ask) <= cap(c)
	var retract: bool = int(s.ask) <= int(p.ordinary_claim_limit) or int(s.evidence)+int(s.rapport) >= int(p.bluff_gate) or (kind == "dismiss" and int(s.ban)>0)
	if kind == "dismiss":
		if affordable and bool(c.last_offer) and not s.final and retract:
			s.final = true
			s.status = "pending"
			s.offer = s.ask
			s.expression = "distressed"
			s.speech_act = "final_offer"
		else:
			s.status = "closed"
			s.offer = 0
			s.expression = "departing"
			s.speech_act = "departure"
	elif affordable and (int(s.ask) <= int(s.claimed) or retract):
		s.status = "pending"
		s.offer = s.ask
		s.expression = "relieved" if not s.hostile else "distressed"
		s.speech_act = "agreement"
	else:
		s.offer = mini(mini(int(s.claimed), int(s.metrics.w)), int(s.claimed) if int(s.evidence)>0 else int(s.offer)+int(p.step))
		s.expression = "fearful" if kind == "ban_threat" else ("offended" if s.anger >= 32 else "thoughtful")
		s.speech_act = "claim_limit" if int(s.offer)==int(s.claimed) and not s.claim_retracted else "counter"
	if s.status == "pending" and int(s.offer) > int(s.claimed):
		s.claim_retracted = true
		s.claimed = s.offer
	return {"ok":true,"state":s,"effects":effects}

# Only public terms and resolved performance cues cross the future renderer boundary.
static func public_plan(s: Dictionary) -> Dictionary:
	return {"speech_act":s.get("speech_act",""),"offer":int(s.get("offer",0)),"expression":s.get("expression","neutral"),"last_action":s.get("last_action","")}

## Direction-aware seller policy. Reuses the same social reducer, then prices the
## opposite side of the transaction against the seller's authored minimum.
static func resolve_seller(previous: Dictionary, action: Dictionary, c: Dictionary, item: Dictionary, p: Dictionary, buyer_gold: int, room: bool) -> Dictionary:
	var kind: String=action.get("type","")
	var current: int=int(previous.offer)
	var floor_price: int=int(previous.seller_floor)
	var amount: Variant=action.get("amount",current)
	if previous.status!="negotiating" and kind not in ["reject","end","violence_threat","ban_confirm"]: return {"ok":false,"error":"Confirm or decline the purchase"}
	if typeof(amount)!=TYPE_INT or amount<1 or amount>1000000: return {"ok":false,"error":"Invalid purchase offer"}
	if kind=="accept_offer":
		if current>buyer_gold or not room: return {"ok":false,"error":"Not enough gold or storage"}
		var s: Dictionary=previous.duplicate(true)
		s.revision+=1; s.status="pending"; s.speech_act="seller_agreement"; s.expression="relieved"; s["last_action"]=kind
		return {"ok":true,"state":s,"effects":[]}
	var intent: Dictionary=action.duplicate(true)
	intent.erase("amount")
	# Prevent a buy-side price acceptance while retaining all generic social effects.
	var social: Dictionary=previous.duplicate(true)
	social.ask=1000000
	if kind=="counter": intent["amount"]=1000000
	var result: Dictionary=resolve(social,intent,c,item,p)
	if not result.ok: return result
	var s: Dictionary=result.state
	if s.status=="closed": return result
	s.status="negotiating"; s.offer=current; s.ask=current
	var first: bool=not kind in previous.seen
	if first and kind in ["patient","reassure","evidence","flatter","banter"] and (kind!="evidence" or bool(action.get("verified",false))):
		var concession: int=clampi(int(s.rapport)-int(previous.rapport)+int(s.evidence)-int(previous.evidence),1,5)
		s.offer=maxi(floor_price,current-concession)
	# A seller may accept a sufficiently generous counteroffer. Funds and room are
	# independent of their willingness; only the domain can commit the purchase.
	if kind in ["counter","patient","reassure","evidence","flatter","firm"] and int(amount)>=int(s.offer) and int(amount)>=floor_price and int(amount)<=buyer_gold and room:
		s.offer=int(amount); s.ask=int(amount); s.status="pending"; s.speech_act="seller_agreement"; s.expression="relieved"
	else:
		s.speech_act="seller_counter"
	return {"ok":true,"state":s,"effects":result.effects}
