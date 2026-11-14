extends "res://ui/week.gd"
## Japanese dual-style presentation only. Week domain remains the only authority.
const JapanArt=preload("res://ui/japan_art.gd")
const Retail=preload("res://ui/retail_director.gd")
var jart=JapanArt.new()
var retail=Retail.new()
var customer_node: TextureRect
var keeper_node: TextureRect
var keeper_state: String="IDLE"
var keeper_elapsed:=0.0
var restock_pending:=false
var restock_remaining:=0.0
const J_INK=Color("222b36")
const J_PANEL=Color("273a48")
const J_PAPER=Color("f1e0bf")
const J_ACCENT=Color("c9a66e")
const J_RED=Color("893e39")
const J_GREEN=Color("3f6559")
func _ready() -> void:
	super._ready()
func pixel(parent: Control,texture: Texture2D,rect: Rect2) -> TextureRect:
	var t:=pic(parent,texture,rect)
	t.stretch_mode=TextureRect.STRETCH_SCALE
	t.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return t
func portrait_texture(c: Dictionary,key: String) -> Texture2D:
	return jart.portrait(str(c.id),key)
func floor_texture(c: Dictionary) -> Texture2D:
	return jart.sprite(str(c.id),0)
func fixture_pos(s: Dictionary,fixture: String) -> Vector2:
	var p:=super.fixture_pos(s,fixture)
	return Vector2(round(p.x/4)*4,round(p.y/4)*4)
func box(parent: Control,rect: Rect2,color: Color=Color("251c19")) -> Panel:
	var chosen: Color=J_PAPER if color.get_luminance()>0.48 else (J_INK if color.get_luminance()<0.04 else J_PANEL)
	var p:=super.box(parent,rect,chosen)
	var sb:=StyleBoxFlat.new()
	sb.bg_color=chosen; sb.border_color=J_ACCENT; sb.set_border_width_all(1); sb.set_corner_radius_all(3)
	sb.shadow_color=Color(0.02,0.03,0.06,0.5); sb.shadow_size=3; sb.shadow_offset=Vector2(0,2)
	p.add_theme_stylebox_override("panel",sb)
	return p
func label(parent: Control,text: String,rect: Rect2,font_size: int=18,color: Color=Color("f2dfbd")) -> Label:
	var l:=super.label(parent,text,rect,font_size,color)
	if color==Color("bc945b"): l.add_theme_color_override("font_color",J_ACCENT.lightened(.12))
	elif color==Color("f2dfbd"): l.add_theme_color_override("font_color",J_PAPER)
	return l
func btn(parent: Control,text: String,rect: Rect2,fn: Callable,disabled: bool=false,primary: bool=false) -> Button:
	var b:=super.btn(parent,text,rect,fn,disabled,primary)
	for mode in ["normal","hover","pressed","disabled","focus"]:
		var sb:=StyleBoxFlat.new()
		sb.bg_color=J_RED if primary else J_PANEL
		if mode=="hover": sb.bg_color=sb.bg_color.lightened(.17)
		if mode=="pressed": sb.bg_color=sb.bg_color.darkened(.15)
		if mode=="disabled": sb.bg_color=Color("444449")
		if mode=="focus": sb.bg_color=Color(0,0,0,0)
		sb.border_color=J_ACCENT; sb.set_border_width_all(1); sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override(mode,sb)
	return b
func refresh() -> void:
	customer_node=null; keeper_node=null
	super.refresh()
	if view=="floor" and restock_pending:
		restock_pending=false; restock_remaining=1.6; keeper_elapsed=0
func command(kind: String,args: Dictionary={},player_line: String="") -> void:
	var old: int=int(shop.snapshot().revision)
	super.command(kind,args,player_line)
	var after: Dictionary=shop.snapshot()
	if int(after.revision)!=old and kind in ["restock","move"]:
		if view=="floor": restock_remaining=1.6; keeper_elapsed=0
		else: restock_pending=true
func _process(delta: float) -> void:
	if view!="floor": return
	var s: Dictionary=last_snapshot
	if s.is_empty(): return
	if is_instance_valid(customer_node):
		retail.step(delta)
		customer_node.position=retail.snapped()
		customer_node.texture=jart.sprite(str(s.customer.id),jart.frame_index(retail.state,retail.elapsed))
		customer_node.flip_h=retail.facing_left
	if is_instance_valid(keeper_node):
		restock_remaining=maxf(0,restock_remaining-delta)
		var next: String="RESTOCK" if restock_remaining>0 else ("INTERACT" if active(s) else "IDLE")
		if keeper_state!=next: keeper_state=next; keeper_elapsed=0
		keeper_elapsed+=delta
		keeper_node.texture=jart.sprite("shopkeeper",jart.frame_index(keeper_state,keeper_elapsed))
func draw_header(s: Dictionary) -> void:
	super.draw_header(s)
	# A small lacquer seal, not a change to the title or story.
	var seal:=label(root,"✿",Rect2(360,17,27,29),21,J_ACCENT)
	seal.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func draw_fixture(s: Dictionary,fixture: String) -> void:
	var pos:=fixture_pos(s,fixture)
	pixel(root,jart.env(fixture+"_world"),Rect2(pos,Vector2(260,132)))
	var first:=0 if fixture=="shelf" else 2
	for i in s.items.values():
		if i.owner!="shop" or not str(i.location).begins_with("shelf:"): continue
		if active(s) and s.visit_goal in ["buy","barter"] and i.instance==s.selected: continue
		var slot:=int(str(i.location).get_slice(":",1))
		if slot<first or slot>=first+2: continue
		var t:=pixel(root,jart.item(str(i.id),"world"),jart.world_rect(str(i.id),pos,slot-first))
		t.name="Display_"+str(i.instance); floor_items[str(i.instance)]=t
	btn(root,"Display shelf" if fixture=="shelf" else "Equipment rack",Rect2(pos.x+36,pos.y+100,188,31),func(): selected_fixture=fixture; open_drawer("fixture"))
func draw_counter_fixtures(s: Dictionary) -> void:
	# Selective, authored projections of the actual furniture/stock. No painted visitors.
	var config: Dictionary=Assets.config()
	for fixture in Fixtures.IDS:
		var coords: Array=config.counter_sockets[str(s.fixtures[fixture])]
		var pos:=Vector2(float(coords[0]),float(coords[1]))
		var scale_factor: float=float(coords[2])
		pic(root,jart.env(fixture+"_counter"),Rect2(pos,Vector2(260,130)*scale_factor))
		var first:=0 if fixture=="shelf" else 2
		for item in s.items.values():
			if item.owner!="shop" or not str(item.location).begins_with("shelf:"): continue
			if item.instance==s.selected and ((active(s) and s.visit_goal in ["buy","barter"]) or not active(s)): continue
			var slot:=int(str(item.location).get_slice(":",1))
			if slot<first or slot>=first+2: continue
			var r:=jart.world_rect(str(item.id),Vector2.ZERO,slot-first)
			var t:=pic(root,jart.item(str(item.id),"icon"),Rect2(pos+r.position*scale_factor,r.size*scale_factor))
			t.name="Background_"+str(item.instance); counter_items[str(item.instance)]=t

func draw_stockroom(s: Dictionary) -> void:
	var backdrop:=pic(root,jart.env("stockroom"),Rect2(0,64,1280,620)); backdrop.stretch_mode=TextureRect.STRETCH_SCALE
	box(root,Rect2(20,78,565,590),Color("30221c"))
	label(root,"STOCKROOM  /  APPRAISAL",Rect2(40,94,520,38),27,GOLD)
	var owned: Array=[]
	var storage_count:=0
	var display_count:=0
	for i in s.items.values():
		if i.owner!="shop": continue
		owned.append(i)
		if str(i.location).begins_with("storage:"): storage_count+=1
		if str(i.location).begins_with("shelf:"): display_count+=1
	label(root,"Storage %d/%d   •   Display %d/4"%[storage_count,shop.capacity(s),display_count],Rect2(40,138,520,28),18,MUTED)
	var pages:=maxi(1,int(ceil(float(owned.size())/4.0)))
	stock_page=clampi(stock_page,0,pages-1)
	for idx in range(stock_page*4,mini(owned.size(),stock_page*4+4)):
		var i: Dictionary=owned[idx]
		var id: String=i.instance
		var y:=181+(idx-stock_page*4)*98
		box(root,Rect2(40,y,525,88),Color("493528"))
		pic(root,jart.item(str(i.id),"icon"),Rect2(49,y+5,80,78))
		label(root,str(i.name),Rect2(142,y+9,280,30),21)
		label(root,slot_name(str(i.location)),Rect2(142,y+44,280,29),16,MUTED)
		btn(root,"Selected" if s.selected==id else "Select",Rect2(435,y+23,115,41),func(): command("select",{"item":id}),active(s) or s.selected==id,s.selected==id)
	btn(root,"Previous",Rect2(40,590,135,42),func(): stock_page-=1; refresh(),stock_page==0)
	label(root,"%d / %d"%[stock_page+1,pages],Rect2(186,595,104,32),18,GOLD)
	btn(root,"Next",Rect2(280,590,95,42),func(): stock_page+=1; refresh(),stock_page>=pages-1)
	btn(root,"Restock",Rect2(385,590,175,42),func(): command("restock"),active(s),true)
	var i: Dictionary=s.item
	box(root,Rect2(605,78,655,590),Color("392820"))
	if i.owner!="shop":
		label(root,"Select an owned item",Rect2(625,95,600,40),28,GOLD)
		label(root,"Merchandise held by a customer is not your stock.",Rect2(625,170,600,60),20)
		return
	var knowledge:=Data.appraisal(i,s.expertise)
	label(root,str(i.name),Rect2(625,95,600,40),29,GOLD)
	pic(root,jart.item(str(i.id),"icon"),Rect2(640,145,260,230))
	label(root,"Condition: "+knowledge.condition+"\nValue: "+knowledge.range+"\nAsking: %dg"%i.asking,Rect2(910,145,330,105),20)
	label(root,"Evidence: "+knowledge.evidence+"\nOrigin: "+knowledge.provenance,Rect2(910,258,330,140),17,MUTED)
	var locked: bool=active(s)
	make_price(root,Rect2(625,410,180,42),int(i.asking))
	btn(root,"Set price",Rect2(815,410,180,42),func(): command("price",{"amount":price_value}),locked)
	btn(root,"Appraise",Rect2(1005,410,235,42),func(): command("appraise"),locked)
	label(root,"Move to a compatible display slot",Rect2(625,466,600,27),17,MUTED)
	for idx in range(4):
		var loc: String="shelf:%d"%idx
		btn(root,("Shelf " if idx<2 else "Rack ")+str(idx%2+1),Rect2(625+idx*155,497,145,41),func(): command("move",{"location":loc}),locked or shop.owned_slot(s,loc) or not Fixtures.slot_allowed(i,loc))
	btn(root,"Return to storage",Rect2(625,557,300,46),func(): store_selected(),locked or str(i.location).begins_with("storage:"))
	btn(root,"Inspect at counter",Rect2(935,557,305,46),func(): switch_view("counter"),false,true)
	label(root,"Acquired for %dg   •   Expertise %s"%[i.acquisition_cost,"trained" if s.expertise else "novice"],Rect2(625,615,600,30),16,MUTED)

func draw_floor(s: Dictionary) -> void:
	# Pixel-world art is independent from the smooth VN and UI layers.
	pixel(root,jart.env("floor"),Rect2(0,64,1280,624))
	# Stationary shopkeeper behind separate counter foreground; both arms above the counter.
	keeper_node=pixel(root,jart.sprite("shopkeeper",0),Rect2(548,140,64,96))
	keeper_node.name="ShopkeeperPixel"
	pixel(root,jart.env("floor_counter"),Rect2(380,224,400,96))
	for fixture in Fixtures.IDS:
		draw_fixture(s,fixture)
	retail.sync(s,Assets.config().sockets)
	if retail.state!="ABSENT":
		customer_node=pixel(root,jart.sprite(str(s.customer.id),jart.frame_index(retail.state,retail.elapsed)),Rect2(retail.snapped(),Vector2(64,96)))
		customer_node.name="CustomerPixel"
		customer_node.flip_h=retail.facing_left
	# UI remains separate from world textures; no fake shoppers.
	btn(root,"Counter",Rect2(397,286,146,32),func(): open_counter())
	btn(root,"Stockroom",Rect2(1065,180,170,40),func(): switch_view("stockroom"))
	if waiting(s):
		box(root,Rect2(720,77,532,74))
		label(root,"Customer waiting  •  " + str(s.customer.name),Rect2(735,88,310,30),19,GOLD)
		btn(root,"Serve customer",Rect2(1045,91,190,46),func(): open_counter(),false,true)
	elif active(s):
		btn(root,"Resume conversation",Rect2(1005,91,245,46),func(): switch_view("counter"),false,true)
	if shop.next_waiting(s): btn(root,"Welcome next visitor",Rect2(1005,151,245,42),func(): command("next_customer"),false,true)
	btn(root,"Merchant journal",Rect2(28,625,195,42),func(): open_drawer("journal"))
	if drawer=="journal": draw_journal(s)
	elif drawer=="report": draw_report(s)
	elif drawer == "fixture": draw_fixture_panel(s)
	elif drawer == "status":
		box(root,Rect2(28,78,300,250))
		label(root,"Shop hours",Rect2(44,93,260,38),24)
		btn(root,"Open shop",Rect2(44,140,268,42),func(): command("open"),s.phase != "morning",true)
		btn(root,"Close shop",Rect2(44,188,268,42),func(): command("close"),s.phase != "open")
		btn(root,"Closing report",Rect2(44,236,268,34),func(): open_drawer("report"),s.phase!="closed")
		btn(root,"Next day",Rect2(44,275,268,34),func(): command("next_day"),s.phase != "closed" or s.day >= 5)


func draw_counter(s: Dictionary) -> void:
	var n: Dictionary = s.session
	var is_active := active(s)
	var has_customer: bool = is_active or social_present(s)
	var show_departure := portrait_event == "exit"
	# Identical physical view for inspection, waiting, negotiation and settlement.
	counter_room = pic(root,jart.env("counter_room"),Rect2(0,62,1280,330))
	counter_room.stretch_mode = TextureRect.STRETCH_SCALE
	draw_counter_fixtures(s)
	if has_customer or show_departure:
		var emotion: String = str(n.get("expression","relieved" if int(s.customer.get("history_modifier",0)) > 0 else "interested"))
		var key := JapanArt.expression(emotion)
		portrait = pic(root,portrait_texture(s.customer,key),Rect2(280,64,470,370))
		portrait.name = "CustomerPortrait"
		portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		animate_customer(portrait,emotion,float(s.customer.get("presentation_motion",1.0)))
	# Physical counter surface occludes the lower body. All staged merchandise is above this layer.
	counter_surface = pic(root,jart.env("counter_surface"),Rect2(0,390,1280,128))
	counter_surface.stretch_mode = TextureRect.STRETCH_SCALE
	if has_customer or show_departure:
		box(root,Rect2(22,78,278,78))
		label(root,str(s.customer.name),Rect2(36,88,275,32),27)
		label(root,str(s.customer.get("role","Customer"))+"  •  "+str(n.get("expression","Remembering")).capitalize(),Rect2(36,123,250,26),17,GOLD)
	else:
		box(root,Rect2(22,78,405,90)); label(root,"Your counter awaits",Rect2(38,90,370,38),25)
		label(root,"Inspection preview — no deal in progress" if s.item.owner=="shop" else "Prepare your display and open the shop.",Rect2(38,128,370,38),16,MUTED)
		if waiting(s): btn(root,"Welcome customer",Rect2(22,180,240,45),func(): open_counter(),false,true)
	var i: Dictionary = s.item
	# Item anchor is independent of the HUD and ledger; texture fit accommodates large objects.
	if (is_active and s.visit_goal in ["buy","sell","barter"]) or (not is_active and i.owner=="shop"):
		var stage := Presentation.stage_rect(i)
		pic(root,Assets.texture(str(Assets.config().stage_shadow)),Presentation.shadow_rect(i))
		item_stage = pic(root,jart.item(str(i.id),"stage"),stage)
		item_stage.name = "StagedItem"
		box(root,Rect2(944,78,316,124))
		pic(root,jart.item(str(i.id),"icon"),Rect2(955,91,74,91))
		label(root,str(i.name),Rect2(1035,88,213,50),19 if str(i.name).length() > 12 else 24)
		label(root,"Condition " + str(Data.appraisal(i,s.expertise).condition),Rect2(1038,144,207,25),16,GOLD)
		label(root,("Seller asks %dg" % n.offer) if s.visit_goal=="sell" and is_active else "Asking %dg" % n.get("ask",i.asking),Rect2(1038,169,207,25),17,GOLD)
	btn(root,"Hide ledger" if ledger else "View ledger",Rect2(1065,213,194,40),func(): ledger = not ledger; refresh())
	if is_active and s.visit_goal=="barter" and not ledger and n.has("trade_item"):
		box(root,Rect2(944,260,316,73),Color("30221c"))
		pic(root,jart.item(str(s.items[n.trade_item].id),"icon"),Rect2(950,265,60,60))
		label(root,"Trade: "+str(s.items[n.trade_item].name)+"\n+ %dg"%n.trade_cash,Rect2(1018,265,232,61),16,GOLD)
	if ledger: draw_ledger()
	box(root,Rect2(22,518,858,159),Color("30221c"))
	label(root,str(s.customer.name) if has_customer else "Counter",Rect2(36,528,820,26),18,GOLD)
	var line: String = provider_line(s) if not n.is_empty() else (str(s.return_note) if s.return_note != "" else "No active conversation.")
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
	label(root,"PROPOSED PURCHASE" if s.visit_goal=="sell" else "PROPOSED DEAL",Rect2(912,528,334,27),17,Color("79512f"))
	var offer := int(n.get("offer",0))
	label(root,deal_text(s) if is_active else "No active offer",Rect2(912,554,335,36),21 if s.reservation.has("terms") else 24,Color("36251c"))
	var pending: bool = is_active and n.status == "pending"
	label(root,deal_detail(s),Rect2(912,594,335,29),15,Color("79512f"))
	btn(root,("Confirm buy" if s.visit_goal=="sell" else ("Confirm trade" if s.reservation.has("terms") else "Confirm sale")) if pending else "Review offer",Rect2(912,628,159,39),func(): review_or_confirm(pending),not is_active or s.visit_goal in ["social","complaint"],true)
	btn(root,"Reject / leave",Rect2(1080,628,166,39),func(): act("reject","No deal."),not is_active)
	if drawer == "responses" and is_active and n.status == "negotiating": draw_responses(s)
	if shop.next_waiting(s): btn(root,"Next visitor",Rect2(22,180,240,42),func(): command("next_customer"),false,true)


