extends "res://domain/shop.gd"
## Five-day scenario adapter. The inherited cash reducer/settlement remain authoritative.
const WeekData = preload("res://domain/week_data.gd")
var book: Dictionary
func _init(path: String = "user://emporium_week_v1.json") -> void:
	book = WeekData.read()
	super._init(WeekData.baseline(),path)
func reset() -> void:
	super.reset()
	_state.gold=book.starting_gold
	_state["week"]=true
	_state["profiles"]={}
	for raw in book.profiles:
		var c: Dictionary=raw.duplicate(true)
		c["memories"]=[]; c["ban_until"]=0; c["safety_hold"]=false
		_state.profiles[c.id]=c
	_state["visit_index"]=0; _state["visit_goal"]=""; _state["visit_spec"]=[]
	_state["journal"]=[]; _state["reports"]=[]; _state["day_start_gold"]=_state.gold
	_state["expertise"]=0; _state["upgrades"]={"storage":false,"sign":false}
	_state["expedition"]={}; _state["rumor"]={}; _state["debt"]={"paid":0,"warning":false}
	_state["seed"]=book.seed
	_state.items={}
	var initial: Array=["dragonstone","knights_blade","ironward_shield","emberroot","ember_tonic"]
	for idx in range(initial.size()):
		var item := WeekData.make_item(book,str(initial[idx]),"week_"+str(initial[idx]),"shop","storage:%d"%idx)
		_state.items[item.instance]=item
	_state.selected="week_dragonstone"
	prepare_visit(_state)
func capacity(s: Dictionary) -> int:
	return 12 if s.upgrades.storage else 8
func owned_slot(s: Dictionary,loc: String) -> bool:
	for i in s.items.values():
		if i.owner=="shop" and i.location==loc: return true
	return false
func storage_slot(s: Dictionary) -> String:
	for idx in range(capacity(s)):
		var loc := "storage:%d"%idx
		if not owned_slot(s,loc): return loc
	return ""
func visits(s: Dictionary) -> Array:
	var v: Array=book.visits.get(str(s.day),[]).duplicate(true)
	if s.upgrades.sign and s.day==4: v.append(["tovin_reed","buy","star_compass"])
	return v
func prepare_visit(s: Dictionary) -> void:
	s.session={}; s.reservation={}; s.visited=false; s.return_note=""
	var list: Array=visits(s)
	while int(s.visit_index)<list.size():
		var spec: Array=list[s.visit_index]
		var c: Dictionary=s.profiles[spec[0]]
		if c.safety_hold or int(c.ban_until)>int(s.day):
			s.visit_index+=1
			continue
		s.customer=c.duplicate(true); s.visit_spec=spec.duplicate(true); s.visit_goal=spec[1]
		return
	s.visit_spec=[]; s.visit_goal=""; s.visited=true
func persist_customer(s: Dictionary) -> void:
	s.profiles[s.customer.id]=s.customer.duplicate(true)
func schedule(s: Dictionary, kind: String, source: int) -> void:
	super.schedule(s,kind,source)
	s.scheduled.back()["customer_id"]=s.customer.id
func account(s: Dictionary, kind: String, cash: int, cost: int=0, value: int=0) -> void:
	var id:=log_event(s,"account",{"kind":kind,"cash":cash,"cost":cost,"value":value})
	s.journal.append({"id":id,"day":s.day,"kind":kind,"cash":cash,"cost":cost,"value":value})
func commit(s: Dictionary) -> Dictionary:
	persist_customer(s)
	s.revision+=1
	if not valid_state(s) or not journal_ok(s): return fail("Week invariant violation")
	_state=s
	return {"ok":true}
func active_week(s: Dictionary) -> bool:
	return not s.session.is_empty() and s.session.status in ["negotiating","pending"]
func waiting_week(s: Dictionary) -> bool:
	return s.phase=="open" and not s.visited and not s.visit_spec.is_empty()
func next_waiting(s: Dictionary) -> bool:
	return s.phase=="open" and s.visited and not active_week(s) and int(s.visit_index)+1<visits(s).size()
func find_display(s: Dictionary,id: String) -> String:
	for key in s.items:
		var i: Dictionary=s.items[key]
		if i.id==id and i.owner=="shop" and str(i.location).begins_with("shelf:"): return key
	return ""
func visit_item(s: Dictionary,spec: Array, index: int) -> String:
	var id: String=spec[index]
	var key: String="visit_%d_%d_%s"%[s.day,s.visit_index,id]
	if not s.items.has(key): s.items[key]=WeekData.make_item(book,id,key,s.customer.id,"customer")
	return key
func start_visit(s: Dictionary) -> Dictionary:
	if not waiting_week(s): return fail("No customer waiting")
	var spec: Array=s.visit_spec
	var goal: String=spec[1]
	var key := ""
	if goal in ["buy","barter"]:
		key=find_display(s,str(spec[2]))
		if key=="": goal="social"; s.return_note="I came looking for "+WeekData.definition(book,str(spec[2])).name+", but I see none displayed."
	elif goal=="sell": key=visit_item(s,spec,2)
	else: key=str(s.selected)
	if key=="": key=str(s.selected)
	s.selected=key; s.visit_goal=goal; s.visited=true
	var sid:=log_event(s,"visit_started",{"customer":s.customer.id,"goal":goal})
	s.session=Negotiation.start(s.customer,s.items[key],_content.policy,sid)
	if goal=="sell":
		s.session.offer=int(spec[3]); s.session.ask=int(spec[3]); s.session["seller_floor"]=int(spec[4])
	elif goal=="barter":
		s.session["trade_item"]=visit_item(s,spec,5)
		s.session["trade_cash"]=int(spec[3])
		s.session["trade_value"]=int(spec[4])
		s.items[s.session.trade_item]["perceived_g"]=int(spec[4])
	elif goal in ["social","complaint"]:
		s.session.offer=0; s.session.ask=0
		s.session.speech_act="social"
		if s.return_note=="": s.return_note=WeekData.return_line(s.customer,goal)
	return commit(s)
func special_act(s: Dictionary, cmd: Dictionary) -> Dictionary:
	var n: Dictionary=s.session
	if int(cmd.get("session",-1))!=int(n.session) or int(cmd.get("revision",-1))!=int(n.revision): return fail("Stale action")
	var a: Dictionary=cmd.get("action",{}).duplicate(true)
	var k: String=a.get("type","")
	var goal: String=s.visit_goal
	var i: Dictionary=s.items[s.selected]
	if k=="ask_rumor":
		if s.rumor.get("state","")!="known" or s.customer.id!=s.rumor.get("knower",""): return fail("No new information from this customer")
		if n.status!="negotiating": return fail("Finish the proposed deal first")
		s.rumor.state="disclosed"; s.rumor["expires"]=mini(5,int(s.day)+2)
		for obj in s.items.values():
			if obj.category=="repair_material": obj.demand_pct=120
		n.revision+=1; n.patience=maxi(0,int(n.patience)-5); n.speech_act="rumor"
		log_event(s,"rumor_disclosed",{"customer":s.customer.id})
		return commit(s)
	if goal=="barter" and k=="barter":
		if n.status!="negotiating": return fail("Deal already pending")
		var cash: int=int(n.trade_cash)
		var terms: Dictionary={"npc_pays_g":cash,"shop_item_ids":[i.instance],"npc_item_ids":[n.trade_item]}
		var result: Dictionary=Terms.evaluate(terms,s.items,s.customer,int(n.metrics.w))
		if not result.ok or storage_slot(s)=="": return fail("Trade unavailable: funds, value or storage")
		n.revision+=1; n.status="pending"; n.offer=cash; n.speech_act="barter_agreement"; n.expression="relieved"
		s.reservation={"item":i.instance,"session":n.session,"revision":n.revision,"amount":cash,"terms":terms}
		return commit(s)
	if goal=="sell" and k=="inspect":
		if n.status!="negotiating": return fail("Finish the proposed purchase")
		i["knowledge"]=2 if s.expertise>0 else 1; i.appraised=true
		n.revision+=1; n.speech_act="seller_counter"
		log_event(s,"appraised",{"item":i.instance,"level":i.knowledge}); return commit(s)
	if goal=="sell":
		a["verified"]=bool(i.get("appraised",false))
		var result: Dictionary=Negotiation.resolve_seller(n,a,s.customer,i,_content.policy,int(s.gold),storage_slot(s)!="")
		if not result.ok: return result
		s.session=result.state
		for effect in result.effects: apply_effect(s,effect)
		s.reservation={"item":i.instance,"session":s.session.session,"revision":s.session.revision,"amount":s.session.offer} if s.session.status=="pending" else {}
		log_event(s,"turn",{"action":k,"session":n.session})
		return commit(s)
	if goal in ["social","complaint"] and k not in ["end","reject","dismiss","ban_confirm","violence_threat","insult","small_talk","reassure","flatter","firm","ban_threat","patient","banter"]:
		return fail("This visit is not a trade")
	# Social behavior shares the generic reducer, including threats, patience and one-time effects.
	a.erase("amount"); a["verified"]=false
	var old_offer: int=int(n.offer)
	var old_ask: int=int(n.ask)
	var result: Dictionary=Negotiation.resolve(n,a,s.customer,i,_content.policy)
	if not result.ok: return result
	s.session=result.state
	for effect in result.effects: apply_effect(s,effect)
	if s.session.status!="closed":
		s.session.status="negotiating"; s.session.offer=old_offer; s.session.ask=old_ask
		s.session.speech_act="seller_counter" if goal=="sell" else "social"
		if goal in ["social","complaint"] and k=="reassure" and not "reassure" in n.seen:
			apply_effect(s,{"kind":"heard_concern","rel":2,"trust":2})
		if goal in ["social","complaint"] and k=="dismiss": close_session(s)
	s.reservation={}
	log_event(s,"turn",{"action":k,"session":n.session})
	return commit(s)
func settle_special(s: Dictionary,cmd: Dictionary) -> Dictionary:
	var n: Dictionary=s.session; var r: Dictionary=s.reservation
	if n.status!="pending" or r.is_empty() or int(cmd.get("session",-1))!=int(r.session) or int(cmd.get("revision",-1))!=int(r.revision): return fail("No current approved terms")
	var i: Dictionary=s.items[s.selected]
	var loc:=storage_slot(s)
	if loc=="": return fail("Storage full")
	var amount: int=int(r.amount)
	if s.visit_goal=="sell":
		if i.owner!=s.customer.id or amount>int(s.gold) or amount<int(n.seller_floor): return fail("Purchase invalid")
		s.gold-=amount; s.customer.wallet+=amount
		i.owner="shop"; i.location=loc; i.acquisition_cost=amount
		account(s,"purchase",-amount)
	elif s.visit_goal=="barter":
		var terms: Dictionary=r.get("terms",{})
		var result: Dictionary=Terms.evaluate(terms,s.items,s.customer,int(Negotiation.metrics(n,s.customer,i,_content.policy).w))
		if not result.ok: return result
		var incoming: Dictionary=s.items[terms.npc_item_ids[0]]
		var value: int=int(incoming.perceived_g)
		s.gold+=amount; s.customer.wallet-=amount
		incoming.owner="shop"; incoming.location=loc; incoming.acquisition_cost=value
		i.owner=s.customer.id; i.location="customer"
		account(s,"barter",amount,int(i.acquisition_cost),value)
	else: return fail("Invalid trade direction")
	var eid:=log_event(s,"trade_settled",{"item":i.instance,"session":n.session,"amount":amount,"goal":s.visit_goal})
	s.receipts.append({"event_id":eid,"amount":amount,"item":i.instance,"session":n.session})
	memory(s,"trade_completed",{"receipt":eid})
	n.status="completed"; n.speech_act="settled"; n.expression="pleased"; s.reservation={}
	return commit(s)
func day_report(s: Dictionary) -> Dictionary:
	var r: Dictionary={"day":s.day,"opening":s.day_start_gold,"closing":s.gold,"sales":0,"purchases":0,"expenses":0,"cogs":0,"barter_value":0,"barter_cash":0,"deals":0,"cash_movement":0,"profit":0}
	for a in s.journal:
		if a.day!=s.day: continue
		r.cash_movement+=int(a.cash)
		match a.kind:
			"sale": r.sales+=int(a.cash); r.cogs+=int(a.cost); r.deals+=1
			"purchase": r.purchases-=int(a.cash); r.deals+=1
			"barter": r.barter_cash+=int(a.cash); r.barter_value+=int(a.value); r.cogs+=int(a.cost); r.deals+=1
			_: r.expenses-=int(a.cash)
	r.profit=r.sales+r.barter_cash+r.barter_value-r.cogs
	return r
func advance(s: Dictionary) -> Dictionary:
	if s.phase!="closed" or s.day>=5: return fail("Close the shop first; scenario ends on Day 5")
	s.day+=1; s.phase="morning"; s.day_start_gold=s.gold; s.visit_index=0
	for e in s.scheduled:
		if e.applied or int(e.due)>int(s.day): continue
		e.applied=true
		var id: String=e.get("customer_id",s.customer.id)
		var c: Dictionary=s.profiles[id]
		match e.kind:
			"helpful_return": c["history_modifier"]=int(c.history_bonus)
			"guarded_return": c["history_modifier"]=-int(c.history_penalty)
		log_event(s,"scheduled_applied",{"source":e.source,"kind":e.kind,"customer":id})
	if s.rumor.get("state","")=="disclosed" and int(s.day)>=int(s.rumor.expires):
		s.rumor.state="expired"
		for obj in s.items.values():
			if obj.category=="repair_material": obj.demand_pct=100
	if s.expedition.get("state","")=="away" and int(s.day)>=int(s.expedition.due):
		s.expedition.state="returned"
		var loot: Array=s.expedition.loot
		for id in loot:
			var key: String="exp_"+str(s.expedition.id)+"_"+str(id)
			var loc:=storage_slot(s)
			var item:=WeekData.make_item(book,str(id),key,"shop",loc if loc!="" else "delivery")
			item.acquisition_cost=int(int(book.expedition.cost)/loot.size())
			s.items[key]=item
		if s.expedition.evidence: s.rumor={"state":"known","truth":"Quarry fragments are authentic; repair demand is rising.","knower":"bram_alder","origin":s.expedition.id}
		log_event(s,"expedition_returned",{"id":s.expedition.id,"injury":s.expedition.injury})
	prepare_visit(s)
	log_event(s,"day_started")
	return commit(s)
func command(cmd: Dictionary) -> Dictionary:
	var s:=_state.duplicate(true)
	var k: String=cmd.get("type","")
	var active:=active_week(s)
	if k=="visit": return start_visit(s)
	if k=="next_customer":
		if not next_waiting(s): return fail("No next visitor")
		persist_customer(s); s.visit_index+=1; prepare_visit(s); return commit(s)
	if k=="next_day": return advance(s)
	if k=="close":
		if s.phase!="open": return fail("Shop not open")
		if active: close_session(s)
		s.phase="closed"
		if s.day>=int(book.debt.due) and int(s.debt.paid)<int(book.debt.amount): s.debt.warning=true
		s.reports.append(day_report(s)); log_event(s,"day_closed")
		return commit(s)
	if k=="act" and active and (s.visit_goal!="buy" or cmd.get("action",{}).get("type","")=="ask_rumor"):
		# Barter visit also supports ordinary cash haggling through the inherited reducer.
		var a: String=cmd.get("action",{}).get("type","")
		if s.visit_goal!="barter" or a in ["barter","ask_rumor"]: return special_act(s,cmd)
	if k=="confirm" and active and (s.visit_goal=="sell" or s.reservation.has("terms")): return settle_special(s,cmd)
	if k=="move":
		var i: Dictionary=s.items[s.selected]; var loc: String=cmd.get("location","")
		if active or i.owner!="shop" or not location_ok(s,loc) or owned_slot(s,loc) or not Fixtures.slot_allowed(i,loc): return fail("Invalid or occupied location")
		i.location=loc; log_event(s,"move",{"location":loc}); return commit(s)
	if k=="restock":
		if active: return fail("Finish the encounter")
		var count:=0
		var stock: Array=s.items.values()
		stock.sort_custom(func(a: Dictionary,b: Dictionary):
			var ai: int=WeekData.rank(book,str(a.id)); var bi: int=WeekData.rank(book,str(b.id))
			return ai<bi if ai!=bi else str(a.instance)<str(b.instance))
		for i in stock:
			if i.owner!="shop" or not str(i.location).begins_with("storage:"): continue
			for idx in range(4):
				var loc: String="shelf:%d"%idx
				if not owned_slot(s,loc) and Fixtures.slot_allowed(i,loc):
					i.location=loc; count+=1; break
		log_event(s,"restock",{"count":count}); return commit(s)
	if k=="appraise":
		var i: Dictionary=s.items[s.selected]
		if active or i.owner!="shop": return fail("Cannot appraise now")
		i.appraised=true; i["knowledge"]=2 if s.expertise>0 else 1
		log_event(s,"appraised",{"item":i.instance,"level":i.knowledge}); return commit(s)
	if k in ["upgrade","expertise","dispatch","pay_debt"]:
		if s.phase!="morning" or active: return fail("Prepare in the morning")
		var cost:=0
		var kind:=k
		match k:
			"upgrade":
				var upgrade: String=cmd.get("upgrade","")
				if not s.upgrades.has(upgrade) or s.upgrades[upgrade]: return fail("Upgrade unavailable")
				cost=75 if upgrade=="storage" else 60; s.upgrades[upgrade]=true; kind=upgrade
			"expertise":
				if s.expertise>0: return fail("Already trained")
				cost=50; s.expertise=1
			"dispatch":
				if not s.expedition.is_empty() or s.day>3: return fail("Contract unavailable")
				cost=int(book.expedition.cost)
				var rng:=RandomNumberGenerator.new(); rng.seed=int(s.seed)+int(s.day)
				var injury:=rng.randi_range(0,3)==0
				s.expedition={"id":s.serial+1,"state":"away","due":int(s.day)+int(book.expedition.days),"injury":injury,"loot":["moon_glass"] if injury else ["moon_glass","quarry_relic"],"evidence":true}
			"pay_debt":
				if s.day<int(book.debt.due): return fail("Installment not due")
				cost=mini(int(s.gold),int(book.debt.amount)-int(s.debt.paid))
				if cost<=0: return fail("Nothing payable")
				s.debt.paid+=cost; s.debt.warning=int(s.debt.paid)<int(book.debt.amount)
		if cost>int(s.gold): return fail("Insufficient gold")
		s.gold-=cost; account(s,kind,-cost); return commit(s)
	if k=="select" and s.items.has(cmd.get("item","")) and s.items[cmd.item].owner!="shop": return fail("Not your merchandise")
	var before: Dictionary=_state
	var result: Dictionary=super.command(cmd)
	if not result.ok: return result
	s=_state.duplicate(true)
	if k=="confirm":
		var amount: int=int(s.gold)-int(before.gold)
		account(s,"sale",amount,int(before.items[before.selected].acquisition_cost))
	persist_customer(s)
	if not valid_state(s) or not journal_ok(s):
		_state=before; return fail("Week invariant violation")
	_state=s
	return result
func location_ok(s: Dictionary,loc: String) -> bool:
	if ShopLocation(loc): return true
	var parts:=loc.split(":")
	return parts.size()==2 and parts[0]=="storage" and parts[1].is_valid_int() and int(parts[1])>=8 and int(parts[1])<capacity(s) and str(int(parts[1]))==parts[1]
func ShopLocation(loc: String) -> bool:
	return valid_location(loc)
func journal_ok(s: Dictionary) -> bool:
	var cash: int=int(book.starting_gold)
	var ids: Dictionary={}
	for a in s.journal:
		if not a is Dictionary or typeof(a.get("cash"))!=TYPE_INT or not a.has("id") or ids.has(a.id): return false
		ids[a.id]=true; cash+=int(a.cash)
	return cash==int(s.gold)
func valid_state(s: Dictionary) -> bool:
	for key in ["customer","items","profiles","session","reservation","selected","day","phase","gold","fixtures","week","journal","receipts","events","scheduled","reports","visit_index","visit_spec","visit_goal","visited","return_note","upgrades","expertise","expedition","rumor","debt","seed","day_start_gold","serial","revision"]:
		if not s.has(key): return false
	if not s.customer is Dictionary or not s.session is Dictionary or not s.reservation is Dictionary or not s.upgrades is Dictionary or not s.expedition is Dictionary or not s.rumor is Dictionary or not s.debt is Dictionary: return false
	if not s.receipts is Array or not s.events is Array or not s.scheduled is Array or not s.reports is Array: return false
	if not s.customer.has("id") or not s.customer.has("wallet"): return false
	if not s.upgrades.has("storage") or not s.upgrades.has("sign"): return false
	if not s.get("week",false) or not s.get("profiles") is Dictionary or not s.get("items") is Dictionary or not s.get("journal") is Array: return false
	if not s.get("fixtures") is Dictionary or not Fixtures.valid(s.fixtures): return false
	if not s.get("day",0) in [1,2,3,4,5] or not s.get("phase","") in ["morning","open","closed"] or typeof(s.get("gold"))!=TYPE_INT or s.gold<0: return false
	if not s.items.has(s.get("selected","")) or not s.profiles.has(s.customer.id): return false
	var occupied: Dictionary={}
	for key in s.items:
		if not s.items[key] is Dictionary: return false
		var i: Dictionary=s.items[key]
		if not i.has("instance") or not i.has("owner") or not i.has("location"): return false
		if i.instance!=key or not i.has("acquisition_cost") or int(i.acquisition_cost)<0: return false
		if i.owner=="shop":
			if i.location!="delivery":
				if not location_ok(s,str(i.location)) or occupied.has(i.location) or not Fixtures.slot_allowed(i,str(i.location)): return false
				occupied[i.location]=true
		elif not s.profiles.has(i.owner) or i.location!="customer": return false
	for c in s.profiles.values():
		if not c is Dictionary or not c.has("wallet") or typeof(c.wallet)!=TYPE_INT or int(c.wallet)<0: return false
	if int(s.customer.wallet)<0: return false
	if active_week(s):
		if s.session.item!=s.selected: return false
		if s.session.status=="pending":
			if s.reservation.is_empty() or s.reservation.item!=s.selected or s.reservation.session!=s.session.session or s.reservation.revision!=s.session.revision or s.reservation.amount!=s.session.offer: return false
		elif not s.reservation.is_empty(): return false
	elif not s.reservation.is_empty(): return false
	var seen: Dictionary={}
	for r in s.receipts:
		if not r is Dictionary or not r.has("session") or seen.has(r.session): return false
		seen[r.session]=true
	return true
func load_save() -> Dictionary:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path): continue
		var s: Variant=parse_save(FileAccess.get_file_as_string(path))
		if s is Dictionary and valid_state(s):
			if not journal_ok(s): continue
			_state=s; return {"ok":true}
	return fail("No valid Merchant's Week save")
