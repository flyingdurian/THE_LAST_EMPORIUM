extends SceneTree
const Shell=preload("res://ui/Week.tscn")
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
	await capture("week_stockroom")
	ui.switch_view("floor"); ui.open_drawer("journal"); await capture("week_journal")
	ui.command("dispatch"); ui.open_drawer("journal"); ui.command("open")
	await capture("week_floor")
	ui.open_counter(); ui.price_value=650; ui.act("evidence","Appraisal",true); ui.act("reassure","Fair offer",true)
	await capture("week_vessa")
	ui.confirm(); ui.command("next_customer"); ui.open_counter()
	await create_timer(0.4).timeout
	await capture("week_seller")
	ui.act("accept_offer","Review purchase"); ui.confirm(); ui.command("close")
	await capture("week_closing")
	root.size=Vector2i(960,540); await capture("week_closing_960")
	ui.command("next_day"); ui.command("open"); ui.open_counter()
	await create_timer(0.4).timeout
	await capture("week_marla_960")
	ui.act("end","Until next time."); ui.command("next_customer"); ui.open_counter(); ui.act("end","Good day."); ui.command("close"); ui.command("next_day"); ui.command("open"); ui.open_counter()
	ui.act("ask_rumor","What did you learn at the quarry?"); ui.act("barter","Let us trade."); root.size=Vector2i(1280,720); await create_timer(0.4).timeout
	await capture("week_barter"); ui.ledger=true; ui.refresh(); root.size=Vector2i(960,540); await capture("week_barter_ledger_960")
	quit()
