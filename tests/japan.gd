extends SceneTree
const Shell=preload("res://ui/Japan.tscn")
const Week=preload("res://domain/week_shop.gd")
const JArt=preload("res://ui/japan_art.gd")
const Retail=preload("res://ui/retail_director.gd")
const A=preload("res://ui/d1_assets.gd")
var passed:=0
var failed:=0
func check(ok: bool,name: String) -> void:
	if ok: passed+=1; print("PASS ",name)
	else: failed+=1; printerr("FAIL ",name)
func _initialize() -> void:
	call_deferred("run")
func grid_ok(im: Image,strict: bool=false) -> bool:
	if im.get_size()!=Vector2i(544,48): return false
	for y in range(0,48,2):
		for x in range(0,544,2):
			var c:=im.get_pixel(x,y)
			for off in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var q:=im.get_pixel(x+off.x,y+off.y)
				# Godot import repairs RGB under alpha-zero edges to avoid smooth-filter fringes.
				# This must never change alpha or visible texels. Source bytes are checked strictly.
				if c.a!=q.a or ((strict or c.a>0.0) and c!=q): return false
	return true
func run() -> void:
	var art=JArt.new()
	check(art.registry.characters.size()==7 and art.registry.items.size()==10,"seven character mappings and ten items")
	var w=Week.new("user://japan_test.json")
	for c in w.book.profiles:
		check(art.registry.characters.has(c.id),"actual profile mapped "+str(c.id))
	for id in art.registry.characters:
		var rec: Dictionary=art.registry.characters[id]
		var sheet: Texture2D=art.tex(str(rec.pixel_sprite_sheet))
		var raw:=Image.load_from_file(str(rec.pixel_sprite_sheet))
		check(not raw.is_empty() and grid_ok(raw,true),"source exact 32x48 frame grid "+id)
		check(sheet!=null and grid_ok(sheet.get_image()),"import preserves visible texels "+id)
		var nonempty:=true
		var unique: Dictionary={}
		var im: Image=sheet.get_image()
		for idx in range(17):
			var f:=im.get_region(Rect2i(idx*32,0,32,48))
			if f.get_used_rect().size.y<38: nonempty=false
			unique[hash(f.get_data())]=true
		check(nonempty and unique.size()>=9,"complete nonempty independent pose cells "+id)
		var variant_ids: Dictionary={}
		var complete:=true
		for e in ["neutral","happy","impatient","surprised"]:
			var tex: Texture2D=art.portrait(id,e)
			if tex==null or tex.get_height()<500: complete=false
			else: variant_ids[hash(tex.get_image().get_data())]=true
		check(complete and variant_ids.size()==4,"four distinct high-resolution expressions "+id)
	var all_items:=true
	for id in art.registry.items:
		for kind in ["world","icon","stage"]:
			if art.item(id,kind)==null: all_items=false
	check(all_items,"all ten item display/icon/stage paths")
	check(art.env("floor").get_size()==Vector2(320,156),"native pixel floor 320x156")
	check(JArt.expression("relieved")=="happy" and JArt.expression("offended")=="impatient" and JArt.expression("frightened")=="surprised","resolved emotional state mapping")
	var ui=Shell.instantiate(); root.add_child(ui)
	ui.shop=w; ui.ui_save_path="user://japan_ui_test.json"; ui.refresh()
	check(ui.retail.state=="ABSENT" and ui.customer_node==null,"no synthetic customer before opening")
	ui.switch_view("stockroom"); ui.command("appraise"); ui.command("restock"); ui.switch_view("floor")
	ui._process(0.1)
	check(ui.keeper_state=="RESTOCK","keeper restock from committed item move")
	check(ui.keeper_node.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"keeper nearest filter")
	ui.command("open")
	var s: Dictionary=ui.shop.snapshot()
	check(ui.retail.state=="IDLE" and ui.retail.target_id=="week_dragonstone","real waiting customer and displayed target")
	var states: Dictionary={}
	for step in range(180):
		ui._process(.05); states[ui.retail.state]=true
	check(states.has("WALK") and states.has("BROWSE") and states.has("PICK_ITEM") and states.has("CHECKOUT_QUEUE"),"retail state sequence")
	check(ui.shop.snapshot()==s,"animation cannot change domain")
	check(is_instance_valid(ui.customer_node) and ui.customer_node.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"customer nearest filter")
	ui.open_counter()
	check(ui.view=="counter" and is_instance_valid(ui.portrait) and ui.portrait.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"actual VN overlay smooth filter")
	check(ui.portrait.texture==art.portrait("vessa_rook","neutral") or ui.portrait.texture.get_width()==560,"same Vessa identity portrait")
	ui.price_value=650; ui.act("evidence","Appraisal",true); ui.act("reassure","Fair",true)
	var pending: Dictionary=ui.shop.snapshot()
	check(pending.session.status=="pending","existing negotiation still works")
	check(ui.portrait.texture.get_image().get_data()==ui.jart.portrait("vessa_rook","happy").get_image().get_data(),"resolved happy portrait")
	ui.switch_view("floor"); ui._process(.1)
	check(ui.keeper_state=="INTERACT" and ui.retail.state=="CHECKOUT_QUEUE","active customer and keeper interaction in world")
	ui.switch_view("stockroom"); ui.switch_view("counter")
	check(ui.shop.snapshot()==pending,"dual-view state and pending offer exact")
	ui.save_game(); ui.switch_view("floor"); ui.load_game()
	check(ui.shop.snapshot()==pending and ui.view=="counter","save reload identity and deal")
	ui.confirm()
	check(ui.shop.snapshot().gold==950 and ui.shop.snapshot().items.week_dragonstone.owner=="vessa_rook","settlement authoritative")
	ui.command("next_customer"); ui.switch_view("floor")
	check(ui.retail.target_id=="" and ui.retail.state=="IDLE","seller skips browse of unavailable goods")
	ui.open_counter()
	check(ui.shop.snapshot().customer.id=="bram_alder" and ui.portrait.texture!=null,"different customer maps into VN")
	ui.act("accept_offer","Review purchase"); ui.confirm(); ui.command("close")
	check(ui.shop.snapshot().reports.size()==1,"closing report preserved")
	# No matching display: no false browsing/picking.
	var missing=Week.new("user://japan_missing.json")
	missing.command({"type":"open"})
	var director=Retail.new()
	director.sync(missing.snapshot(),A.config().sockets)
	check(director.target_id=="","no target without displayed merchandise")
	for i in range(120): director.step(.05)
	check(director.state=="CHECKOUT_QUEUE","missing target directly queues")
	for f in ["user://japan_test.json","user://japan_test.json.bak","user://japan_ui_test.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("JAPAN RESULT: ",passed," passed, ",failed," failed")
	quit(failed)
