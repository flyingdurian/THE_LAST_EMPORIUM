extends "res://ui/gate_c.gd"
const Week = preload("res://domain/week_shop.gd")
const Data = preload("res://domain/week_data.gd")
const Provider = preload("res://domain/offline_provider.gd")
var stock_page := 0
func _ready() -> void:
	shop=Week.new()
	ui_save_path="user://emporium_week_ui.json"
	super._ready()
func waiting(s: Dictionary) -> bool:
	return shop.waiting_week(s)
func social_present(_s: Dictionary) -> bool:
	return false
func portrait_texture(c: Dictionary,key: String) -> Texture2D:
	if c.id=="vessa_rook": return Assets.texture(str(Assets.config().portraits[key]))
	return Assets.texture(str(Assets.config().week_customers[c.id].portraits[key]))
func floor_texture(c: Dictionary) -> Texture2D:
	if c.id=="vessa_rook": return Assets.texture(str(Assets.config().customer_floor))
	return Assets.texture(str(Assets.config().week_customers[c.id].floor))
func provider_line(s: Dictionary) -> String:
	return Provider.render(Negotiation.public_plan(s.session),{"style":s.customer.get("style","courteous"),"note":s.return_note if s.return_note!="" else "A little conversation is welcome. Let us return to business."})
func append_npc(s: Dictionary) -> void:
	last_line=provider_line(s)
	history.append({"speaker":str(s.customer.name),"text":last_line})
func deal_text(s: Dictionary) -> String:
	if s.visit_goal in ["social","complaint"]: return "No trade requested"
	if s.reservation.has("terms"): return "%dg + %s"%[s.session.offer,s.items[s.session.trade_item].name]
	if s.visit_goal=="sell": return "Pay %dg  •  %s"%[s.session.offer,s.item.name]
	return "%dg  •  %s"%[s.session.offer,s.item.name]
func command(kind: String,args: Dictionary={},player_line: String="") -> void:
	super.command(kind,args,player_line)
	if kind=="next_customer" and message=="":
		history=[]; history_session=-1; last_line=""; view="floor"; drawer=""; refresh()
	if kind=="close" and message=="":
		view="floor"; drawer="report"; refresh()
func draw_header(s: Dictionary) -> void:
	super.draw_header(s)
	# Five-day scenario label is separate from the immutable game title.
func draw_responses(s: Dictionary) -> void:
	box(root,Rect2(22,170,490,338))
	label(root,"Choose your response",Rect2(38,182,455,35),24)
	var social: bool=s.visit_goal in ["social","complaint"]
	make_price(root,Rect2(38,224,175,40),maxi(1,int(s.session.ask)))
	btn(root,"Counteroffer",Rect2(223,224,270,40),func(): act("counter","I propose %dg."%price_value,true),social)
	var rows: Array=[["evidence","Show appraisal",true],["reassure","Acknowledge / reassure",not social],["patient","Bargain patiently",not social],["flatter","Flatter",not social],["small_talk","Personal conversation",false],["firm","Stand firm",false],["ban_threat","Threaten a ban",false],["insult","Insult",false],["dismiss","Dismiss customer",false],["violence_threat","Threaten violence",false],["end","End conversation",false]]
	if s.visit_goal=="barter": rows[0]=["barter","Offer item + gold trade",false]
	if s.visit_goal=="sell": rows[0]=["inspect","Inspect offered goods",false]
	if s.rumor.get("state","")=="known" and s.customer.id==s.rumor.get("knower",""): rows.append(["ask_rumor","Ask about the quarry",false])
	else: rows.append(["banter","Blunt banter",false])
	for idx in range(rows.size()):
		var row: Array=rows[idx]; var kind: String=row[0]; var caption: String=row[1]; var priced: bool=row[2]
		btn(root,caption,Rect2(38+(idx%2)*230,272+int(idx/2)*37,220,34),func(): choose_response(kind,caption,priced),social and kind=="evidence")
func draw_stockroom(s: Dictionary) -> void:
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
		pic(root,Assets.item_texture(i),Rect2(49,y+5,80,78))
		label(root,str(i.name),Rect2(142,y+9,280,30),21)
		label(root,str(i.location).replace("shelf:","Display slot ").replace("storage:","Storage slot "),Rect2(142,y+44,280,29),16,MUTED)
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
	pic(root,Assets.item_texture(i),Rect2(640,145,260,230))
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
func store_selected() -> void:
	var loc: String=shop.storage_slot(shop.snapshot())
	if loc=="": message="Storage full."; refresh()
	else: command("move",{"location":loc})
func draw_journal(s: Dictionary) -> void:
	box(root,Rect2(22,80,550,530),Color("30221c"))
	label(root,"MERCHANT JOURNAL",Rect2(40,94,500,40),26,GOLD)
	var ex: Dictionary=s.expedition
	var report: String="Hire Iona for the Old Quarry • 90g • returns in 2 days."
	if not ex.is_empty():
		report="Iona is away until Day %d."%ex.due if ex.state=="away" else ("Iona returned injured; one fragment recovered." if ex.injury else "Bram returned with Moon Glass and a Quarry Relic.")
	label(root,report,Rect2(40,143,510,64),19)
	btn(root,"Dispatch expedition",Rect2(40,211,510,42),func(): command("dispatch"),s.phase!="morning" or not ex.is_empty() or s.day>3,true)
	btn(root,"Train appraisal • 50g",Rect2(40,265,510,42),func(): command("expertise"),s.phase!="morning" or s.expertise>0)
	btn(root,"Expand storage • 75g",Rect2(40,317,510,42),func(): command("upgrade",{"upgrade":"storage"}),s.phase!="morning" or s.upgrades.storage)
	btn(root,"Shop sign • 60g",Rect2(40,369,510,42),func(): command("upgrade",{"upgrade":"sign"}),s.phase!="morning" or s.upgrades.sign)
	var debt: String="Installment: %dg / 250g. Due Day 3."%s.debt.paid
	if s.debt.warning: debt+=" Grace through Day 5; shop stays open."
	label(root,debt,Rect2(40,421,510,55),18,GOLD)
	btn(root,"Pay outstanding installment",Rect2(40,479,510,42),func(): command("pay_debt"),s.day<3 or s.phase!="morning" or s.debt.paid>=250)
	var rumor: String="Repair demand: normal"
	if s.rumor.get("state","")=="disclosed": rumor="Repair demand +20% until Day %d"%s.rumor.expires
	label(root,rumor,Rect2(40,534,510,29),17,MUTED)
	btn(root,"Close",Rect2(40,568,510,29),func(): open_drawer("journal"))
func draw_report(s: Dictionary) -> void:
	box(root,Rect2(340,90,600,530),Color("30221c"))
	var r: Dictionary=s.reports.back() if not s.reports.is_empty() else shop.day_report(s)
	label(root,"DAY %d  /  CLOSING LEDGER"%r.day,Rect2(364,103,550,40),26,GOLD)
	var rows: Array=[["Opening cash",r.opening],["Cash sales",r.sales],["Stock purchases",-r.purchases],["Barter cash",r.barter_cash],["Other expenses",-r.expenses],["Cash movement",r.cash_movement],["Closing cash",r.closing],["Cost of goods sold",r.cogs],["Barter goods received",r.barter_value],["Realized trading profit",r.profit]]
	for idx in range(rows.size()):
		label(root,"%s: %dg"%[rows[idx][0],rows[idx][1]],Rect2(364,151+idx*29,550,28),18,PAPER if idx!=9 else GOLD)
	label(root,"%d deals  •  Profit excludes operating expenses"%r.deals,Rect2(364,449,550,28),16,MUTED)
	label(root,"Payment overdue — recover through Day 5." if s.debt.warning else "Your shop is closed for the day.",Rect2(364,485,550,28),17,GOLD)
	btn(root,"Continue to Day %d"%(s.day+1) if s.day<5 else "Week complete",Rect2(364,530,550,48),func(): command("next_day"),s.day>=5,true)

func draw_floor(s: Dictionary) -> void:
	# Full empty-room composition; only fixed architecture and counter are painted.
	var plate := pic(root,Assets.texture(str(Assets.config().floor)),Rect2(0,62,1280,622))
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	# Stationary shopkeeper, independent of the background; the counter masks the lower body.
	pic(root,Assets.texture(str(Assets.config().keeper)),Rect2(532,178,76,84))
	if waiting(s) or active(s) or social_present(s): pic(root,floor_texture(s.customer),Rect2(612,252,44,94))
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
	counter_room = pic(root,Assets.texture(str(Assets.config().counter_room)),Rect2(0,62,1280,330))
	counter_room.stretch_mode = TextureRect.STRETCH_SCALE
	draw_counter_fixtures(s)
	if has_customer or show_departure:
		var emotion: String = str(n.get("expression","relieved" if int(s.customer.get("history_modifier",0)) > 0 else "interested"))
		var key := Presentation.expression(emotion)
		portrait = pic(root,portrait_texture(s.customer,key),Rect2(306,78,364,416))
		portrait.name = "CustomerPortrait"
		animate_customer(portrait,emotion,float(s.customer.get("presentation_motion",1.0)))
	# Physical counter surface occludes the lower body. All staged merchandise is above this layer.
	counter_surface = pic(root,Assets.texture(str(Assets.config().counter_surface)),Rect2(0,390,1280,128))
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
		item_stage = pic(root,Presentation.stage_texture(i),stage)
		item_stage.name = "StagedItem"
		box(root,Rect2(944,78,316,124))
		pic(root,Assets.item_texture(i),Rect2(955,91,74,91))
		label(root,str(i.name),Rect2(1035,88,213,50),19 if str(i.name).length() > 12 else 24)
		label(root,"Condition " + str(Data.appraisal(i,s.expertise).condition),Rect2(1038,144,207,25),16,GOLD)
		label(root,("Seller asks %dg" % n.offer) if s.visit_goal=="sell" and is_active else "Asking %dg" % n.get("ask",i.asking),Rect2(1038,169,207,25),17,GOLD)
	btn(root,"Hide ledger" if ledger else "View ledger",Rect2(1065,213,194,40),func(): ledger = not ledger; refresh())
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
	label(root,deal_text(s) if is_active else "No active offer",Rect2(912,555,335,43),25,Color("36251c"))
	var pending: bool = is_active and n.status == "pending"
	label(root,"Awaiting your confirmation" if pending else ("Customer offer — not yet accepted" if is_active else "Inspection only — no transaction"),Rect2(912,594,335,29),15,Color("79512f"))
	btn(root,("Confirm buy" if s.visit_goal=="sell" else ("Confirm trade" if s.reservation.has("terms") else "Confirm sale")) if pending else "Review offer",Rect2(912,628,159,39),func(): review_or_confirm(pending),not is_active or s.visit_goal in ["social","complaint"],true)
	btn(root,"Reject / leave",Rect2(1080,628,166,39),func(): act("reject","No deal."),not is_active)
	if drawer == "responses" and is_active and n.status == "negotiating": draw_responses(s)
	if shop.next_waiting(s): btn(root,"Next visitor",Rect2(22,180,240,42),func(): command("next_customer"),false,true)


func draw_fixture(s: Dictionary, fixture: String) -> void:
	var pos := fixture_pos(s,fixture)
	pic(root,Assets.texture(str(Assets.config()[fixture])),Rect2(pos,Vector2(260,130)))
	var first := 0 if fixture == "shelf" else 2
	for i in s.items.values():
		if i.owner != "shop" or not str(i.location).begins_with("shelf:"): continue
		if active(s) and s.visit_goal in ["buy","barter"] and i.instance == s.selected: continue
		var slot := int(str(i.location).get_slice(":",1))
		if slot < first or slot >= first+2: continue
		var item_rect := Presentation.display_rect(i,pos,slot-first,1.0)
		var display := pic(root,Assets.item_texture(i),item_rect)
		display.name = "Display_" + str(i.instance)
		floor_items[str(i.instance)] = display
	btn(root,"Display shelf" if fixture=="shelf" else "Equipment rack",Rect2(pos.x+36,pos.y+100,188,31),func(): selected_fixture=fixture; open_drawer("fixture"))

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
			if item.instance==s.selected and ((active(s) and s.visit_goal in ["buy","barter"]) or not active(s)): continue
			var slot := int(str(item.location).get_slice(":",1))
			if slot<first or slot>=first+2: continue
			var t := pic(root,Assets.item_texture(item),Presentation.display_rect(item,pos,slot-first,scale_factor))
			t.name = "Background_" + str(item.instance)
			counter_items[str(item.instance)] = t

