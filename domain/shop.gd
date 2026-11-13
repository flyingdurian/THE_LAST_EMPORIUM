extends RefCounted
## Single authoritative command boundary. UI receives copies; all effects and settlement are here.
const Negotiation = preload("res://domain/negotiation.gd")
const Terms = preload("res://domain/terms.gd")
const Fixtures = preload("res://domain/fixtures.gd")
var _content: Dictionary
var _state: Dictionary
var save_path: String

func _init(content: Dictionary = {}, path: String = "user://emporium_foundation_v1.json") -> void:
	save_path = path
	_content = content.duplicate(true) if not content.is_empty() else read_content()
	reset()

static func integers(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v: out[k] = integers(v[k])
		return out
	if v is Array:
		var out: Array = []
		for x in v: out.append(integers(x))
		return out
	if v is float and floor(v) == v: return int(v)
	return v

static func read_content() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/benchmark.json"))
	return integers(data) if data is Dictionary else {}

func reset() -> void:
	var c: Dictionary = _content.customer.duplicate(true)
	var i: Dictionary = _content.item.duplicate(true)
	c["memories"] = []
	c["ban_until"] = 0
	c["safety_hold"] = false
	_state = {"version":1,"day":1,"phase":"morning","gold":120,"customer":c,"items":{str(i.instance):i},"selected":i.instance,"session":{},"serial":0,"events":[],"scheduled":[],"receipts":[],"visited":false,"return_note":"","reservation":{},"revision":0}
	_state["fixtures"] = Fixtures.defaults()
	for extra in _content.get("extra_items",[]):
		_state.items[str(extra.instance)] = extra.duplicate(true)

func snapshot() -> Dictionary:
	var copy := _state.duplicate(true)
	copy["item"] = copy.items[copy.selected].duplicate(true)
	return copy

func fail(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}

func log_event(s: Dictionary, kind: String, details: Dictionary = {}) -> int:
	s.serial += 1
	var ev := {"id":s.serial,"day":s.day,"kind":kind,"details":details.duplicate(true)}
	s.events.append(ev)
	return int(ev.id)

func memory(s: Dictionary, kind: String, details: Dictionary = {}) -> int:
	var eid := log_event(s,kind,details)
	s.customer.memories.append({"event_id":eid,"kind":kind,"day":s.day,"item":s.selected})
	return eid

func schedule(s: Dictionary, kind: String, source: int) -> void:
	s.scheduled.append({"kind":kind,"source":source,"due":int(s.day)+1,"applied":false})

func apply_effect(s: Dictionary, effect: Dictionary) -> void:
	var c: Dictionary = s.customer
	var k: String = effect.kind
	c.relationship = clampi(int(c.relationship)+int(effect.get("rel",0)), -100,100)
	c.trust = clampi(int(c.trust)+int(effect.get("trust",0)),0,100)
	var eid := memory(s,k,effect)
	match k:
		"threatened_ban":
			schedule(s,"guarded_return",eid)
			# Eligibility is private, never a published rumor.
			schedule(s,"grievance_eligible",eid)
		"actual_ban": c.ban_until = int(s.day)+int(effect.days)
		"violence_threat":
			c.safety_hold = true
			schedule(s,"report_eligible",eid)

func close_session(s: Dictionary) -> void:
	s.reservation = {}
	if not s.session.is_empty():
		s.session.status = "closed"
		s.session.offer = 0
		s.session.speech_act = "departure"
		s.session.expression = "departing"

func command(cmd: Dictionary) -> Dictionary:
	# Copy-on-write; rejected commands leave the prior state untouched.
	var s := _state.duplicate(true)
	var kind: String = cmd.get("type", "")
	var c: Dictionary = s.customer
	var i: Dictionary = s.items[s.selected]
	var p: Dictionary = _content.policy
	var active: bool = not s.session.is_empty() and s.session.status in ["negotiating","pending"]
	match kind:
		"select":
			if active or not s.items.has(cmd.get("item","")): return fail("Cannot select item")
			s.selected = cmd.item
		"move_fixture":
			if active: return fail("Finish the encounter before moving furniture")
			var fixture: String = str(cmd.get("fixture",""))
			var socket: String = str(cmd.get("socket",""))
			if not Fixtures.can_place(s.fixtures,fixture,socket): return fail("Placement socket unavailable")
			s.fixtures[fixture] = socket
			log_event(s,"fixture_moved",{"fixture":fixture,"socket":socket})
		"move":
			var loc: String = cmd.get("location", "")
			if active or i.owner != "shop" or not valid_location(loc) or not s.reservation.is_empty(): return fail("Cannot move item now")
			if not Fixtures.slot_allowed(i,loc): return fail("This merchandise needs a compatible display")
			for other in s.items.values():
				if other.instance != i.instance and other.owner == "shop" and other.location == loc: return fail("Slot occupied")
			i.location = loc
			log_event(s,"move",{"location":loc})
		"price":
			var amount: Variant = cmd.get("amount",0)
			if active or i.owner != "shop" or typeof(amount)!=TYPE_INT or amount < 1 or amount > 1000000: return fail("Invalid or locked price")
			i.asking = amount
			log_event(s,"price",{"amount":amount})
		"appraise":
			if active or i.owner != "shop": return fail("Cannot appraise now")
			i["appraised"] = true
			log_event(s,"appraised")
		"open":
			if s.phase != "morning": return fail("Already open or finished")
			s.phase = "open"
			log_event(s,"opened")
		"visit":
			if s.phase != "open" or active or s.visited: return fail("Visit unavailable")
			if int(c.ban_until)>int(s.day) or c.safety_hold: return fail("Customer cannot visit")
			s.visited = true
			if i.owner != "shop":
				s.return_note = "Thank you for the purchase." if s.return_note == "" else s.return_note
				log_event(s,"social_visit")
			elif not str(i.location).begins_with("shelf:"): return fail("Display the item first")
			else:
				var sid := log_event(s,"visit_started")
				s.session = Negotiation.start(c,i,p,sid)
		"act":
			if not active: return fail("No active negotiation")
			if int(cmd.get("session",-1)) != int(s.session.session) or int(cmd.get("revision",-1)) != int(s.session.revision): return fail("Stale action")
			var act: Dictionary = cmd.get("action",{}).duplicate(true)
			# Evidence is grounded in actual appraisal, never supplied by text/AI.
			act["verified"] = bool(i.get("appraised",false))
			var result: Dictionary = Negotiation.resolve(s.session,act,c,i,p)
			if not result.ok: return result
			s.session = result.state
			for effect in result.effects: apply_effect(s,effect)
			log_event(s,"turn",{"session":s.session.session,"revision":s.session.revision,"action":act.type})
			if s.session.status == "pending":
				s.reservation = {"item":i.instance,"session":s.session.session,"revision":s.session.revision,"amount":s.session.offer}
			else: s.reservation = {}
		"confirm":
			if not active or s.session.status != "pending": return fail("No pending deal")
			var r: Dictionary = s.reservation
			if r.is_empty() or int(cmd.get("session",-1)) != int(r.session) or int(cmd.get("revision",-1)) != int(r.revision): return fail("Stale confirmation")
			var amount := int(r.amount)
			if i.owner != "shop" or not str(i.location).begins_with("shelf:") or r.item != i.instance or amount != int(s.session.offer) or amount < 1 or amount > Negotiation.cap(c) or amount > int(Negotiation.metrics(s.session,c,i,p).w): return fail("Deal no longer valid")
			var terms: Dictionary = Terms.evaluate({"npc_pays_g":amount,"shop_item_ids":[i.instance],"npc_item_ids":[]},s.items,c,int(Negotiation.metrics(s.session,c,i,p).w))
			if not terms.ok: return terms
			s.gold += amount
			c.wallet -= amount
			i.owner = c.id
			i.location = "customer"
			var receipt_id := log_event(s,"sale",{"amount":amount,"session":r.session,"item":i.instance})
			s.receipts.append({"event_id":receipt_id,"amount":amount,"item":i.instance,"session":r.session})
			if s.session.hostile:
				memory(s,"coerced_purchase",{"receipt":receipt_id})
			elif amount >= Negotiation.rnd(Negotiation.reference_value(i)*0.85) and amount <= int(c.fair_ceiling):
				c.relationship = clampi(int(c.relationship)+int(p.fair_rel),-100,100)
				c.trust = clampi(int(c.trust)+int(p.fair_trust),0,100)
				var eid := memory(s,"fair_dealing",{"receipt":receipt_id})
				schedule(s,"helpful_return",eid)
			else: memory(s,"purchase",{"receipt":receipt_id})
			s.session.status = "completed"
			s.session.speech_act = "settled"
			s.session.expression = "guarded" if s.session.hostile else "pleased"
			s.reservation = {}
		"close":
			if s.phase != "open": return fail("Shop is not open")
			if active: close_session(s)
			s.phase = "closed"
			log_event(s,"day_closed")
		"next_day":
			if s.phase != "closed" or int(s.day)>=2: return fail("Prototype ends after Day 2")
			s.day += 1
			s.phase = "morning"
			s.visited = false
			s.session = {}
			s.return_note = ""
			for event in s.scheduled:
				if not event.applied and int(event.due)<=int(s.day):
					event.applied = true
					match event.kind:
						"helpful_return":
							s.return_note = "I remember your fairness. " + str(c.clue)
							c["history_modifier"] = int(c.history_bonus)
						"guarded_return":
							s.return_note = "I remember your threat. I would rather keep this brief."
							c["history_modifier"] = -int(c.history_penalty)
						"report_eligible": s.return_note = "The customer is not returning after the threat."
					log_event(s,"scheduled_applied",{"source":event.source,"kind":event.kind})
			log_event(s,"day_started")
		_: return fail("Unknown command")
	s.revision += 1
	if not valid_state(s): return fail("Invariant violation")
	_state = s
	return {"ok":true}

static func valid_location(loc: String) -> bool:
	var parts := loc.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int(): return false
	var idx := int(parts[1])
	return str(idx)==parts[1] and idx>=0 and ((parts[0]=="shelf" and idx<4) or (parts[0]=="storage" and idx<8))

func valid_state(s: Dictionary) -> bool:
	for key in ["version","day","phase","gold","customer","items","selected","session","reservation","serial","events","scheduled","receipts","visited","return_note","revision"]:
		if not s.has(key): return false
	if not Fixtures.valid(s.get("fixtures",{})): return false
	if s.version != 1 or not s.customer is Dictionary or not s.items is Dictionary or not s.session is Dictionary or not s.reservation is Dictionary: return false
	if not s.events is Array or not s.scheduled is Array or not s.receipts is Array: return false
	if typeof(s.serial)!=TYPE_INT or typeof(s.revision)!=TYPE_INT or s.serial<0 or s.revision<0: return false
	var seen_ids := {}
	for ev in s.events:
		if not ev is Dictionary or not ev.has("id") or not ev.has("kind") or not ev.has("day") or seen_ids.has(ev.id): return false
		seen_ids[ev.id] = true
	for ev in s.scheduled:
		if not ev is Dictionary or not ev.has("source") or not ev.has("kind") or not ev.has("due") or not ev.has("applied") or not seen_ids.has(ev.source): return false
	for rec in s.receipts:
		if not rec is Dictionary or not rec.has("event_id") or not seen_ids.has(rec.event_id): return false
	if typeof(s.gold)!=TYPE_INT or s.gold<0 or not s.day in [1,2] or not s.phase in ["morning","open","closed"]: return false
	var c: Dictionary = s.customer
	if not s.items.has(s.selected): return false
	var i: Dictionary = s.items[s.selected]
	var occupied := {}
	for key in s.items:
		var obj: Variant = s.items[key]
		if not obj is Dictionary or not obj.has("instance") or obj.instance != key or not obj.has("owner") or not obj.has("location"): return false
		if obj.owner == "shop":
			if not valid_location(str(obj.location)) or occupied.has(obj.location) or not Fixtures.slot_allowed(obj,str(obj.location)): return false
			occupied[obj.location] = true
		elif obj.owner != s.customer.id or obj.location != "customer": return false
	for k in _content.customer:
		if not c.has(k): return false
	for k in _content.item:
		if not i.has(k): return false
	if not c.has("memories") or not c.memories is Array or not c.has("ban_until") or not c.has("safety_hold"): return false
	if c.id != _content.customer.id or typeof(c.wallet)!=TYPE_INT or c.wallet<0 or int(s.gold)+int(c.wallet)!=120+int(_content.customer.wallet): return false
	if not ((i.owner=="shop" and valid_location(str(i.location))) or (i.owner==c.id and i.location=="customer")): return false
	if not s.session.is_empty():
		for k in ["status","session","revision","offer","ask","metrics","item","expression","speech_act","initial_trust","initial_relationship","hostile","final","claimed","claim_retracted","patience","anger","evidence","firm","ban","rapport","seen"]:
			if not s.session.has(k): return false
		if s.session.status in ["negotiating","pending"] and s.session.item != i.instance: return false
		if s.session.status == "pending" and s.reservation.is_empty(): return false
	if not s.reservation.is_empty():
		for k in ["item","session","revision","amount"]:
			if not s.reservation.has(k): return false
		if s.session.is_empty() or s.session.status!="pending" or s.reservation.item!=i.instance or i.owner!="shop" or s.reservation.session!=s.session.session or s.reservation.revision!=s.session.revision or s.reservation.amount!=s.session.offer: return false
	return true

static func parse_save(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK: return null
	return integers(parser.data)

func save() -> Dictionary:
	var tmp := save_path+".tmp"
	var f := FileAccess.open(tmp,FileAccess.WRITE)
	if f == null: return fail("Cannot write save")
	f.store_string(JSON.stringify(_state))
	f.flush()
	f.close()
	var dest := ProjectSettings.globalize_path(save_path)
	var backup := dest+".bak"
	if FileAccess.file_exists(save_path):
		# Preserve the last valid primary; do not overwrite backup with corrupt input.
		var old: Variant = parse_save(FileAccess.get_file_as_string(save_path))
		if old is Dictionary and valid_state(old):
			if DirAccess.copy_absolute(dest,backup)!=OK: return fail("Backup failed")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),dest)!=OK: return fail("Save replace failed")
	return {"ok":true}

func load_save() -> Dictionary:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path): continue
		var parsed: Variant = parse_save(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			# Compatible legacy saves: add missing layout and new unique test stock once.
			if not parsed.has("fixtures"): parsed["fixtures"] = Fixtures.defaults()
			if parsed.get("items") is Dictionary:
				for extra in _content.get("extra_items",[]):
					if not parsed.items.has(extra.instance):
						var free := true
						for obj in parsed.items.values():
							if obj is Dictionary and obj.get("owner") == "shop" and obj.get("location") == extra.location: free = false
						if free: parsed.items[extra.instance] = extra.duplicate(true)
		if parsed is Dictionary and valid_state(parsed):
			_state = parsed
			return {"ok":true,"backup":path.ends_with(".bak")}
	return fail("No valid save; current session preserved")
