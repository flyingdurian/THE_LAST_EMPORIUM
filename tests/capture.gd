extends SceneTree
const Shell = preload("res://ui/GateC.tscn")
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("PWD")+"/.artifacts/logs/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	var ui=Shell.instantiate(); root.add_child(ui); ui.dialogue_speed=0
	ui.command("move",{"location":"shelf:0"}); ui.command("appraise")
	ui.command("select",{"item":"i_sword_001"}); ui.command("move",{"location":"shelf:2"})
	ui.command("select",{"item":"i_shield_001"}); ui.command("move",{"location":"shelf:3"})
	ui.switch_view("stockroom"); await capture("stockroom_1280")
	ui.switch_view("counter"); await capture("shield_inspection")
	ui.command("select",{"item":"i_sword_001"}); await capture("sword_inspection")
	ui.command("select",{"item":"i_dragon_001"}); await capture("dragon_inspection")
	ui.switch_view("floor"); ui.command("open"); await capture("floor_1280")
	ui.command("visit"); await capture("counter_neutral")
	ui.price_value=650; ui.act("evidence","Appraisal",true); ui.act("reassure","Fair offer",true); await capture("counter_1280")
	ui.ledger=true; ui.refresh(); await capture("ledger_1280")
	root.size=Vector2i(960,540); await capture("ledger_960")
	ui.ledger=false; ui.refresh(); await capture("counter_960")
	ui.confirm(); await create_timer(0.6).timeout
	ui.command("close"); ui.command("next_day"); ui.command("open"); ui.command("visit"); await capture("return_960")
	ui.shop.reset(); ui.command("move",{"location":"shelf:0"}); ui.command("open"); ui.command("visit"); ui.act("insult","Rude"); await capture("counter_offended")
	quit()
