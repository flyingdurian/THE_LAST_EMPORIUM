extends RefCounted
## A pure presentation director. Actual visit state is the source of presence.
## No economy, time advancement, reservations or customer state writes.
const Fixtures=preload("res://domain/fixtures.gd")
const ENTRY:=Vector2(640,568)
const QUEUE:=Vector2(628,312)
var visit_key: String=""
var state: String="ABSENT"
var position:=ENTRY
var facing_left:=false
var elapsed:=0.0
var target_id: String=""
var browse_point:=Vector2.ZERO
var path: Array[Vector2]=[]
var leg: String=""
func key_for(s: Dictionary) -> String:
	return "%d:%d:%s"%[int(s.day),int(s.get("visit_index",0)),str(s.customer.id)]
func active(s: Dictionary) -> bool:
	return not s.session.is_empty() and s.session.status in ["negotiating","pending"]
func waiting(s: Dictionary) -> bool:
	return s.phase=="open" and not s.visited and not s.get("visit_spec",[]).is_empty()
func sync(s: Dictionary,sockets: Dictionary) -> void:
	if s.phase!="open" or not (active(s) or waiting(s)):
		state="ABSENT"; visit_key=""; target_id=""; path.clear(); return
	var key:=key_for(s)
	if active(s):
		visit_key=key; state="CHECKOUT_QUEUE"; position=QUEUE; path.clear(); target_id=str(s.selected); return
	if key==visit_key and state!="ABSENT": return
	visit_key=key; position=ENTRY; state="IDLE"; elapsed=0; target_id=""; browse_point=Vector2.ZERO; path.clear()
	var spec: Array=s.get("visit_spec",[])
	if spec.size()<3 or not spec[1] in ["buy","barter"]: return
	for i in s.items.values():
		if i.owner!="shop" or i.id!=spec[2] or not str(i.location).begins_with("shelf:"): continue
		var idx:=int(str(i.location).get_slice(":",1))
		var fixture: String="shelf" if idx<2 else "rack"
		var socket: String=str(s.fixtures[fixture])
		var coords: Array=sockets.get(socket,[350,374])
		var pos:=Vector2(float(coords[0]),float(coords[1]))
		# Authored aisle-side approach, never the interior of the furniture.
		browse_point=Vector2(pos.x+264 if pos.x<640 else pos.x-72,pos.y+10)
		target_id=str(i.instance); break
func begin_walk(to: Vector2, next_leg: String) -> void:
	path.clear()
	# Travel along center aisle then take a short horizontal approach.
	var aisle:=Vector2(640,to.y)
	if absf(position.x-640)>4: path.append(Vector2(640,position.y))
	if position.distance_to(aisle)>4: path.append(aisle)
	if aisle.distance_to(to)>4: path.append(to)
	if path.is_empty(): path.append(to)
	state="WALK"; leg=next_leg; elapsed=0
func step(delta: float) -> void:
	if state=="ABSENT": return
	elapsed+=delta
	match state:
		"IDLE":
			if elapsed>=0.35:
				begin_walk(browse_point if target_id!="" else QUEUE,"browse" if target_id!="" else "queue")
		"WALK":
			if path.is_empty():
				state="BROWSE" if leg=="browse" else "CHECKOUT_QUEUE"
				elapsed=0; return
			var point: Vector2=path[0]
			var direction:=point-position
			if absf(direction.x)>1: facing_left=direction.x<0
			position=position.move_toward(point,190.0*delta)
			if position.distance_to(point)<1:
				position=point; path.pop_front()
				if path.is_empty():
					state="BROWSE" if leg=="browse" else "CHECKOUT_QUEUE"
					if state=="BROWSE": facing_left=position.x<640
					elapsed=0
		"BROWSE":
			if elapsed>=1.0: state="PICK_ITEM"; elapsed=0
		"PICK_ITEM":
			if elapsed>=0.65: begin_walk(QUEUE,"queue")
		"CHECKOUT_QUEUE":
			pass
func snapped() -> Vector2:
	return Vector2(round(position.x/4)*4,round(position.y/4)*4)
