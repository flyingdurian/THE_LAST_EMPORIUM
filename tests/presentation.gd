extends SceneTree
const Shell = preload("res://ui/GateC.tscn")
var failures := 0
func check(value: bool, name: String) -> void:
	if value: print("PASS ",name)
	else: failures += 1; printerr("FAIL ",name)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = Shell.instantiate(); root.add_child(ui)
	ui.command("move",{"location":"shelf:0"}); ui.command("appraise"); ui.command("open"); ui.command("visit")
	var before: Dictionary = ui.shop.snapshot()
	ui.switch_view("floor"); ui.switch_view("counter")
	check(before == ui.shop.snapshot(),"navigation is pure")
	ui.price_value = 650; ui.act("evidence","Appraisal",true); ui.act("reassure","Fair offer",true)
	var pending: Dictionary = ui.shop.snapshot()
	check(pending.session.status == "pending","pending deal")
	ui.ledger = true; ui.refresh(); ui.switch_view("floor"); ui.switch_view("counter")
	check(pending == ui.shop.snapshot(),"reservation and offer survive switching")
	ui.confirm(); var settled: Dictionary = ui.shop.snapshot(); ui.confirm()
	check(settled == ui.shop.snapshot() and settled.gold == 770 and settled.receipts.size() == 1,"confirm exactly once")
	check(ui.history.size() >= 5,"conversation history retained")
	print("Presentation failures: ",failures); quit(failures)
