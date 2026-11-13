extends RefCounted
## Authored sockets only. Item slots belong to the fixture, not its position.
const SOCKETS = ["west","east","southwest","southeast"]
const IDS = ["shelf","rack"]
static func defaults() -> Dictionary:
	return {"shelf":"west","rack":"east"}
static func valid(layout: Dictionary) -> bool:
	return layout.size()==2 and layout.get("shelf","") in SOCKETS and layout.get("rack","") in SOCKETS and layout.shelf != layout.rack
static func can_place(layout: Dictionary, fixture: String, socket: String) -> bool:
	if not valid(layout) or not fixture in IDS or not socket in SOCKETS: return false
	for id in layout:
		if id != fixture and layout[id] == socket: return false
	return true
static func slot_allowed(item: Dictionary, location: String) -> bool:
	if not location.begins_with("shelf:"): return true
	var kind: String = str(item.get("display_kind","any"))
	var slot: int = int(location.get_slice(":",1))
	return kind == "any" or (kind == "shelf" and slot < 2) or (kind == "rack" and slot >= 2)
