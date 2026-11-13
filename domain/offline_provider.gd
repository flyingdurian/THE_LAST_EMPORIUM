extends RefCounted
const Speech = preload("res://domain/dialogue.gd")
## Public speech plans and selected public context only. No command/state mutation.
static func render(plan: Dictionary, context: Dictionary) -> String:
	var act: String=plan.get("speech_act","")
	var amount: int=int(plan.get("offer",0))
	var line: String
	match act:
		"social": line=str(context.get("note","Let's talk about the shop."))
		"rumor": line="I found a guild mark at the quarry. Repair fragments are sought after now; that won't last forever."
		"seller_agreement": line="Agreed. %dg for my merchandise. Shall we settle?"%amount
		"seller_counter": line="I could part with it for %dg. I need a fair return."%amount
		"barter_agreement": line="My trade item and %dg. That suits me."%amount
		_: line=Speech.render(plan)
	var style: String=context.get("style","courteous")
	if act in ["opening","counter","claim_limit","agreement"]:
		match style:
			"blunt": line="Straight to business. "+line
			"practical": line="I have to watch every coin. "+line
			"formal": line="Let us be precise. "+line
			"dry": line="No need for ceremony. "+line
			"cheerful": line="A fine day for trade! "+line
	return line
