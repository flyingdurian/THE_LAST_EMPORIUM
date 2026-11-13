extends RefCounted
## Offline speech performer. No command bus reference or write access.
static func render(plan: Dictionary) -> String:
	var amount := int(plan.get("offer",0))
	match plan.get("speech_act", ""):
		"opening": return "I would offer %dg. Would you consider it?" % amount
		"counter": return "I can offer %dg. I cannot agree to that price." % amount
		"claim_limit": return "I had set aside %dg. I cannot go higher." % amount
		"agreement": return "I can agree to %dg. Shall we settle?" % amount
		"final_offer": return "Wait! %dg. My final offer." % amount
		"safety_exit": return "I will not stay for this."
		"angry_exit": return "Enough. I am leaving."
		"departure": return "Then I will take my leave."
		"settled": return "Thank you. The deal is settled."
		_: return "Let us consider the terms."
