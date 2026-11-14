extends SceneTree
const Week=preload("res://domain/week_shop.gd")
const Data=preload("res://domain/week_data.gd")
const N=preload("res://domain/negotiation.gd")
const Provider=preload("res://domain/offline_provider.gd")
var passed:=0
var failed:=0
func check(ok: bool,name: String) -> void:
	if ok: passed+=1; print("PASS ",name)
	else: failed+=1; printerr("FAIL ",name)
func cmd(w,kind: String,args: Dictionary={}) -> Dictionary:
	var a:=args.duplicate(true); a.type=kind
	return w.command(a)
func act(w,kind: String,args: Dictionary={}) -> Dictionary:
	var n: Dictionary=w.snapshot().session
	var a:=args.duplicate(true); a.type=kind
	return cmd(w,"act",{"session":n.session,"revision":n.revision,"action":a})
func confirm(w) -> Dictionary:
	var n: Dictionary=w.snapshot().session
	return cmd(w,"confirm",{"session":n.session,"revision":n.revision})
func select(w,id: String) -> void:
	cmd(w,"select",{"item":id})
func display(w,id: String,loc: String) -> void:
	select(w,id); cmd(w,"move",{"location":loc})
func end_visit(w) -> void:
	if w.active_week(w.snapshot()): act(w,"end")
func advance(w) -> void:
	cmd(w,"close"); cmd(w,"next_day")
func _initialize() -> void:
	var path: String="user://week_test.json"
	var w=Week.new(path)
	check(w.snapshot().profiles.size()==6 and w.book.items.size()==10,"six profiles ten item definitions")
	check(w.snapshot().items.size()==5 and w.snapshot().gold==300,"opening stock and cash")
	var c: Dictionary=w.snapshot().profiles.marla_fen
	check(N.cap(c)==80 and c.reserve==0 and c.claimed==80,"hard cash budget")
	var base: Dictionary=w.book.profiles[0]
	var item: Dictionary=Data.make_item(w.book,"dragonstone","synthetic_test","shop","shelf:0")
	var policy: Dictionary=Data.baseline().policy
	var a: Dictionary=N.resolve(N.start(base,item,policy,1),{"type":"ban_threat"},base,item,policy)
	var strong: Dictionary=w.snapshot().profiles.ser_caldus
	var z: Dictionary=N.resolve(N.start(strong,item,policy,1),{"type":"ban_threat"},strong,item,policy)
	check(a.state.ban>z.state.ban and a.state.metrics.w>z.state.metrics.w,"different resistance same intent")
	var blunt: Dictionary=w.snapshot().profiles.bram_alder
	var first: Dictionary=N.resolve(N.start(blunt,item,policy,1),{"type":"banter"},blunt,item,policy)
	var second: Dictionary=N.resolve(first.state,{"type":"banter"},blunt,item,policy)
	check(first.state.rapport>0 and second.state.rapport==first.state.rapport and second.state.anger>first.state.anger,"banter and repeated rapport bounded")
	check(cmd(w,"dispatch").ok and w.snapshot().gold==210,"paid committed expedition")
	var expedition: Dictionary=w.snapshot().expedition
	check(w.save().ok,"save committed expedition")
	var restored=Week.new(path)
	check(restored.load_save().ok and restored.snapshot().expedition==expedition,"reload cannot reroll outcome")
	w=restored
	check(Data.appraisal(w.snapshot().item,0).condition=="Unknown","unknown appraisal property")
	check(cmd(w,"appraise").ok and Data.appraisal(w.snapshot().item,0).provenance=="Unknown","basic evidence not provenance")
	cmd(w,"restock")
	check(w.snapshot().items.week_dragonstone.location=="shelf:0" and w.snapshot().items.week_knights_blade.location=="shelf:2","compatible restock")
	cmd(w,"open"); cmd(w,"visit")
	check(w.snapshot().customer.id=="vessa_rook" and w.snapshot().session.offer==500,"Vessa day one")
	act(w,"evidence",{"amount":650}); act(w,"reassure",{"amount":650})
	check(w.snapshot().session.status=="pending" and w.snapshot().gold==210,"fair pending no transfer")
	check(confirm(w).ok and w.snapshot().gold==860 and w.snapshot().items.week_dragonstone.owner=="vessa_rook","cash sale")
	check(not confirm(w).ok and w.snapshot().receipts.size()==1,"duplicate cash settlement blocked")
	cmd(w,"next_customer"); cmd(w,"visit")
	check(w.snapshot().visit_goal=="sell" and w.snapshot().item.owner=="bram_alder","walk-in seller owns item")
	var before: Dictionary=w.snapshot()
	act(w,"accept_offer")
	check(w.snapshot().session.status=="pending" and w.snapshot().gold==before.gold,"purchase pending")
	check(confirm(w).ok and w.snapshot().gold==795 and w.snapshot().item.owner=="shop" and w.snapshot().item.acquisition_cost==65,"purchase atomic cost")
	check(not confirm(w).ok,"duplicate purchase blocked")
	cmd(w,"close")
	var report: Dictionary=w.snapshot().reports.back()
	check(report.sales==650 and report.purchases==65 and report.expenses==0 and report.expedition_outlay==90 and report.cogs==360 and report.profit==290 and report.closing-report.opening==report.cash_movement,"day one ledger reconciles")
	cmd(w,"next_day")
	check(w.snapshot().day==2 and w.snapshot().profiles.vessa_rook.history_modifier==10,"return memory scheduled")
	check(cmd(w,"expertise").ok and cmd(w,"upgrade",{"upgrade":"storage"}).ok and cmd(w,"upgrade",{"upgrade":"sign"}).ok,"expertise and two upgrades")
	select(w,"week_emberroot"); cmd(w,"appraise")
	check(Data.appraisal(w.snapshot().item,1).provenance!="Unknown","trained appraisal unlocks origin")
	cmd(w,"open"); cmd(w,"visit")
	check(w.snapshot().customer.id=="marla_fen","day two buyer")
	act(w,"counter",{"amount":81})
	check(w.snapshot().session.status!="pending","hard budget refusal")
	act(w,"counter",{"amount":60})
	if w.snapshot().session.status!="pending": act(w,"accept_offer")
	check(confirm(w).ok,"Marla buys")
	cmd(w,"next_customer"); cmd(w,"visit")
	check(w.snapshot().visit_goal=="social" and w.snapshot().return_note.contains("fairness"),"Vessa actual returning visit")
	act(w,"small_talk"); end_visit(w)
	advance(w)
	check(w.snapshot().day==3 and w.snapshot().expedition.state=="returned" and w.snapshot().rumor.state=="known","expedition resolved and rumor eligible")
	var count: int=w.snapshot().items.size()
	w.save(); restored=Week.new(path); restored.load_save(); w=restored
	check(w.snapshot().items.size()==count and w.snapshot().expedition.state=="returned","loot persists once")
	check(cmd(w,"pay_debt").ok and w.snapshot().debt.paid==250,"installment payment")
	cmd(w,"open"); cmd(w,"visit")
	check(w.snapshot().customer.id=="bram_alder" and w.snapshot().visit_goal=="barter","returning salvager barter")
	check(act(w,"ask_rumor").ok and w.snapshot().rumor.state=="disclosed" and w.snapshot().items.week_dragonstone.demand_pct==120,"authorized disclosure bounded demand")
	check(not act(w,"ask_rumor").ok,"duplicate disclosure blocked")
	check(act(w,"barter").ok and w.snapshot().reservation.has("terms"),"barter proposal")
	var pending: Dictionary=w.snapshot()
	w.save(); restored=Week.new(path); restored.load_save(); w=restored
	check(w.snapshot()==pending,"pending barter save exact")
	check(confirm(w).ok and w.snapshot().items.week_knights_blade.owner=="bram_alder" and w.snapshot().items[pending.session.trade_item].owner=="shop","barter atomic ownership")
	check(not confirm(w).ok,"duplicate barter blocked")
	cmd(w,"next_customer"); cmd(w,"visit")
	check(w.snapshot().customer.id=="ser_caldus","resistant customer visits")
	act(w,"violence_threat")
	check(w.snapshot().customer.safety_hold and w.snapshot().session.status=="closed","distinct violence consequence")
	advance(w)
	check(w.snapshot().day==4,"day four")
	cmd(w,"open"); cmd(w,"visit"); act(w,"accept_offer"); check(confirm(w).ok,"broker sells compass")
	cmd(w,"next_customer"); cmd(w,"visit"); check(w.snapshot().visit_goal=="complaint","complaint visit")
	act(w,"reassure"); end_visit(w)
	cmd(w,"next_customer")
	check(w.snapshot().customer.id=="tovin_reed","sign upgrade attracts additional visitor")
	advance(w)
	check(w.snapshot().day==5 and w.snapshot().rumor.state=="expired" and w.snapshot().items.week_dragonstone.demand_pct==100,"demand expires")
	var compass: String=""
	for i in w.snapshot().items.values():
		if i.id=="star_compass" and i.owner=="shop": compass=i.instance
	if compass!="":
		var loc: String="shelf:0"
		if w.owned_slot(w.snapshot(),loc): loc="shelf:1"
		display(w,compass,loc)
	cmd(w,"open"); cmd(w,"visit")
	check(w.snapshot().customer.id=="tovin_reed","day five trader")
	end_visit(w); cmd(w,"next_customer"); cmd(w,"visit"); end_visit(w); cmd(w,"close")
	check(w.snapshot().reports.size()==5 and not cmd(w,"next_day").ok,"five-day scenario closes")
	var gold: int=300
	for r in w.snapshot().reports:
		gold+=int(r.cash_movement)
		check(r.closing-r.opening==r.cash_movement and r.sales+r.barter_cash-r.purchases-r.expenses-r.expedition_outlay-r.debt_payment==r.cash_movement,"daily report reconciliation %d"%r.day)
	check(gold==w.snapshot().gold,"week cash reconciles")
	w.save(); restored=Week.new(path); check(restored.load_save().ok and restored.snapshot()==w.snapshot(),"five-day save exact")
	# Independent poor merchant and stale/insufficient transaction cases.
	var poor=Week.new("user://week_poor.json")
	cmd(poor,"dispatch"); cmd(poor,"expertise"); cmd(poor,"upgrade",{"upgrade":"storage"}); cmd(poor,"upgrade",{"upgrade":"sign"})
	cmd(poor,"open"); cmd(poor,"visit"); end_visit(poor); cmd(poor,"next_customer"); cmd(poor,"visit")
	before=poor.snapshot(); act(poor,"accept_offer")
	check(poor.snapshot()==before and poor.snapshot().session.status!="pending","insufficient funds no purchase")
	end_visit(poor); advance(poor); cmd(poor,"open"); advance(poor); cmd(poor,"open"); cmd(poor,"close")
	check(poor.snapshot().debt.warning and cmd(poor,"next_day").ok,"missed installment recoverable")
	var poor_barter=Week.new("user://week_poor_barter.json")
	for p in poor_barter.book.profiles:
		if p.id=="bram_alder": p.wallet=10
	poor_barter.reset(); cmd(poor_barter,"restock"); cmd(poor_barter,"open"); advance(poor_barter); cmd(poor_barter,"open"); advance(poor_barter); cmd(poor_barter,"open"); cmd(poor_barter,"visit")
	before=poor_barter.snapshot(); check(not act(poor_barter,"barter").ok and poor_barter.snapshot()==before,"insufficient barter cash rejects both sides atomically")
	check(Provider.render({"speech_act":"counter","offer":500,"expression":"neutral"},{"style":"blunt"}).contains("500g"),"offline dialogue authorized amount")
	for f in [path,path+".bak",path+".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("WEEK RESULT: ",passed," passed, ",failed," failed")
	quit(failed)
