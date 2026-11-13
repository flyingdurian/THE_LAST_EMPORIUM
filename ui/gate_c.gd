extends Control
## Gate C: a presentation adapter. Never writes the authoritative snapshot.
const Shop = preload("res://domain/shop.gd")
const Negotiation = preload("res://domain/negotiation.gd")
const Speech = preload("res://domain/dialogue.gd")
const FLOOR = preload("res://art/floor.jpg")
const COUNTER = preload("res://art/counter.jpg")
const ITEM = preload("res://art/dragonstone.png")
const SAVE_UI = "user://emporium_gate_c_ui.json"
var shop = Shop.new()
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
const INK = Color("251c19")
const GOLD = Color("bc945b")
const PAPER = Color("f2dfbd")
const MUTED = Color("d0bba0")
const GREEN = Color("355546")

func _ready() -> void:
	get_window().min_size = Vector2i(960,540)
	refresh()

func box(parent: Control, rect: Rect2, color: Color = INK) -> Panel:
	var p := Panel.new()
	p.position = rect.position; p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color; style.border_color = GOLD
	style.set_border_width_all(1); style.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel",style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func label(parent: Control, text: String, rect: Rect2, font_size: int = 18, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text; l.position = rect.position; l.size = rect.size
	l.add_theme_font_size_override("font_size",font_size)
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
	b.pressed.connect(fn); parent.add_child(b)
	return b

func pic(parent: Control, texture: Texture2D, rect: Rect2, cover: bool = false) -> TextureRect:
	var t := TextureRect.new(); t.texture = texture; t.position = rect.position; t.size = rect.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t); return t

func active(s: Dictionary) -> bool:
	return not s.session.is_empty() and s.session.status in ["negotiating","pending"]

func waiting(s: Dictionary) -> bool:
	return s.phase == "open" and not s.visited and not s.customer.safety_hold and int(s.customer.ban_until) <= int(s.day)

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
	if kind == "visit" and not after.session.is_empty() and (before.session.is_empty() or before.session.session != after.session.session):
		history = []; history_session = int(after.session.session)
		append_npc(after)
	elif kind in ["act","confirm"] and not after.session.is_empty():
		if player_line != "": history.append({"speaker":"You","text":player_line})
		append_npc(after)
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
	if is_instance_valid(root):
		remove_child(root); root.queue_free()
	root = Control.new(); root.size = Vector2(1280,720); add_child(root)
	var s := shop.snapshot(); last_snapshot = s
	var bg := ColorRect.new(); bg.color = INK; bg.size = root.size; bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bg)
	if view == "floor": draw_floor(s)
	else: draw_counter(s)
	draw_header(s)
	box(root,Rect2(0,684,1280,36),Color("201817"))
	label(root,message if message != "" else "Offline prototype  •  Structured actions, no live AI",Rect2(20,690,1000,25),15,MUTED)
	btn(root,"Debug",Rect2(1175,688,86,27),func(): debug = not debug; refresh())
	if debug: draw_debug()

func draw_header(s: Dictionary) -> void:
	box(root,Rect2(0,0,1280,62),Color("201817"))
	label(root,"THE LAST EMPORIUM",Rect2(18,14,350,40),27)
	label(root,"Day %d" % s.day,Rect2(390,19,90,30),20)
	label(root,"%dg" % s.gold,Rect2(490,19,150,30),20,GOLD)
	var status_text := str(s.phase).capitalize()
	btn(root,"Shop: " + status_text,Rect2(648,10,148,42),func(): open_status())
	btn(root,"Shop Floor",Rect2(940,10,150,42),func(): switch_view("floor"),false,view == "floor")
	btn(root,"Counter" + (" •" if waiting(s) else ""),Rect2(1100,10,160,42),func(): switch_view("counter"),false,view == "counter")

func draw_floor(s: Dictionary) -> void:
	var floor_art := pic(root,FLOOR,Rect2(0,62,1280,622))
	floor_art.stretch_mode = TextureRect.STRETCH_SCALE
	# Contextual hotspots, not domain changes. Scenic concept objects are decorative.
	btn(root,"Display shelf",Rect2(307,458,182,42),func(): open_drawer("shelf"))
	btn(root,"Stockroom",Rect2(1055,180,185,42),func(): open_drawer("stock"))
	btn(root,"Counter",Rect2(495,240,180,42),func(): open_counter())
	if waiting(s):
		box(root,Rect2(720,77,532,74))
		label(root,"Customer waiting  •  " + str(s.customer.name),Rect2(735,88,310,30),19,GOLD)
		btn(root,"Serve customer",Rect2(1045,91,190,46),func(): open_counter(),false,true)
	elif active(s):
		btn(root,"Resume conversation",Rect2(1005,91,245,46),func(): switch_view("counter"),false,true)
	if str(s.item.location).begins_with("shelf:") and s.item.owner == "shop":
		pic(root,ITEM,Rect2(382,353,76,88))
	label(root,"Reserved expansion space  •  future shelves and equipment racks",Rect2(585,644,650,26),16,PAPER)
	if drawer in ["stock","shelf"]: draw_stock(s)
	elif drawer == "status":
		box(root,Rect2(28,78,300,205))
		label(root,"Shop hours",Rect2(44,93,260,38),24)
		btn(root,"Open shop",Rect2(44,140,268,42),func(): command("open"),s.phase != "morning",true)
		btn(root,"Close shop",Rect2(44,188,268,42),func(): command("close"),s.phase != "open")
		btn(root,"Next day",Rect2(44,236,268,34),func(): command("next_day"),s.phase != "closed" or s.day != 1)

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
	var has_customer: bool = is_active
	pic(root,COUNTER if has_customer else FLOOR,Rect2(0,62,1280,520),true)
	if has_customer:
		box(root,Rect2(22,78,305,78))
		label(root,str(s.customer.name),Rect2(36,88,275,32),27)
		label(root,str(n.get("expression","Interested")).capitalize(),Rect2(36,123,275,26),17,GOLD)
	else:
		box(root,Rect2(22,78,405,90)); label(root,"Your counter awaits",Rect2(38,90,370,38),25)
		label(root,s.return_note if s.return_note != "" else "Prepare your display and open the shop.",Rect2(38,128,370,38),16,MUTED)
		if waiting(s): btn(root,"Welcome customer",Rect2(22,180,240,45),func(): open_counter(),false,true)
	var i: Dictionary = s.item
	# Item anchor is independent of the HUD and ledger; texture fit accommodates large objects.
	if is_active:
		item_stage = pic(root,ITEM,Rect2(770,250,345,260))
		box(root,Rect2(944,78,316,124))
		pic(root,ITEM,Rect2(956,90,76,78))
		label(root,str(i.name),Rect2(1038,90,210,31),23)
		label(root,"Condition %d%%  •  Asking %dg" % [i.condition_pct,i.asking],Rect2(1038,126,207,49),16,GOLD)
		label(root,"Inspect / terms",Rect2(956,171,285,24),15,MUTED)
	btn(root,"Hide ledger" if ledger else "View ledger",Rect2(1065,213,194,40),func(): ledger = not ledger; refresh())
	if ledger: draw_ledger()
	box(root,Rect2(22,518,858,159),Color("30221c"))
	label(root,str(s.customer.name) if has_customer else "Counter",Rect2(36,528,820,26),18,GOLD)
	var line: String = Speech.render(Negotiation.public_plan(n)) if not n.is_empty() else (str(s.return_note) if s.return_note != "" else "No active conversation.")
	label(root,line,Rect2(36,556,825,57),21)
	var edit := LineEdit.new(); edit.position = Vector2(36,624); edit.size = Vector2(610,40); edit.placeholder_text = "Free text unavailable offline • choose a response"; edit.editable = false; root.add_child(edit)
	btn(root,"Respond…",Rect2(660,624,202,40),func(): open_drawer("responses"),is_active == false or n.status != "negotiating",true)
	box(root,Rect2(898,518,362,159),Color("ead5b2"))
	label(root,"PROPOSED DEAL",Rect2(912,528,334,27),17,Color("79512f"))
	var offer := int(n.get("offer",0))
	label(root,("%dg  •  %s" % [offer,i.name]) if is_active else "No active offer",Rect2(912,555,335,43),25,Color("36251c"))
	var pending: bool = is_active and n.status == "pending"
	label(root,"Awaiting your confirmation" if pending else "Customer offer — not yet accepted",Rect2(912,594,335,29),15,Color("79512f"))
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
	var rows := [["evidence","Show appraisal",true],["reassure","Acknowledge their need",true],["patient","Bargain patiently",true],["flatter","Flatter",true],["small_talk","Small talk",false],["firm","Stand firm",false],["ban_threat","Threaten a ban",false],["insult","Insult",false],["dismiss","Dismiss customer",false],["violence_threat","Threaten violence",false]]
	for idx in range(rows.size()):
		var row: Array = rows[idx]; var kind: String = row[0]; var caption: String = row[1]; var priced: bool = row[2]
		btn(root,caption,Rect2(38+(idx%2)*230,275+int(idx/2)*42,220,36),func(): act(kind,caption + (" • %dg" % price_value if priced else ""),priced,{"affront":true} if kind == "firm" else {}))

func draw_debug() -> void:
	box(root,Rect2(20,70,315,178),Color("241d1b"))
	label(root,"DEVELOPER TOOLS",Rect2(35,82,275,30),19,GOLD)
	btn(root,"Save",Rect2(35,120,130,42),func(): save_game())
	btn(root,"Load",Rect2(175,120,130,42),func(): load_game())
	btn(root,"Reset test",Rect2(35,174,270,42),func(): shop.reset(); history=[]; history_session=-1; last_line=""; view="floor"; drawer=""; debug=false; refresh())

func save_game() -> void:
	var r: Dictionary = shop.save()
	if r.ok:
		var f := FileAccess.open(SAVE_UI,FileAccess.WRITE)
		if f: f.store_string(JSON.stringify({"revision":shop.snapshot().revision,"view":view,"ledger":ledger,"history":history,"history_session":history_session,"price":price_value})); f.close()
	message = "Saved" if r.ok else str(r.get("error","Save failed")); refresh()

func load_game() -> void:
	var r: Dictionary = shop.load_save()
	if r.ok:
		var s := shop.snapshot(); var ui: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_UI))
		view = "counter" if active(s) else "floor"; ledger = false; history=[]; history_session=-1
		if ui is Dictionary and int(ui.get("revision",-1)) == int(s.revision):
			view = "counter" if ui.get("view","") == "counter" else "floor"; ledger = bool(ui.get("ledger",false)); history = ui.get("history",[]); history_session = int(ui.get("history_session",-1)); price_value = int(ui.get("price",650))
		elif not s.session.is_empty():
			history_session = int(s.session.session); append_npc(s)
		drawer = ""; debug = false
	message = "Loaded" if r.ok else str(r.get("error","Load failed")); refresh()
