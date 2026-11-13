extends SceneTree
const Shop = preload("res://domain/shop.gd")
const N = preload("res://domain/negotiation.gd")
const Speech = preload("res://domain/dialogue.gd")
const Terms = preload("res://domain/terms.gd")
var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		printerr("FAIL ",label)

func cmd(shop, type: String, extra: Dictionary={}) -> Dictionary:
	var command: Dictionary = extra.duplicate()
	command.type = type
	return shop.command(command)

func act(shop, type: String, extra: Dictionary={}) -> Dictionary:
	var s: Dictionary=shop.snapshot().session
	var a: Dictionary=extra.duplicate(); a.type=type
	return cmd(shop,"act",{"session":s.session,"revision":s.revision,"action":a})

func confirm(shop) -> Dictionary:
	var s: Dictionary=shop.snapshot().session
	return cmd(shop,"confirm",{"session":s.session,"revision":s.revision})

func fresh(content: Dictionary={}, path: String="user://emporium_test.json", appraised: bool=true):
	var shop = Shop.new(content,path)
	cmd(shop,"move",{"location":"shelf:0"})
	if appraised: cmd(shop,"appraise")
	cmd(shop,"open"); cmd(shop,"visit")
	return shop

func fair(shop, amount: int=650) -> void:
	act(shop,"evidence",{"amount":amount})
	act(shop,"reassure",{"amount":amount})

func force(shop, amount: int=700) -> void:
	act(shop,"evidence",{"amount":amount})
	act(shop,"firm",{"affront":true})
	act(shop,"ban_threat")
	act(shop,"dismiss")

func day_two(shop) -> void:
	cmd(shop,"close"); cmd(shop,"next_day"); cmd(shop,"open"); cmd(shop,"visit")

func _initialize() -> void:
	var s = fresh()
	check(s.snapshot().session.metrics.w==600 and s.snapshot().session.offer==500 and s.snapshot().gold==120,"N01 opening/cap")
	act(s,"evidence",{"amount":650})
	check(s.snapshot().session.metrics.w==621 and s.snapshot().session.status=="negotiating","N05 evidence not automatic acceptance")
	act(s,"reassure",{"amount":650})
	check(s.snapshot().session.metrics.w==651 and s.snapshot().session.status=="pending" and s.snapshot().gold==120,"N02 fair pending, no transfer")
	var stale: Dictionary=s.snapshot().session
	check(not cmd(s,"move",{"location":"storage:0"}).ok and not cmd(s,"confirm",{"session":stale.session,"revision":stale.revision-1}).ok,"N17 reservation and stale confirmation")
	check(confirm(s).ok and s.snapshot().gold==770 and s.snapshot().customer.wallet==150 and s.snapshot().item.owner==s.snapshot().customer.id,"N02 fair ownership/wallet")
	check(not confirm(s).ok and s.snapshot().receipts.size()==1 and s.snapshot().customer.relationship==6,"N12 duplicate confirm rejected")
	day_two(s)
	check(s.snapshot().return_note.contains("fairness") and s.snapshot().session.is_empty(),"N11 helpful return without duplicate relic")
	s=fresh(); force(s)
	check(s.snapshot().session.final and s.snapshot().session.offer==700 and s.snapshot().session.metrics.w==702 and s.snapshot().customer.relationship==-8,"N03 coercion")
	check(confirm(s).ok and s.snapshot().gold==820 and s.snapshot().customer.wallet==100 and s.snapshot().customer.trust==38,"N03 confirmed coercive sale")
	day_two(s)
	check(s.snapshot().return_note.contains("threat") and s.snapshot().scheduled.size()==2,"N11 guarded return and private grievance")
	s=fresh(); force(s); act(s,"reject")
	check(s.snapshot().gold==120 and s.snapshot().customer.wallet==800 and s.snapshot().session.status=="closed" and s.snapshot().reservation.is_empty() and s.snapshot().customer.memories.size()==1,"N10 reject final, actual threat persists")
	for a in [721,800]:
		s=fresh(); force(s,a)
		check(s.snapshot().session.status=="closed" and s.snapshot().gold==120,"N04 cap %d" % a)
	var c: Dictionary=Shop.read_content(); c.customer.wallet=640
	s=fresh(c); fair(s)
	check(s.snapshot().session.metrics.cap==600 and s.snapshot().session.status=="negotiating","N04 independent wallet limit")
	s=fresh(); act(s,"evidence",{"amount":700}); act(s,"firm",{"affront":true}); act(s,"ban_threat"); var leverage: int=s.snapshot().session.ban
	act(s,"ban_threat"); check(leverage==20 and s.snapshot().session.ban==20,"N06 diminishing returns")
	act(s,"ban_threat"); act(s,"ban_threat")
	check(s.snapshot().session.status=="closed" and s.snapshot().customer.memories.size()==1,"N06 repetition departure/no duplicate memory")
	c=Shop.read_content(); c.customer.ban_credibility=0
	s=fresh(c); act(s,"ban_threat")
	check(s.snapshot().session.ban==0,"N06 zero credibility")
	s=fresh(); act(s,"violence_threat")
	check(s.snapshot().session.status=="closed" and s.snapshot().customer.safety_hold and s.snapshot().customer.relationship==-15,"N07 violence safety exit")
	s=fresh(); act(s,"ban_confirm",{"days":30})
	check(s.snapshot().customer.ban_until==31 and s.snapshot().session.status=="closed","N09 confirmed ban")
	day_two(s); check(not s.snapshot().visited,"N18 ban blocks return")
	s=fresh(); act(s,"end"); day_two(s)
	check(s.snapshot().day==2 and s.snapshot().session.status=="negotiating" and s.snapshot().gold==120,"N13 unsold return")
	s=fresh(); act(s,"evidence",{"amount":625}); act(s,"patient",{"amount":625})
	check(s.snapshot().session.metrics.w==636 and s.snapshot().session.status=="pending","N14 patient route")
	s=fresh({},"user://emporium_test.json",false); act(s,"evidence",{"amount":650})
	check(s.snapshot().session.evidence==0 and s.snapshot().session.metrics.w==600,"N05 unsupported evidence")
	c=Shop.read_content(); c.customer.id="test_other"; c.item.id="test_relic"; c.item.instance="test_instance"
	s=fresh(c); fair(s); check(s.snapshot().session.offer==650 and s.snapshot().session.metrics.w==651,"N15 renamed data unchanged")
	c.customer.pride=95; c.customer.independence=95; c.customer.alternatives=95; c.customer.dependence=10; c.item.condition_pct=75
	s=fresh(c); force(s); check(s.snapshot().session.status=="closed" and s.snapshot().session.metrics.w<700,"N08/N15 alternate traits and condition")
	c=Shop.read_content(); var other: Dictionary=c.item.duplicate(true); other.instance="synthetic_2"; other.location="storage:1"; c.extra_items=[other]
	s=Shop.new(c); check(not cmd(s,"move",{"location":"storage:1"}).ok,"P1 occupied slot rejection")
	check(cmd(s,"select",{"item":"synthetic_2"}).ok and cmd(s,"move",{"location":"shelf:3"}).ok,"P1 generic instance/slot")
	# Synthetic trade only: no barter UI or settlement.
	c=Shop.read_content()
	var compass: Dictionary=c.item.duplicate(true); compass.instance="test_compass"; compass.owner=c.customer.id; compass.perceived_g=65
	var inventory: Dictionary={str(c.item.instance):c.item,"test_compass":compass}
	var terms: Dictionary={"npc_pays_g":550,"shop_item_ids":[c.item.instance],"npc_item_ids":["test_compass"]}
	check(Terms.evaluate(terms,inventory,c.customer,651).ok and Terms.evaluate(terms,inventory,c.customer,651).utility==615,"N16 synthetic barter utility")
	terms.npc_item_ids=["test_compass","test_compass"]
	check(not Terms.evaluate(terms,inventory,c.customer,651).ok,"N16 duplicate goods rejected")
	terms.npc_item_ids=["missing"]
	check(not Terms.evaluate(terms,inventory,c.customer,651).ok,"N16 missing goods rejected")
	terms.npc_item_ids=["test_compass"]; compass.locked=true
	check(not Terms.evaluate(terms,inventory,c.customer,651).ok,"N16 locked goods rejected")
	var path := "user://emporium_test.json"
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	s=fresh({},path); fair(s); var before: Dictionary=s.snapshot()
	check(s.save().ok,"N12 save pending")
	var restored = Shop.new({},path)
	check(restored.load_save().ok and restored.snapshot()==before,"N12 exact reload pending")
	check(confirm(restored).ok and not confirm(restored).ok and restored.save().ok,"N12 settle once after reload")
	var f:=FileAccess.open(path,FileAccess.WRITE); f.store_string("corrupt"); f.close()
	check(restored.load_save().ok and restored.snapshot()==before,"N20 corrupt primary backup")
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var a1=fresh(); var a2=fresh(); force(a1); force(a2)
	check(a1.snapshot()==a2.snapshot(),"N19 deterministic replay")
	check(not Speech.render(N.public_plan(a1.snapshot().session)).contains("720"),"Speech does not expose ceiling")
	print("RESULT: ",passed," passed, ",failed," failed")
	quit(1 if failed>0 else 0)
