extends Control
const Shop = preload("res://domain/shop.gd")
const Speech = preload("res://domain/dialogue.gd")
const Negotiation = preload("res://domain/negotiation.gd")
var shop = Shop.new()
var room := "shop"
var pos := Vector2(180,310)
var hud: Label
var info: Label
var speech: Label
var status: Label
var actions: VBoxContainer
var price: SpinBox
var screen: Control
var tile_mode := 32
var message := ""
const DOOR := Rect2(490,300,70,100)
const COUNTER := Rect2(70,90,350,70)
const SHELF := Rect2(70,210,95,110)
const CHEST := Rect2(80,100,180,100)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("201d20")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20; root.offset_top = 16; root.offset_right = -20; root.offset_bottom = -16
	root.add_theme_constant_override("separation",24)
	add_child(root)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 610
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	hud = Label.new(); hud.add_theme_font_size_override("font_size",24); left.add_child(hud)
	var map = preload("res://ui/map.gd").new()
	map.host = self
	map.custom_minimum_size = Vector2(580,450)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(map)
	screen = map
	info = Label.new(); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(info)
	var nav := HBoxContainer.new(); left.add_child(nav)
	button(nav,"Enter adjacent room [E]", func(): change_room())
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 500
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation",7)
	root.add_child(panel)
	var title := Label.new(); title.text = "THE LAST EMPORIUM  /  OFFLINE"; title.add_theme_font_size_override("font_size",22); panel.add_child(title)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(status)
	speech = Label.new(); speech.custom_minimum_size.y = 78; speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(speech)
	var pr := HBoxContainer.new(); panel.add_child(pr)
	var pl := Label.new(); pl.text = "Price / counter (g)"; pr.add_child(pl)
	price = SpinBox.new(); price.min_value=1; price.max_value=1000000; price.step=1; price.value=650; price.custom_minimum_size.x=160; pr.add_child(price)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; panel.add_child(scroll)
	actions = VBoxContainer.new(); actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(actions)
	var controls := HBoxContainer.new(); panel.add_child(controls)
	button(controls,"Save",func(): result(shop.save()))
	button(controls,"Load",func(): result(shop.load_save()))
	button(controls,"New test run",func():
		shop.reset()
		room="shop"
		pos=Vector2(180,310)
		message="Fresh fixture; saved file unchanged."
		refresh())
	refresh()

func button(parent: Container, label: String, fn: Callable, disabled: bool=false) -> Button:
	var b := Button.new(); b.text=label; b.disabled=disabled; b.custom_minimum_size.y=32
	b.pressed.connect(fn); parent.add_child(b); return b

func result(r: Dictionary) -> void:
	message = "" if r.ok else str(r.get("error","Rejected"))
	if r.ok and r.has("backup"): message = "Loaded backup." if r.backup else "Loaded save."
	refresh()

func command(kind: String, extra: Dictionary={}) -> void:
	var c := extra.duplicate(); c["type"]=kind; result(shop.command(c))

func act(kind: String, extra: Dictionary={}) -> void:
	var a := extra.duplicate(); a["type"]=kind
	var s: Dictionary=shop.snapshot().session
	command("act",{"session":s.session,"revision":s.revision,"action":a})

func near_rect(rect: Rect2) -> bool:
	return rect.grow(60).has_point(pos)

func change_room() -> void:
	if not near_rect(DOOR):
		message="Walk to the doorway first."; refresh(); return
	room = "stockroom" if room=="shop" else "shop"
	pos = Vector2(460,350); message=""; refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
		change_room(); get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Arrow keys move; input focus in price field stops navigation.
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	var v := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if v == Vector2.ZERO: return
	var old := pos
	var target := pos+v*210.0*delta
	target.x=clampf(target.x,25,550); target.y=clampf(target.y,25,420)
	var obstacles := [COUNTER,SHELF] if room=="shop" else [CHEST]
	var xtry := Vector2(target.x,pos.y)
	var ytry := Vector2(pos.x,target.y)
	var blocked := false
	for ob in obstacles:
		if ob.grow(12).has_point(xtry): blocked=true
	if not blocked: pos.x=xtry.x
	blocked=false
	for ob in obstacles:
		if ob.grow(12).has_point(ytry): blocked=true
	if not blocked: pos.y=ytry.y
	if old != pos:
		screen.queue_redraw()
		if room=="shop" and (COUNTER.grow(60).has_point(old)!=near_rect(COUNTER) or SHELF.grow(60).has_point(old)!=near_rect(SHELF)): refresh()
		elif room=="stockroom" and CHEST.grow(60).has_point(old)!=near_rect(CHEST): refresh()

func refresh() -> void:
	var s: Dictionary=shop.snapshot(); var i: Dictionary=s.item; var n: Dictionary=s.session
	var active: bool=not n.is_empty() and n.status in ["negotiating","pending"]
	hud.text="Day %d  •  %s  •  %dg" % [s.day,str(s.phase).capitalize(),s.gold]
	info.text="Arrow keys: walk  •  E: doorway  •  %s\nGraybox only • final art scale not locked" % room.capitalize()
	status.text="%s: %s  |  listed %dg\n%s" % [i.name,str(i.location),i.asking,message]
	if i.get("appraised",false): status.text += "\nAppraisal: intact; rare stock; estimated 600–720g."
	speech.text=(s.return_note if s.visited else "") if n.is_empty() else "%s — %s\n%s" % [s.customer.name,n.expression.capitalize(),Speech.render(Negotiation.public_plan(n))]
	if n.is_empty() and speech.text=="": speech.text="Prepare stock, open the shop, then invite the customer at the counter."
	if active and s.visited and s.return_note!="": speech.text=s.return_note+"\n"+speech.text
	for child in actions.get_children(): actions.remove_child(child); child.queue_free()
	if not active:
		var at_stock: bool=room=="stockroom" and near_rect(CHEST)
		var at_shelf: bool=room=="shop" and near_rect(SHELF)
		button(actions,"Display item on shelf",func(): command("move",{"location":"shelf:0"}),not at_stock or i.owner!="shop")
		button(actions,"Return item to stockroom",func(): command("move",{"location":"storage:0"}),not at_shelf or i.owner!="shop")
		button(actions,"Appraise item",func(): command("appraise"),not (at_stock or at_shelf) or i.owner!="shop")
		button(actions,"Set asking price",func(): command("price",{"amount":int(price.value)}),not (at_stock or at_shelf) or i.owner!="shop")
		button(actions,"Open shop",func(): command("open"),s.phase!="morning")
		button(actions,"Invite customer at counter",func(): command("visit"),room!="shop" or not near_rect(COUNTER) or s.phase!="open" or s.visited)
	else:
		if n.status=="pending":
			var slip := Label.new(); slip.text="Deal slip: %s for %dg\nNo transfer until confirmed." % [i.name,n.offer]; actions.add_child(slip)
			button(actions,"Confirm sale",func(): command("confirm",{"session":n.session,"revision":n.revision}))
			button(actions,"Reject offer / leave",func(): act("reject"))
		else:
			button(actions,"Counter at entered price",func(): act("counter",{"amount":int(price.value)}))
			button(actions,"Show appraisal + counter",func(): act("evidence",{"amount":int(price.value)}))
			button(actions,"Acknowledge need + counter",func(): act("reassure",{"amount":int(price.value)}))
			button(actions,"Patient bargaining + counter",func(): act("patient",{"amount":int(price.value)}))
			button(actions,"Flatter + counter",func(): act("flatter",{"amount":int(price.value)}))
			button(actions,"Firm refusal (stern)",func(): act("firm",{"affront":true}))
			button(actions,"Threaten shop ban",func(): act("ban_threat"))
			button(actions,"Insult",func(): act("insult"))
			button(actions,"Enact 30-day ban…",func(): request_ban())
			button(actions,"Threaten violence",func(): act("violence_threat"))
			button(actions,"Small talk",func(): act("small_talk"))
			button(actions,"Dismiss (one possible final offer)",func(): act("dismiss"))
			button(actions,"Accept current customer offer",func(): act("accept_offer"))
			button(actions,"End immediately",func(): act("end"))
	button(actions,"Close shop",func(): command("close"),s.phase!="open")
	button(actions,"Start Day 2",func(): command("next_day"),s.phase!="closed" or s.day!=1)
	screen.queue_redraw()

func request_ban() -> void:
	var n: Dictionary = shop.snapshot().session
	var dialog := ConfirmationDialog.new()
	dialog.title = "Enact a ban?"
	dialog.dialog_text = "This customer will be barred for 30 days. The encounter ends without a sale."
	add_child(dialog)
	dialog.confirmed.connect(func():
		command("act",{"session":n.session,"revision":n.revision,"action":{"type":"ban_confirm","days":30}})
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
