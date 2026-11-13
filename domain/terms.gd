extends RefCounted
## Pure term validator. Cash settlement is enabled; barter is validation-only in this milestone.
const N = preload("res://domain/negotiation.gd")
static func evaluate(terms: Dictionary, inventory: Dictionary, customer: Dictionary, willingness: int) -> Dictionary:
	var amount: Variant = terms.get("npc_pays_g",null)
	var outgoing: Variant = terms.get("shop_item_ids",[])
	var incoming: Variant = terms.get("npc_item_ids",[])
	if typeof(amount)!=TYPE_INT or amount<0 or amount>N.spendable(customer): return {"ok":false,"error":"Invalid cash"}
	if not outgoing is Array or not incoming is Array or outgoing.size()!=1: return {"ok":false,"error":"One shop item required"}
	var seen := {}
	var utility: int = amount
	for side_index in range(2):
		var side: Array = outgoing if side_index==0 else incoming
		for id in side:
			if not id is String or seen.has(id) or not inventory.has(id): return {"ok":false,"error":"Missing or duplicate item"}
			seen[id] = true
			var item: Dictionary = inventory[id]
			var expected: String = "shop" if side_index==0 else str(customer.id)
			if item.owner!=expected or bool(item.get("locked",false)): return {"ok":false,"error":"Ownership or lock conflict"}
			if side_index==1: utility += int(item.get("perceived_g",N.reference_value(item)))
	if utility<1 or utility>mini(int(customer.ceiling),willingness): return {"ok":false,"error":"Willingness exceeded"}
	return {"ok":true,"utility":utility,"cash":amount}
