extends SceneTree
const Shell = preload("res://ui/GateC.tscn")
const Shop = preload("res://domain/shop.gd")
var failures := 0
func check(value: bool, name: String) -> void:
	if value: print("PASS ",name)
	else: failures += 1; printerr("FAIL ",name)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = Shell.instantiate(); root.add_child(ui)
	ui.shop = Shop.new({},"user://gate_c_test.json")
	ui.ui_save_path = "user://gate_c_test_ui.json"
	ui.refresh()
	ui.command("move",{"location":"shelf:0"}); ui.command("appraise"); ui.command("open"); ui.command("visit")
	var before: Dictionary = ui.shop.snapshot()
	ui.switch_view("floor"); ui.switch_view("counter")
	check(before == ui.shop.snapshot(),"navigation is pure")
	ui.price_value = 650; ui.act("evidence","Appraisal",true); ui.act("reassure","Fair offer",true)
	var pending: Dictionary = ui.shop.snapshot()
	check(pending.session.status == "pending","pending deal")
	check(ui.item_stage.size == Vector2(200,160) and ui.item_stage.position.y+ui.item_stage.size.y==460,"compact crystal stage on counter")
	var thumb_found := false
	for child in ui.root.get_children():
		if child is TextureRect and child.position == Vector2(955,91):
			thumb_found = child.size == Vector2(74,91)
	check(thumb_found,"HUD thumbnail stays inside frame")
	ui.ledger = true; ui.refresh(); ui.switch_view("floor"); ui.switch_view("counter")
	check(pending == ui.shop.snapshot(),"reservation and offer survive switching")
	ui.save_game(); ui.switch_view("floor"); ui.load_game()
	check(ui.shop.snapshot() == pending and ui.view == "counter" and ui.ledger,"save/load restores domain and presentation")
	ui.confirm(); var settled: Dictionary = ui.shop.snapshot(); ui.confirm()
	check(settled == ui.shop.snapshot() and settled.gold == 770 and settled.receipts.size() == 1,"confirm exactly once")
	check(ui.history.size() >= 5,"conversation history retained")
	for path in ["user://gate_c_test.json","user://gate_c_test.json.bak","user://gate_c_test.json.tmp","user://gate_c_test_ui.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Presentation failures: ",failures); quit(failures)
