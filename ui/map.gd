extends Control
var host
func _draw() -> void:
	if host == null: return
	var scale_v := Vector2(size.x/580.0,size.y/450.0)
	draw_set_transform(Vector2.ZERO,0.0,scale_v)
	draw_rect(Rect2(0,0,580,450),Color("4d3d35"))
	var tile: int = host.tile_mode
	for x in range(0,580,tile): draw_line(Vector2(x,0),Vector2(x,450),Color("5a4840"))
	for y in range(0,450,tile): draw_line(Vector2(0,y),Vector2(580,y),Color("5a4840"))
	var font := ThemeDB.fallback_font
	draw_rect(host.DOOR,Color("6c7972")); draw_string(font,Vector2(495,350),"DOOR",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	var s: Dictionary=host.shop.snapshot()
	if host.room=="shop":
		draw_rect(host.COUNTER,Color("94663c")); draw_string(font,Vector2(95,130),"COUNTER",HORIZONTAL_ALIGNMENT_LEFT,-1,22)
		draw_rect(host.SHELF,Color("9b795a")); draw_string(font,Vector2(78,240),"SHELF",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		if s.item.location=="shelf:0": draw_circle(Vector2(115,275),14,Color("c65353"))
		if s.visited and not s.session.is_empty() and s.session.status in ["negotiating","pending"]: draw_circle(Vector2(235,70),19,Color("b390b8")); draw_string(font,Vector2(260,76),"Customer",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	else:
		draw_rect(host.CHEST,Color("9b795a")); draw_string(font,Vector2(95,145),"STOCK",HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		if s.item.location=="storage:0": draw_circle(Vector2(170,170),14,Color("c65353"))
	draw_circle(host.pos,13,Color("e7d5ac")); draw_string(font,host.pos+Vector2(17,-4),"You",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
