extends SceneTree
const Shell=preload("res://ui/Japan.tscn")
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("PWD")+"/.artifacts/logs/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	var ui=Shell.instantiate(); root.add_child(ui)
	ui.dialogue_speed=0
	ui.switch_view("stockroom"); ui.command("appraise"); ui.command("restock")
	await capture("japan_stockroom_1280")
	ui.switch_view("floor"); ui.command("open")
	await create_timer(1.5).timeout
	await capture("japan_walk_1280")
	await create_timer(1.8).timeout
	await capture("japan_browse_1280")
	await create_timer(2.5).timeout
	await capture("japan_floor_1280")
	root.size=Vector2i(960,540); await capture("japan_floor_960")
	root.size=Vector2i(1280,720); ui.open_counter(); await create_timer(.4).timeout
	await capture("japan_vessa_neutral")
	ui.price_value=650; ui.act("evidence","Appraisal",true); ui.act("reassure","Fair offer",true); await create_timer(.3).timeout
	await capture("japan_vessa_happy")
	ui.ledger=true; ui.refresh(); root.size=Vector2i(960,540)
	await capture("japan_ledger_960")
	ui.confirm(); ui.command("next_customer"); ui.open_counter(); await create_timer(.4).timeout
	await capture("japan_bram_960")
	ui.act("accept_offer","Review purchase"); ui.confirm(); ui.command("close")
	await capture("japan_closing_960")
	quit()
