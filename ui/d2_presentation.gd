extends RefCounted
## Pure visual projection of actual state, no domain mutations.
const Assets = preload("res://ui/d1_assets.gd")
static func presence(s: Dictionary) -> String:
	if s.phase!="open": return "absent"
	if not s.session.is_empty() and s.session.status in ["negotiating","pending"]: return "counter"
	if s.visited and s.session.is_empty() and s.return_note!="": return "social"
	if not s.visited and not s.customer.safety_hold and int(s.customer.ban_until)<=int(s.day): return "waiting"
	return "absent"
static func expression(emotion: String) -> String:
	if emotion in ["relieved","pleased","happy"]: return "pleased"
	if emotion in ["offended","fearful","frightened","distressed","guarded","departing"]: return "offended"
	return "neutral"
static func reaction(emotion: String) -> Vector2:
	match expression(emotion):
		"pleased": return Vector2(0,-7)
		"offended": return Vector2(-8,3)
		_: return Vector2(0,3)
static func display_rect(item: Dictionary, pos: Vector2, slot: int, factor: float) -> Rect2:
	var spec: Dictionary = Assets.config().display_sizes.get(str(item.id),{"size":[40,45],"offset":[52,-31]})
	var size := Vector2(float(spec.size[0]),float(spec.size[1]))*factor
	var offset := Vector2(float(spec.offset[0])+float(slot)*106.0,float(spec.offset[1]))*factor
	return Rect2(pos+offset,size)
static func stage_rect(item: Dictionary) -> Rect2:
	# The sword lies along the surface; the shield stands against it. The crystal stays compact.
	return Rect2(740,222,470,282) if item.get("stage_size","small")=="large" else Rect2(795,310,270,192)
static func stage_texture(item: Dictionary) -> Texture2D:
	var path: String = str(Assets.config().get("counter_items",{}).get(str(item.id),""))
	return Assets.texture(path) if path!="" else Assets.item_texture(item)
