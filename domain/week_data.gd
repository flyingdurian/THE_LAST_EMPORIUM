extends RefCounted
const Shop = preload("res://domain/shop.gd")
static func read() -> Dictionary:
	return Shop.parse_save(FileAccess.get_file_as_string("res://data/week.json"))
static func baseline() -> Dictionary:
	return Shop.read_content()
static func definition(book: Dictionary,id: String) -> Dictionary:
	for i in book.items:
		if i.id==id: return i.duplicate(true)
	return {}
static func make_item(book: Dictionary,id: String,key: String,owner: String,loc: String) -> Dictionary:
	var i:=definition(book,id)
	i.instance=key; i.owner=owner; i.location=loc; i.appraised=false; i["knowledge"]=0
	return i
static func return_line(c: Dictionary,goal: String) -> String:
	if goal=="complaint": return "Could you keep a little stock for regulars? I rely on this shop for herbs."
	if int(c.get("history_modifier",0))>0: return "I remember your fairness. "+str(c.clue)
	if int(c.get("history_modifier",0))<0: return "I remember your threat. Let us keep this brief."
	return "Good to see you again. How has the shop been?"
static func appraisal(i: Dictionary, expertise: int) -> Dictionary:
	var level: int=int(i.get("knowledge",0))
	var value: int=int(i.base_value*i.condition_pct*i.demand_pct/10000.0)
	var spread: int=15 if level>=2 else 35
	return {"condition":str(i.condition_pct)+"%" if level>0 else "Unknown","range":"%d–%dg"%[maxi(1,int(value*(100-spread)/100.0)),int(value*(100+spread)/100.0)] if level>0 else "Unknown","evidence":str(i.evidence) if level>0 else "Inspect to reveal evidence","provenance":str(i.provenance) if level>=2 else "Unknown"}

static func rank(book: Dictionary,id: String) -> int:
	for idx in range(book.items.size()):
		if book.items[idx].id==id: return idx
	return book.items.size()
