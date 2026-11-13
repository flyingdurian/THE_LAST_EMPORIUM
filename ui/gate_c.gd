extends Control
## Gate D2: presentation adapter. No authority over settlement or customer state.
const Shop = preload("res://domain/shop.gd")
const Negotiation = preload("res://domain/negotiation.gd")
const Speech = preload("res://domain/dialogue.gd")
const OWNER = preload("res://art/merchant_floor.png")
const Presentation = preload("res://ui/d2_presentation.gd")
const Ambient = preload("res://ui/ambient.gd")
const ITEM = preload("res://art/dragonstone.png")
const SAVE_UI = "user://emporium_gate_d1_ui.json"
const Assets = preload("res://ui/d1_assets.gd")
const Fixtures = preload("res://domain/fixtures.gd")
var shop = Shop.new(Assets.content())
var selected_fixture := "shelf"
var audio_service: Node
const AudioService = preload("res://audio/manager.gd")
var portrait: TextureRect
var dialogue_label: Label
var dialogue_tween: Tween
var portrait_event := ""
var reveal_next := false
var gold_feedback := 0
var dialogue_speed := 1 # 0 instant, 1 normal, 2 slow
var floor_items: Dictionary = {}
var counter_items: Dictionary = {}
var counter_room: TextureRect
var counter_surface: TextureRect
var view := "floor"
var drawer := ""
var ledger := false
var debug := false
var history: Array = []
var history_session := -1
var message := ""
var price_value := 650
var price: SpinBox
var root: Control
var item_stage: TextureRect
var last_line := ""
var transition: Tween
var last_snapshot: Dictionary = {}
var owner_pos := Vector2(650,642)
var ui_save_path := SAVE_UI
var owner_sprite: TextureRect
var heading_font: SystemFont
var conversation_font: SystemFont
const FLOOR_OBSTACLES := [Rect2(290,380,240,155),Rect2(780,380,225,155),Rect2(210,555,260,150),Rect2(840,555,240,150)]
const INK = Color("251c19")
const GOLD = Color("bc945b")
const PAPER = Color("f2dfbd")
const MUTED = Color("d0bba0")
const GREEN = Color("355546")

func _ready() -> void:
	get_window().min_size = Vector2i(960,540)
	audio_service = get_tree().root.get_node_or_null("EmporiumAudio")
	if audio_service == null:
		audio_service = AudioService.new(); add_child(audio_service)
	heading_font = SystemFont.new(); heading_font.font_names = PackedStringArray(["Georgia","DejaVu Serif","Noto Serif"]); heading_font.font_weight = 700
	conversation_font = SystemFont.new(); conversation_font.font_names = PackedStringArray(["Georgia","DejaVu Serif","Noto Serif"])
	var prefs := ConfigFile.new()
	if prefs.load("user://emporium_presentation.cfg")==OK: dialogue_speed = clampi(int(prefs.get_value("dialogue","speed",1)),0,2)
	refresh()

func box(parent: Control, rect: Rect2, color: Color = INK) -> Panel:
	var p := Panel.new()
	p.position = rect.position; p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color; style.border_color = GOLD
	style.set_border_width_all(1); style.set_corner_radius_all(7)
	style.shadow_color = Color(0.04,0.02,0.01,0.45); style.shadow_size = 3; style.shadow_offset = Vector2(0,2)
	p.add_theme_stylebox_override("panel",style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func label(parent: Control, text: String, rect: Rect2, font_size: int = 18, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text; l.position = rect.position; l.size = rect.size
	l.add_theme_font_size_override("font_size",font_size)
	if font_size >= 23 and heading_font != null: l.add_theme_font_override("font",heading_font)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func btn(parent: Control, text: String, rect: Rect2, fn: Callable, disabled: bool = false, primary: bool = false) -> Button:
	var b := Button.new(); b.text = text; b.position = rect.position; b.size = rect.size
	b.disabled = disabled; b.add_theme_font_size_override("font_size",17)
	for mode in ["normal","hover","pressed","disabled","focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = GREEN if primary else Color("4b3226")
		if mode == "hover": sb.bg_color = sb.bg_color.lightened(0.16)
		if mode == "disabled": sb.bg_color = Color("4a423a")
		if mode == "focus": sb.bg_color = Color(0,0,0,0)
		sb.border_color = GOLD; sb.set_border_width_all(1); sb.set_corner_radius_all(5)
		b.add_theme_stylebox_override(mode,sb)
	b.pressed.connect(func(): audio_service.cue("click"); fn.call()); parent.add_child(b)
	return b

func pic(parent: Control, texture: Texture2D, rect: Rect2, cover: bool = false) -> TextureRect:
	var t := TextureRect.new()
	# Set expansion before the texture and final rectangle; otherwise the native texture size becomes the minimum.
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = texture; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t); t.position = rect.position; t.size = rect.size
	return t

func active(s: Dictionary) -> bool:
	return not s.session.is_empty() and s.session.status in ["negotiating","pending"]

func waiting(s: Dictionary) -> bool:
	return Presentation.presence(s) == "waiting"

func social_present(s: Dictionary) -> bool:
	return Presentation.presence(s) == "social"

func switch_view(target: String) -> void:
	if view == target: return
	view = target; drawer = ""; debug = false
	refresh()
	root.modulate.a = 0.4
	if transition and transition.is_valid(): transition.kill()
	transition = create_tween(); transition.tween_property(root,"modulate:a",1.0,0.15)

func open_status() -> void:
	if view != "floor":
		view = "floor"; drawer = "status"; refresh()
	else: open_drawer("status")

func open_drawer(kind: String) -> void:
	drawer = "" if drawer == kind else kind
	refresh()

func command(kind: String, args: Dictionary = {}, player_line: String = "") -> void:
	var cmd := args.duplicate(true); cmd["type"] = kind
	var before := shop.snapshot()
	var r: Dictionary = shop.command(cmd)
	if not r.ok:
		message = str(r.get("error","Action rejected")); refresh(); return
	message = ""
	var after := shop.snapshot()
	if kind == "visit":
		portrait_event = "enter"; reveal_next = true; audio_service.cue("arrival")
	elif kind in ["act","confirm"]:
		reveal_next = true
		if active(before) and not active(after): portrait_event = "exit"
		elif before.session.get("expression","") != after.session.get("expression",""): portrait_event = "reaction"
		if int(after.gold) > int(before.gold):
			gold_feedback = int(after.gold)-int(before.gold); audio_service.cue("sale")
		elif after.session.get("expression","") in ["offended","fearful","frightened","distressed"]: audio_service.cue("tension")
	if kind == "visit" and not after.session.is_empty() and (before.session.is_empty() or before.session.session != after.session.session):
		history = []; history_session = int(after.session.session)
		append_npc(after)
	elif kind in ["act","confirm"] and not after.session.is_empty():
		if player_line != "": history.append({"speaker":"You","text":player_line})
		append_npc(after)
	elif kind == "visit" and social_present(after):
		history = [{"speaker":str(after.customer.name),"text":str(after.return_note)}]; history_session = -1
	elif kind == "next_day":
		history = []; history_session = -1; last_line = ""
	if kind == "visit": view = "counter"; drawer = ""
	if kind in ["act","confirm"] and (not active(after) or after.session.status == "pending"): drawer = ""
	if kind == "close" or kind == "next_day": view = "floor"; drawer = ""
	refresh()

func append_npc(s: Dictionary) -> void:
	last_line = Speech.render(Negotiation.public_plan(s.session))
	history.append({"speaker":str(s.customer.name),"text":last_line})

func act(kind: String, text: String, with_price: bool = false, extra: Dictionary = {}) -> void:
	var s := shop.snapshot()
	if not active(s): return
	var a := extra.duplicate(true); a["type"] = kind
	if with_price: a["amount"] = price_value
	command("act",{"session":s.session.session,"revision":s.session.revision,"action":a},text)

func confirm() -> void:
	var s := shop.snapshot()
	if not active(s) or s.session.status != "pending": return
	command("confirm",{"session":s.session.session,"revision":s.session.revision},"Confirm sale.")

func open_counter() -> void:
	var s := shop.snapshot()
	if waiting(s): command("visit")
	else: switch_view("counter")

func refresh() -> void:
	if transition and transition.is_valid(): transition.kill()
	transition = null
	if dialogue_tween and dialogue_tween.is_valid(): dialogue_tween.kill()
	dialogue_tween = null; dialogue_label = null; portrait = null; item_stage = null; counter_room = null; counter_surface = null
	floor_items.clear(); counter_items.clear()
	owner_sprite = null
	if is_instance_valid(root):
		remove_child(root); root.queue_free()
	root = Control.new(); root.size = Vector2(1280,720); add_child(root)
	var s := shop.snapshot(); last_snapshot = s
	var bg := ColorRect.new(); bg.color = INK; bg.size = root.size; bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bg)
	if view == "floor": draw_floor(s)
	elif view == "stockroom": draw_stockroom(s)
	else: draw_counter(s)
	draw_header(s)
	if drawer == "menu": draw_menu()
	box(root,Rect2(0,684,1280,36),Color("201817"))
	label(root,message if message != "" else ("Select a fixture, counter or stockroom  •  Offline prototype" if view == "floor" else "Offline prototype  •  Structured actions, no live AI"),Rect2(20,690,1000,25),15,MUTED)
	btn(root,"Debug",Rect2(1175,688,86,27),func(): debug = not debug; refresh())
	if debug: draw_debug()
	if gold_feedback > 0:
		var toast := label(root,"+%dg" % gold_feedback,Rect2(485,66,140,38),26,Color("f4ce77"))
		var ft := create_tween().bind_node(toast).set_parallel(true)
		ft.tween_property(toast,"position:y",32.0,1.1); ft.tween_property(toast,"modulate:a",0.0,1.1)
		gold_feedback = 0
	portrait_event = ""; reveal_next = false

func draw_header(s: Dictionary) -> void:
	box(root,Rect2(0,0,1280,62),Color("201817"))
	label(root,"THE LAST EMPORIUM",Rect2(18,14,350,40),27)
	label(root,"Day %d" % s.day,Rect2(390,19,90,30),20)
	label(root,"%dg" % s.gold,Rect2(484,19,104,30),20,GOLD)
	btn(root,"SFX off" if audio_service.muted else "SFX on",Rect2(585,17,61,28),func(): audio_service.set_muted(not audio_service.muted); refresh())
	var status_text := str(s.phase).capitalize()
	btn(root,"Shop: " + status_text,Rect2(648,10,136,42),func(): open_status())
	btn(root,"Menu",Rect2(792,10,76,42),func(): open_drawer("menu"))
	btn(root,"Shop Floor",Rect2(877,10,119,42),func(): switch_view("floor"),false,view == "floor")
	btn(root,"Counter" + (" •" if waiting(s) else ""),Rect2(1005,10,113,42),func(): switch_view("counter"),false,view == "counter")
	btn(root,"Stockroom",Rect2(1127,10,135,42),func(): switch_view("stockroom"),false,view == "stockroom")

func draw_floor(s: Dictionary) -> void:
	# Full empty-room composition; only fixed architecture and counter are painted.
	var plate := pic(root,Assets.texture(str(Assets.config().floor)),Rect2(0,62,1280,622))
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	# Stationary shopkeeper, independent of the background; the counter masks the lower body.
	pic(root,Assets.texture(str(Assets.config().keeper)),Rect2(532,178,76,84))
	if waiting(s) or active(s) or social_present(s): pic(root,Assets.texture(str(Assets.config().customer_floor)),Rect2(612,252,44,94))
	for fixture in Fixtures.IDS:
		draw_fixture(s,fixture)
	btn(root,"Counter",Rect2(330,245,146,36),func(): open_counter())
	btn(root,"Stockroom",Rect2(1065,180,170,40),func(): switch_view("stockroom"))
	if waiting(s):
		box(root,Rect2(720,77,532,74))
		label(root,"Customer waiting  •  " + str(s.customer.name),Rect2(735,88,310,30),19,GOLD)
		btn(root,"Serve customer",Rect2(1045,91,190,46),func(): open_counter(),false,true)
	elif active(s):
		btn(root,"Resume conversation",Rect2(1005,91,245,46),func(): switch_view("counter"),false,true)
	if drawer == "fixture": draw_fixture_panel(s)
	elif drawer == "status":
		box(root,Rect2(28,78,300,205))
		label(root,"Shop hours",Rect2(44,93,260,38),24)
		btn(root,"Open shop",Rect2(44,140,268,42),func(): command("open"),s.phase != "morning",true)
		btn(root,"Close shop",Rect2(44,188,268,42),func(): command("close"),s.phase != "open")
		btn(root,"Next day",Rect2(44,236,268,34),func(): command("next_day"),s.phase != "closed" or s.day != 1)
func fixture_pos(s: Dictionary, fixture: String) -> Vector2:
	var coords: Array = Assets.config().sockets[s.fixtures[fixture]]
	return Vector2(float(coords[0]),float(coords[1]))
func draw_fixture(s: Dictionary, fixture: String) -> void:
	var pos := fixture_pos(s,fixture)
	pic(root,Assets.texture(str(Assets.config()[fixture])),Rect2(pos,Vector2(260,130)))
	var first := 0 if fixture == "shelf" else 2
	for i in s.items.values():
		if i.owner != "shop" or not str(i.location).begins_with("shelf:"): continue
		if active(s) and i.instance == s.selected: continue
		var slot := int(str(i.location).get_slice(":",1))
		if slot < first or slot >= first+2: continue
		var item_rect := Presentation.display_rect(i,pos,slot-first,1.0)
		var display := pic(root,Assets.item_texture(i),item_rect)
		display.name = "Display_" + str(i.instance)
		floor_items[str(i.instance)] = display
	btn(root,"Display shelf" if fixture=="shelf" else "Equipment rack",Rect2(pos.x+36,pos.y+100,188,31),func(): selected_fixture=fixture; open_drawer("fixture"))
func draw_fixture_panel(s: Dictionary) -> void:
	box(root,Rect2(15,372,315,300))
	label(root,"DISPLAY SHELF" if selected_fixture=="shelf" else "EQUIPMENT RACK",Rect2(30,382,280,35),21,GOLD)
	var first := 0 if selected_fixture=="shelf" else 2
	for idx in range(2):
		var loc := "shelf:%d" % (first+idx)
		var found := "Empty"
		for i in s.items.values():
			if i.owner=="shop" and i.location==loc: found=str(i.name)
		label(root,"Slot %d: %s" % [idx+1,found],Rect2(30,421+idx*27,280,27),16)
	label(root,"Move to a placement socket",Rect2(30,483,280,25),16,MUTED)
	for idx in range(Fixtures.SOCKETS.size()):
		var socket: String = Fixtures.SOCKETS[idx]
		btn(root,socket.capitalize(),Rect2(30+(idx%2)*140,511+int(idx/2)*38,135,34),func(): command("move_fixture",{"fixture":selected_fixture,"socket":socket}),active(s) or not Fixtures.can_place(s.fixtures,selected_fixture,socket) or s.fixtures[selected_fixture]==socket)
	btn(root,"Manage merchandise",Rect2(30,597,280,38),func(): switch_view("stockroom"),false,true)
	btn(root,"Close",Rect2(30,638,280,26),func(): open_drawer("fixture"))
func draw_stockroom(s: Dictionary) -> void:
	box(root,Rect2(20,78,565,590),Color("30221c"))
	label(root,"STOCKROOM  /  APPRAISAL",Rect2(40,94,520,38),27,GOLD)
	label(root,"Select your merchandise",Rect2(40,138,520,28),18,MUTED)
	var row := 0
	for i in s.items.values():
		if i.owner != "shop": continue
		var id: String = str(i.instance)
		var y := 181+row*104
		box(root,Rect2(40,y,525,91),Color("493528"))
		pic(root,Assets.item_texture(i),Rect2(49,y+5,80,80))
		label(root,str(i.name),Rect2(142,y+9,300,30),22)
		label(root,str(i.location).replace("shelf:","Display slot ").replace("storage:","Storage slot "),Rect2(142,y+44,300,29),16,MUTED)
		btn(root,"Selected" if s.selected==id else "Select",Rect2(435,y+25,115,41),func(): command("select",{"item":id}),active(s) or s.selected==id,s.selected==id)
		row += 1
	var i: Dictionary = s.item
	box(root,Rect2(605,78,655,590),Color("392820"))
	label(root,str(i.name),Rect2(625,95,600,40),29,GOLD)
	pic(root,Assets.item_texture(i),Rect2(640,145,300,260))
	label(root,"Condition %d%%\nAsking %dg\n%s" % [i.condition_pct,i.asking,"Appraisal verified" if i.get("appraised",false) else "Not appraised"],Rect2(955,157,285,120),20)
	var locked: bool = active(s) or i.owner!="shop"
	make_price(root,Rect2(625,418,180,42),int(i.asking))
	btn(root,"Set price",Rect2(815,418,180,42),func(): command("price",{"amount":price_value}),locked)
	btn(root,"Appraise",Rect2(1005,418,235,42),func(): command("appraise"),locked)
	label(root,"Move to a compatible display slot",Rect2(625,474,600,27),17,MUTED)
	for idx in range(4):
		var loc := "shelf:%d" % idx
		var occupied := false
		for other in s.items.values():
			if other.owner=="shop" and other.location==loc: occupied=true
		btn(root,("Shelf " if idx<2 else "Rack ")+str(idx%2+1),Rect2(625+idx*155,505,145,41),func(): command("move",{"location":loc}),locked or occupied or not Fixtures.slot_allowed(i,loc))
	btn(root,"Return to storage",Rect2(625,565,300,46),func(): store_selected(),locked or str(i.location).begins_with("storage:"))
	btn(root,"Inspect at counter",Rect2(935,565,305,46),func(): switch_view("counter"),i.owner!="shop",true)
func store_selected() -> void:
	var s := shop.snapshot()
	for idx in range(8):
		var loc := "storage:%d" % idx
		var occupied := false
		for item in s.items.values():
			if item.owner=="shop" and item.location==loc: occupied=true
		if not occupied:
			command("move",{"location":loc})
			return
	message = "Storage is full."; refresh()

func make_price(parent: Control, rect: Rect2, initial: int) -> void:
	price = SpinBox.new(); price.position = rect.position; price.size = rect.size
	price.min_value = 1; price.max_value = 1000000; price.step = 1; price.value = initial
	price_value = initial
	price.add_theme_font_size_override("font_size",18)
	price.value_changed.connect(func(v: float): price_value = int(v))
	parent.add_child(price)

func draw_stock(s: Dictionary) -> void:
	box(root,Rect2(900,253,360,410))
	label(root,"STOCKROOM" if drawer == "stock" else "DISPLAY SHELF",Rect2(918,267,300,35),20,GOLD)
	btn(root,"×",Rect2(1214,263,34,34),func(): open_drawer(drawer))
	var i: Dictionary = s.item
	pic(root,ITEM,Rect2(918,308,110,100))
	label(root,str(i.name),Rect2(1037,316,210,32),24)
	label(root,"%s  •  %d%% condition" % [str(i.location),i.condition_pct],Rect2(1037,350,205,53),16,MUTED)
	label(root,"Asking %dg" % i.asking,Rect2(918,411,300,32),20,GOLD)
	var locked: bool = active(s) or i.owner != "shop"
	make_price(root,Rect2(918,449,145,40),int(i.asking))
	btn(root,"Set price",Rect2(1073,449,168,40),func(): command("price",{"amount":price_value}),locked)
	btn(root,"Appraise",Rect2(918,499,323,39),func(): command("appraise"),locked)
	btn(root,"Display on shelf" if drawer == "stock" else "Move to stockroom",Rect2(918,546,323,40),func(): command("move",{"location":"shelf:0" if drawer == "stock" else "storage:0"}),locked,true)
	label(root,"Appraisal verified" if i.get("appraised",false) else "Inspect to establish appraisal evidence.",Rect2(918,599,325,50),17,MUTED)

func draw_counter(s: Dictionary) -> void:
	var n: Dictionary = s.session
	var is_active := active(s)
	var has_customer: bool = is_active or social_present(s)
	var show_departure := portrait_event == "exit"
	# Identical physical view for inspection, waiting, negotiation and settlement.
	counter_room = pic(root,Assets.texture(str(Assets.config().counter_room)),Rect2(0,62,1280,330))
	counter_room.stretch_mode = TextureRect.STRETCH_SCALE
	draw_counter_fixtures(s)
	if has_customer or show_departure:
		var emotion: String = str(n.get("expression","relieved" if int(s.customer.get("history_modifier",0)) > 0 else "interested"))
		var key := Presentation.expression(emotion)
		portrait = pic(root,Assets.texture(str(Assets.config().portraits[key])),Rect2(306,78,364,416))
		portrait.name = "CustomerPortrait"
		animate_customer(portrait,emotion,float(s.customer.get("presentation_motion",1.0)))
	# Physical counter surface occludes the lower body. All staged merchandise is above this layer.
	counter_surface = pic(root,Assets.texture(str(Assets.config().counter_surface)),Rect2(0,390,1280,128))
	counter_surface.stretch_mode = TextureRect.STRETCH_SCALE
	if has_customer or show_departure:
		box(root,Rect2(22,78,278,78))
		label(root,str(s.customer.name),Rect2(36,88,275,32),27)
		label(root,str(n.get("expression","Remembering")).capitalize(),Rect2(36,123,250,26),17,GOLD)
	else:
		box(root,Rect2(22,78,405,90)); label(root,"Your counter awaits",Rect2(38,90,370,38),25)
		label(root,"Inspection preview — no deal in progress" if s.item.owner=="shop" else "Prepare your display and open the shop.",Rect2(38,128,370,38),16,MUTED)
		if waiting(s): btn(root,"Welcome customer",Rect2(22,180,240,45),func(): open_counter(),false,true)
	var i: Dictionary = s.item
	# Item anchor is independent of the HUD and ledger; texture fit accommodates large objects.
	if is_active or (i.owner=="shop" and not social_present(s)):
		var stage := Presentation.stage_rect(i)
		pic(root,Assets.texture(str(Assets.config().stage_shadow)),Presentation.shadow_rect(i))
		item_stage = pic(root,Presentation.stage_texture(i),stage)
		item_stage.name = "StagedItem"
		box(root,Rect2(944,78,316,124))
		pic(root,Assets.item_texture(i),Rect2(955,91,74,91))
		label(root,str(i.name),Rect2(1035,88,213,50),19 if str(i.name).length() > 12 else 24)
		label(root,"Condition %d%%" % i.condition_pct,Rect2(1038,144,207,25),16,GOLD)
		label(root,"Asking %dg" % n.get("ask",i.asking),Rect2(1038,169,207,25),17,GOLD)
	btn(root,"Hide ledger" if ledger else "View ledger",Rect2(1065,213,194,40),func(): ledger = not ledger; refresh())
	if ledger: draw_ledger()
	box(root,Rect2(22,518,858,159),Color("30221c"))
	label(root,str(s.customer.name) if has_customer else "Counter",Rect2(36,528,820,26),18,GOLD)
	var line: String = Speech.render(Negotiation.public_plan(n)) if not n.is_empty() else (str(s.return_note) if s.return_note != "" else "No active conversation.")
	var sc := ScrollContainer.new(); sc.position=Vector2(36,555); sc.size=Vector2(825,64); sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(sc)
	var lines := VBoxContainer.new(); lines.size_flags_horizontal=Control.SIZE_EXPAND_FILL; sc.add_child(lines)
	dialogue_label = label(lines,line,Rect2(0,0,807,57),21)
	dialogue_label.custom_minimum_size = Vector2(807,0)
	if conversation_font != null: dialogue_label.add_theme_font_override("font",conversation_font)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: skip_dialogue())
	if reveal_next and dialogue_speed>0: start_dialogue(line)
	var edit := LineEdit.new(); edit.position = Vector2(36,624); edit.size = Vector2(610,40); edit.placeholder_text = "Free text unavailable offline • choose a response"; edit.editable = false; root.add_child(edit)
	btn(root,"Respond…",Rect2(660,624,202,40),func(): open_drawer("responses"),is_active == false or n.status != "negotiating",true)
	box(root,Rect2(898,518,362,159),Color("ead5b2"))
	label(root,"PROPOSED DEAL",Rect2(912,528,334,27),17,Color("79512f"))
	var offer := int(n.get("offer",0))
	label(root,("%dg  •  %s" % [offer,i.name]) if is_active else "No active offer",Rect2(912,555,335,43),25,Color("36251c"))
	var pending: bool = is_active and n.status == "pending"
	label(root,"Awaiting your confirmation" if pending else ("Customer offer — not yet accepted" if is_active else "Inspection only — no transaction"),Rect2(912,594,335,29),15,Color("79512f"))
	btn(root,"Confirm sale" if pending else "Review offer",Rect2(912,628,159,39),func(): review_or_confirm(pending),not is_active,true)
	btn(root,"Reject / leave",Rect2(1080,628,166,39),func(): act("reject","No deal."),not is_active)
	if drawer == "responses" and is_active and n.status == "negotiating": draw_responses(s)

func review_or_confirm(pending: bool) -> void:
	if pending: confirm()
	else: act("accept_offer","I accept your offer for review.")

func draw_ledger() -> void:
	# Overlay covers item staging, but the persistent item HUD at y=78 remains visible.
	box(root,Rect2(768,259,492,249),Color("ead5b2"))
	label(root,"CONVERSATION LEDGER",Rect2(783,271,457,28),18,Color("79512f"))
	var scroll := ScrollContainer.new(); scroll.position = Vector2(783,305); scroll.size = Vector2(461,190); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(scroll)
	var lines := VBoxContainer.new(); lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(lines)
	for entry in history:
		var l := Label.new(); l.text = "%s: %s" % [entry.speaker,entry.text]; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.add_theme_color_override("font_color",Color("37281d")); l.add_theme_font_size_override("font_size",17); lines.add_child(l)
	if history.is_empty():
		var l := Label.new(); l.text = "No exchanges yet."; l.add_theme_color_override("font_color",Color("37281d")); lines.add_child(l)
	if scroll.get_v_scroll_bar(): scroll.set_deferred("scroll_vertical",1000000)

func draw_responses(s: Dictionary) -> void:
	box(root,Rect2(22,170,490,338))
	label(root,"Choose your response",Rect2(38,182,455,35),24)
	make_price(root,Rect2(38,224,175,40),price_value)
	btn(root,"Counteroffer",Rect2(223,224,270,40),func(): act("counter","I propose %dg." % price_value,true))
	var rows := [["evidence","Show appraisal",true],["reassure","Acknowledge their need",true],["patient","Bargain patiently",true],["flatter","Flatter",true],["small_talk","Small talk",false],["firm","Stand firm",false],["ban_threat","Threaten a ban",false],["insult","Insult",false],["dismiss","Dismiss customer",false],["violence_threat","Threaten violence",false],["ban_confirm","Ban 30 days…",false],["end","End conversation",false]]
	for idx in range(rows.size()):
		var row: Array = rows[idx]; var kind: String = row[0]; var caption: String = row[1]; var priced: bool = row[2]
		btn(root,caption,Rect2(38+(idx%2)*230,272+int(idx/2)*37,220,34),func(): choose_response(kind,caption,priced))

func choose_response(kind: String, caption: String, priced: bool) -> void:
	if kind != "ban_confirm":
		act(kind,caption + (" • %dg" % price_value if priced else ""),priced,{"affront":true} if kind == "firm" else {})
		return
	var n: Dictionary = shop.snapshot().session
	var dialog := ConfirmationDialog.new()
	dialog.title = "Enact a 30-day ban?"
	dialog.dialog_text = "This bars the customer from returning and ends the encounter without a sale."
	add_child(dialog)
	dialog.confirmed.connect(func():
		command("act",{"session":n.session,"revision":n.revision,"action":{"type":"ban_confirm","days":30}},"You are barred from this shop.")
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func draw_menu() -> void:
	box(root,Rect2(805,70,249,299))
	label(root,"Shop menu",Rect2(821,84,205,32),23)
	btn(root,"Save game",Rect2(821,122,217,43),func(): save_game(),false,true)
	btn(root,"Load game",Rect2(821,173,217,43),func(): load_game())
	btn(root,"Text: " + ["Instant","Normal","Slow"][dialogue_speed],Rect2(821,224,217,43),func(): set_dialogue_speed((dialogue_speed+1)%3))
	label(root,"Effects volume",Rect2(821,273,217,25),16,MUTED)
	var volume := HSlider.new(); volume.min_value=0; volume.max_value=1; volume.step=0.05; volume.value=audio_service.volume; volume.position=Vector2(821,309); volume.size=Vector2(217,30); root.add_child(volume)
	volume.value_changed.connect(func(v: float): audio_service.set_volume(v))

func draw_debug() -> void:
	box(root,Rect2(20,70,315,178),Color("241d1b"))
	label(root,"DEVELOPER TOOLS",Rect2(35,82,275,30),19,GOLD)
	btn(root,"Save",Rect2(35,120,130,42),func(): save_game())
	btn(root,"Load",Rect2(175,120,130,42),func(): load_game())
	btn(root,"Reset test",Rect2(35,174,270,42),func(): shop.reset(); history=[]; history_session=-1; last_line=""; view="floor"; drawer=""; debug=false; refresh())

func save_game() -> void:
	var r: Dictionary = shop.save()
	if r.ok:
		var f := FileAccess.open(ui_save_path,FileAccess.WRITE)
		if f: f.store_string(JSON.stringify({"revision":shop.snapshot().revision,"view":view,"ledger":ledger,"history":history,"history_session":history_session,"price":price_value,"owner_pos":[owner_pos.x,owner_pos.y]})); f.close()
	message = "Saved" if r.ok else str(r.get("error","Save failed")); refresh()

func load_game() -> void:
	var r: Dictionary = shop.load_save()
	if r.ok:
		var s := shop.snapshot(); var ui: Variant = Shop.parse_save(FileAccess.get_file_as_string(ui_save_path)) if FileAccess.file_exists(ui_save_path) else null
		view = "counter" if active(s) else "floor"; ledger = false; history=[]; history_session=-1
		if ui is Dictionary and int(ui.get("revision",-1)) == int(s.revision):
			view = str(ui.get("view","floor")) if ui.get("view","") in ["floor","counter","stockroom"] else "floor"; ledger = bool(ui.get("ledger",false)); history = ui.get("history",[]); history_session = int(ui.get("history_session",-1)); price_value = int(ui.get("price",650))
			var saved_pos: Array = ui.get("owner_pos",[650,642])
			if saved_pos.size() == 2: owner_pos = Vector2(float(saved_pos[0]),float(saved_pos[1]))
		elif not s.session.is_empty():
			history_session = int(s.session.session); append_npc(s)
		drawer = ""; debug = false
	message = "Loaded" if r.ok else str(r.get("error","Load failed")); refresh()

func add_ambient(rect: Rect2) -> void:
	var a := Ambient.new()
	a.position = rect.position; a.size = rect.size; a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(a)


func draw_counter_fixtures(s: Dictionary) -> void:
	# Selective authored projections. No unrelated or synthetic shoppers.
	var config := Assets.config()
	for fixture in Fixtures.IDS:
		var socket: String = str(s.fixtures[fixture])
		var coords: Array = config.counter_sockets[socket]
		var pos := Vector2(float(coords[0]),float(coords[1]))
		var scale_factor := float(coords[2])
		pic(root,Assets.texture(str(config[fixture])),Rect2(pos,Vector2(260,130)*scale_factor))
		var first := 0 if fixture=="shelf" else 2
		for item in s.items.values():
			if item.owner!="shop" or not str(item.location).begins_with("shelf:"): continue
			# The selected object is represented by the independent stage, not twice in this view.
			if item.instance==s.selected: continue
			var slot := int(str(item.location).get_slice(":",1))
			if slot<first or slot>=first+2: continue
			var t := pic(root,Assets.item_texture(item),Presentation.display_rect(item,pos,slot-first,scale_factor))
			t.name = "Background_" + str(item.instance)
			counter_items[str(item.instance)] = t

func animate_customer(node: TextureRect, emotion: String, intensity: float) -> void:
	var amount := clampf(intensity,0.0,1.5)
	if amount<=0.0:
		if portrait_event=="exit": node.hide()
		return
	var home := node.position
	var t := create_tween().bind_node(node)
	match portrait_event:
		"enter":
			node.position.x -= 30.0*amount; node.modulate.a=0.0
			t.set_parallel(true); t.tween_property(node,"position",home,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT); t.tween_property(node,"modulate:a",1.0,0.28)
		"exit":
			t.tween_interval(0.18); t.set_parallel(true); t.tween_property(node,"position:x",home.x-35.0*amount,0.32).set_delay(0.18); t.tween_property(node,"modulate:a",0.0,0.30).set_delay(0.18)
			t.chain().tween_callback(node.hide)
		"reaction":
			var offset := Presentation.reaction(emotion)*amount
			t.tween_property(node,"position",home+offset,0.09).set_trans(Tween.TRANS_SINE)
			t.tween_property(node,"position",home,0.17).set_trans(Tween.TRANS_SINE)
		_: t.kill()

func start_dialogue(line: String) -> void:
	if not is_instance_valid(dialogue_label): return
	dialogue_label.visible_characters=0
	var duration := float(line.length()) / (60.0 if dialogue_speed==1 else 30.0)
	dialogue_tween = create_tween().bind_node(dialogue_label)
	dialogue_tween.tween_property(dialogue_label,"visible_characters",line.length(),maxf(0.12,duration))
	dialogue_tween.tween_callback(func():
		if is_instance_valid(dialogue_label): dialogue_label.visible_characters=-1)
	audio_service.cue("text")

func skip_dialogue() -> void:
	if dialogue_tween and dialogue_tween.is_valid(): dialogue_tween.kill()
	if is_instance_valid(dialogue_label): dialogue_label.visible_characters=-1

func set_dialogue_speed(speed: int) -> void:
	dialogue_speed = clampi(speed,0,2); skip_dialogue()
	var prefs := ConfigFile.new(); prefs.load("user://emporium_presentation.cfg"); prefs.set_value("dialogue","speed",dialogue_speed); prefs.save("user://emporium_presentation.cfg")
	refresh()
