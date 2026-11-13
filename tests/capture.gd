extends SceneTree
const Shell = preload("res://ui/GateC.tscn")
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/logs/" + name + ".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	var ui = Shell.instantiate()
	root.add_child(ui)
	ui.command("move",{"location":"shelf:0"})
	ui.command("appraise")
	ui.command("open")
	await capture("floor_1280")
	ui.command("visit")
	ui.price_value = 650
	ui.act("evidence","Appraisal",true)
	ui.act("reassure","Fair offer",true)
	await capture("counter_1280")
	ui.ledger = true
	ui.refresh()
	await capture("ledger_1280")
	root.size = Vector2i(960,540)
	await capture("ledger_960")
	ui.ledger = false
	ui.refresh()
	await capture("counter_960")
	ui.switch_view("floor")
	await create_timer(0.2).timeout
	await capture("floor_960")
	quit()
