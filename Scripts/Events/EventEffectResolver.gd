class_name EventEffectResolver
extends RefCounted


var registry: EventDataRegistry


func _init(p_registry: EventDataRegistry) -> void:
	registry = p_registry


func preflight(
	effects: Array,
	participants: Dictionary,
	context: Dictionary,
	starting_money: int,
	starting_diamonds: int
) -> Dictionary:
	var plans: Array = []
	var failures: Array = []
	var money := starting_money
	var diamonds := starting_diamonds
	var reserved_items: Dictionary = {}
	var exclusive_mutations: Dictionary = {}
	for index in effects.size():
		var effect_value = effects[index]
		if typeof(effect_value) != TYPE_DICTIONARY:
			failures.append(_failure(index, "invalid_effect", "An Event effect is unavailable."))
			continue
		var effect: Dictionary = effect_value
		var plan := _plan_effect(index, effect, participants, context, reserved_items)
		if not bool(plan.get("valid", false)):
			failures.append(plan.get("failure", _failure(index, "effect_unavailable", "An Event effect cannot currently be applied.")))
			continue
		var exclusive_key := _exclusive_mutation_key(plan)
		if not exclusive_key.is_empty() and exclusive_mutations.has(exclusive_key):
			failures.append(_failure(index, "conflicting_effects", "Multiple Event effects would mutate the same authoritative state in one atomic resolution."))
			continue
		if not exclusive_key.is_empty():
			exclusive_mutations[exclusive_key] = true
		match String(effect.get("type", "")):
			"money_change": money = maxi(money + int(effect.get("amount", 0)), 0)
			"diamond_change": diamonds = maxi(diamonds + int(effect.get("amount", 0)), 0)
			"education_enroll": money -= int(plan.get("domain_cost", 0))
			"business_upgrade": money -= int(plan.get("domain_cost", 0))
		if money < 0:
			failures.append(_failure(index, "insufficient_money", "The family cannot afford all Event effects."))
		if diamonds < 0:
			failures.append(_failure(index, "insufficient_diamonds", "The family cannot afford all Event effects."))
		plans.append(plan)
	return {"valid": failures.is_empty(), "plans": plans, "failure_reasons": failures, "final_money": money, "final_diamonds": diamonds}


func apply(plans: Array, source_instance_id: String) -> Dictionary:
	var results: Array = []
	var created_items: Dictionary = {}
	for plan_value in plans:
		var plan: Dictionary = plan_value
		var result := _apply_plan(plan, source_instance_id, created_items)
		results.append(result)
		if not bool(result.get("success", false)):
			return {"success": false, "effect_results": results, "failure_reasons": [result]}
	return {"success": true, "effect_results": results, "failure_reasons": []}


func _plan_effect(index: int, effect: Dictionary, participants: Dictionary, context: Dictionary, reserved_items: Dictionary) -> Dictionary:
	var effect_type := String(effect.get("type", ""))
	var plan := {"valid": true, "index": index, "effect": effect.duplicate(true), "type": effect_type}
	match effect_type:
		"stat_change", "stat_set", "add_flag", "remove_flag", "relationship_status_set", "accept_job_offer", "reject_job_offer", "job_remove", "salary_increase", "education_enroll", "add_item", "remove_item", "equip_item", "unequip_item", "remove_from_house":
			var character_id := _character_id(effect, "target", participants)
			if character_id <= 0:
				return _invalid(index, "target_unavailable", "The target Character is no longer available.")
			plan["character_id"] = character_id
		"relationship_marry", "relationship_divorce":
			var primary_id := _character_id(effect, "primary", participants)
			var target_id := _character_id(effect, "target", participants)
			if primary_id <= 0 or target_id <= 0:
				return _invalid(index, "relationship_target_unavailable", "The relationship participants are no longer available.")
			plan["primary_id"] = primary_id
			plan["target_id"] = target_id
		"business_upgrade":
			var business_id := _string_target(effect, "business", participants, context)
			var cost := BusinessManager.get_business_upgrade_cost(business_id)
			if business_id.is_empty() or cost <= 0:
				return _invalid(index, "business_upgrade_unavailable", "The Business cannot currently be upgraded.")
			plan["business_id"] = business_id
			plan["domain_cost"] = cost

	match effect_type:
		"stat_change", "stat_set":
			if String(effect.get("stat", "")) not in CharacterManager.CHARACTER_STAT_NAMES:
				return _invalid(index, "stat_unavailable", "The Character stat is unavailable.")
		"relationship_status_set":
			var relationship_status := String(effect.get("value", "")).strip_edges()
			if not RelationshipNpcManager.can_set_external_relationship_status(
				int(plan["character_id"]),
				relationship_status
			):
				return _invalid(index, "relationship_status_unavailable", "The Relationship status can no longer be changed.")
			plan["relationship_status"] = relationship_status
		"relationship_marry":
			var candidate := CharacterManager.get_character_by_id(int(plan["target_id"]))
			var partner := CharacterManager.get_character_by_id(int(plan["primary_id"]))
			if String(candidate.get("character_type", "")) != "relationship_npc":
				candidate = CharacterManager.get_character_by_id(int(plan["primary_id"]))
				partner = CharacterManager.get_character_by_id(int(plan["target_id"]))
				plan["primary_id"] = int(partner.get("character_id", 0))
				plan["target_id"] = int(candidate.get("character_id", 0))
			if not RelationshipNpcManager.can_make_candidate_family_member(int(candidate.get("character_id", 0)), int(partner.get("character_id", 0))):
				return _invalid(index, "marriage_unavailable", "These Characters can no longer marry.")
		"relationship_divorce":
			if not RelationshipNpcManager.are_married_partners(CharacterManager.get_character_by_id(int(plan["primary_id"])), CharacterManager.get_character_by_id(int(plan["target_id"]))):
				return _invalid(index, "divorce_unavailable", "These Characters are no longer married.")
		"accept_job_offer":
			var character := CharacterManager.get_character_by_id(int(plan["character_id"]))
			if not CareerManager.is_active_job_offer_valid(character, CareerManager.get_active_job_offer(int(plan["character_id"]))):
				return _invalid(index, "job_offer_unavailable", "The Job offer is no longer available.")
		"reject_job_offer":
			if CareerManager.get_active_job_offer(int(plan["character_id"])).is_empty():
				return _invalid(index, "job_offer_unavailable", "The Job offer is no longer available.")
		"job_remove":
			if CharacterManager.get_character_by_id(int(plan["character_id"])).get("job_id", null) == null:
				return _invalid(index, "external_job_unavailable", "The Character has no external Job to remove.")
		"salary_increase":
			var character := CharacterManager.get_character_by_id(int(plan["character_id"]))
			if character.get("job_id", null) == null or String(character.get("company_id", "")).is_empty():
				return _invalid(index, "external_job_unavailable", "The Character has no external salary to increase.")
		"education_enroll":
			var school_id := int(effect.get("school_id", 0))
			if not EducationManager.can_enroll_character_in_school(int(plan["character_id"]), school_id):
				return _invalid(index, "education_enrollment_unavailable", "School enrollment is no longer available.")
			plan["school_id"] = school_id
			plan["domain_cost"] = int(EducationManager.get_school_by_id(school_id).get("base_cost", 0))
		"add_item":
			if ItemManager.get_item_definition(String(effect.get("item_id", ""))).is_empty():
				return _invalid(index, "item_unavailable", "The Item definition is unavailable.")
			plan["created_item_key"] = "effect_%d" % index
		"remove_item", "equip_item", "unequip_item":
			var item_plan := _plan_item(effect_type, int(plan["character_id"]), String(effect.get("item_id", "")), reserved_items)
			if not bool(item_plan.get("valid", false)):
				return _invalid(index, "item_instance_unavailable", "No eligible matching Item instance is available.")
			for key in item_plan:
				plan[key] = item_plan[key]
			reserved_items[String(item_plan.get("instance_id", ""))] = true
		"remove_from_house":
			if HouseManager.get_character_assignment(int(plan["character_id"])).is_empty():
				return _invalid(index, "house_assignment_unavailable", "The Character is not assigned to a House.")
		"queue_event":
			var target_event := registry.get_event(String(effect.get("event_id", "")))
			if target_event.is_empty() or String(target_event.get("trigger", {}).get("type", "")) != "chain":
				return _invalid(index, "chain_event_unavailable", "The follow-up Event is unavailable.")
			var inherited_participants := EventManager.active_event.participants if EventManager.active_event != null else participants
			var inherited_context := EventManager.active_event.context if EventManager.active_event != null else context
			if not bool(EventManager.can_activate_chain(String(effect.get("event_id", "")), inherited_participants, inherited_context).get("available", false)):
				return _invalid(index, "chain_event_locked", "The follow-up Event is no longer available.")
		"schedule_event":
			var target_event := registry.get_event(String(effect.get("event_id", "")))
			if target_event.is_empty() or String(target_event.get("trigger", {}).get("type", "")) != "scheduled":
				return _invalid(index, "scheduled_event_unavailable", "The scheduled Event is unavailable.")
		"cancel_scheduled_event":
			if not _has_scheduled_target(effect):
				return _invalid(index, "scheduled_event_unavailable", "No matching scheduled Event is available to cancel.")
		"add_flag", "remove_flag", "money_change", "diamond_change", "remove_from_house", "business_upgrade": pass
		_:
			return _invalid(index, "unsupported_effect", "The Event effect is unsupported.")
	return plan


func _apply_plan(plan: Dictionary, source_instance_id: String, created_items: Dictionary) -> Dictionary:
	var effect: Dictionary = plan["effect"]
	var effect_type := String(plan["type"])
	var result := {"success": false, "effect_type": effect_type, "effect_index": int(plan["index"])}
	var character_id := int(plan.get("character_id", 0))
	match effect_type:
		"stat_change", "stat_set":
			var character := CharacterManager.get_character_by_id(character_id)
			var stat := String(effect.get("stat", ""))
			var before := int(character.get(stat, 0))
			var requested := int(effect.get("amount", 0)) if effect_type == "stat_change" else int(effect.get("value", 0)) - before
			var mutation := CharacterManager.set_character_stat(character_id, stat, before + requested)
			result.merge({"success": not mutation.is_empty(), "target_character_id": character_id, "stat": stat, "requested_amount": requested, "applied_amount": int(mutation.get("applied_amount", 0)), "before": before, "after": int(mutation.get("after", before))}, true)
		"add_flag", "remove_flag":
			var enabled := effect_type == "add_flag"
			result.merge({
				"success": CharacterManager.set_character_flag(
					character_id,
					effect.get("flag_id", null),
					enabled
				),
				"target_character_id": character_id
			}, true)
		"money_change":
			var before := GameManager.family_money
			GameManager.set_family_money(before + int(effect.get("amount", 0)))
			result.merge({"success": true, "requested_amount": int(effect.get("amount", 0)), "applied_amount": GameManager.family_money - before, "before": before, "after": GameManager.family_money}, true)
		"diamond_change":
			var before := GameManager.diamonds
			GameManager.set_diamonds(before + int(effect.get("amount", 0)))
			result.merge({"success": true, "requested_amount": int(effect.get("amount", 0)), "applied_amount": GameManager.diamonds - before, "before": before, "after": GameManager.diamonds}, true)
		"relationship_status_set":
			var character := CharacterManager.get_character_by_id(character_id)
			var before := String(character.get("relationship_status", ""))
			var after := String(plan.get("relationship_status", ""))
			result.merge({
				"success": RelationshipNpcManager.set_external_relationship_status(
					character_id,
					after
				),
				"target_character_id": character_id,
				"before": before,
				"after": after
			}, true)
		"relationship_marry": result["success"] = RelationshipNpcManager.make_candidate_family_member(int(plan["target_id"]), int(plan["primary_id"]))
		"relationship_divorce": result["success"] = RelationshipNpcManager.divorce_characters(int(plan["primary_id"]), int(plan["target_id"]))
		"accept_job_offer":
			result["success"] = CareerManager.accept_job_offer(character_id)
			var character := CharacterManager.get_character_by_id(character_id)
			var job_id_value = character.get("job_id", null)
			var company_id_value = character.get("company_id", null)
			var job_id := 0 if job_id_value == null else int(job_id_value)
			var company_id := "" if company_id_value == null else String(company_id_value)
			result.merge({"target_character_id": character_id, "job_id": job_id, "company_id": company_id, "salary": int(character.get("salary", 0)), "job_name": String(CareerManager.get_job_by_id(job_id).get("job_name", "")), "company_name": String(CareerManager.get_company_by_id(company_id).get("company_name", ""))}, true)
		"reject_job_offer":
			var offer := CareerManager.get_active_job_offer(character_id)
			var job_id := int(offer.get("job_id", 0))
			var company_id := String(offer.get("company_id", ""))
			result["success"] = CareerManager.reject_job_offer(character_id)
			result.merge({"target_character_id": character_id, "job_id": job_id, "company_id": company_id, "salary": int(offer.get("salary", 0)), "job_name": String(CareerManager.get_job_by_id(job_id).get("job_name", "")), "company_name": String(CareerManager.get_company_by_id(company_id).get("company_name", ""))}, true)
		"job_remove":
			var character := CharacterManager.get_character_by_id(character_id)
			var previous_job_id_value = character.get("job_id", null)
			var previous_company_id_value = character.get("company_id", null)
			var previous_job_id := 0 if previous_job_id_value == null else int(previous_job_id_value)
			var previous_company_id := "" if previous_company_id_value == null else String(previous_company_id_value)
			var previous_salary := int(character.get("salary", 0))
			result["success"] = CareerManager.remove_external_job(character_id)
			result.merge({"target_character_id": character_id, "previous_job_id": previous_job_id, "previous_company_id": previous_company_id, "previous_salary": previous_salary, "job_name": String(CareerManager.get_job_by_id(previous_job_id).get("job_name", "")), "company_name": String(CareerManager.get_company_by_id(previous_company_id).get("company_name", ""))}, true)
		"salary_increase":
			var character := CharacterManager.get_character_by_id(character_id)
			var before := int(character.get("salary", 0))
			var job_id_value = character.get("job_id", null)
			var company_id_value = character.get("company_id", null)
			var job_id := 0 if job_id_value == null else int(job_id_value)
			var company_id := "" if company_id_value == null else String(company_id_value)
			result["success"] = CareerManager.increase_external_salary(character_id, int(effect.get("amount", 0)))
			result.merge({"target_character_id": character_id, "job_id": job_id, "company_id": company_id, "job_name": String(CareerManager.get_job_by_id(job_id).get("job_name", "")), "company_name": String(CareerManager.get_company_by_id(company_id).get("company_name", "")), "before": before, "after": int(character.get("salary", before)), "requested_amount": int(effect.get("amount", 0)), "applied_amount": int(character.get("salary", before)) - before}, true)
		"education_enroll": result["success"] = EducationManager.enroll_character_in_school(character_id, int(plan["school_id"]))
		"add_item":
			var instance := ItemManager.create_item_instance(String(effect.get("item_id", "")))
			result.merge({"success": not instance.is_empty(), "target_character_id": character_id, "item_id": String(effect.get("item_id", "")), "instance_id": String(instance.get("instance_id", ""))}, true)
			created_items[String(plan.get("created_item_key", ""))] = instance
		"equip_item":
			var definition := ItemManager.get_item_definition(String(effect.get("item_id", "")))
			result["success"] = ItemManager.equip_item(character_id, String(plan["instance_id"]), String(definition.get("slot", "")))
			result.merge({"target_character_id": character_id, "item_id": String(effect.get("item_id", "")), "instance_id": String(plan["instance_id"])})
		"unequip_item":
			var definition := ItemManager.get_item_definition(String(effect.get("item_id", "")))
			result["success"] = ItemManager.unequip_item(character_id, String(definition.get("slot", "")), String(plan["instance_id"]))
			result.merge({"target_character_id": character_id, "item_id": String(effect.get("item_id", "")), "instance_id": String(plan["instance_id"])})
		"remove_item":
			if bool(plan.get("unequip_first", false)):
				ItemManager.unequip_item(character_id, String(plan.get("slot", "")), String(plan["instance_id"]))
			result["success"] = ItemManager.remove_item_instance(String(plan["instance_id"]))
			result.merge({"target_character_id": character_id, "item_id": String(effect.get("item_id", "")), "instance_id": String(plan["instance_id"])})
		"remove_from_house": result["success"] = HouseManager.remove_character_from_house(character_id)
		"business_upgrade": result["success"] = BusinessManager.upgrade_business(String(plan["business_id"]))
		"queue_event":
			var queued := EventManager.activate_chain(String(effect.get("event_id", "")), _inherited_participants(effect, plan), _inherited_context(effect, plan), source_instance_id)
			result["success"] = bool(queued.get("queued", false))
			var queued_instance = queued.get("instance", null)
			result["queued_instance_id"] = queued_instance.instance_id if queued_instance is EventInstance else ""
		"schedule_event":
			var delay: Dictionary = effect.get("delay", {})
			var scheduled := EventManager.schedule_event_after(String(effect.get("event_id", "")), String(delay.get("unit", "")), int(delay.get("value", 0)), EventManager.active_event.participants if bool(effect.get("inherit_context", true)) else {}, EventManager.active_event.context if bool(effect.get("inherit_context", true)) else {}, source_instance_id)
			result["success"] = not scheduled.is_empty()
			result["scheduled_event_id"] = String(scheduled.get("scheduled_event_id", ""))
		"cancel_scheduled_event": result["success"] = _cancel_scheduled(effect)
	result["display"] = _display(effect, result)
	return result


func _plan_item(effect_type: String, character_id: int, item_id: String, reserved: Dictionary) -> Dictionary:
	var candidates: Array = []
	var target_equipped: Array = []
	for value in ItemManager.family_inventory:
		if typeof(value) != TYPE_DICTIONARY or String(value.get("item_id", "")) != item_id:
			continue
		var instance: Dictionary = value
		var instance_id := String(instance.get("instance_id", ""))
		if reserved.has(instance_id):
			continue
		var owner := ItemManager.get_item_equipped_owner(instance_id)
		if owner == character_id:
			target_equipped.append(instance.duplicate(true))
		elif owner <= 0:
			candidates.append(instance.duplicate(true))
	if effect_type in ["unequip_item"]:
		candidates = target_equipped
	elif effect_type == "remove_item" and not target_equipped.is_empty():
		candidates = target_equipped
	elif effect_type == "equip_item":
		candidates.append_array(target_equipped)
	if candidates.is_empty():
		return {"valid": false}
	candidates.sort_custom(Callable(self, "_item_before"))
	var selected: Dictionary = candidates[0]
	var definition := ItemManager.get_item_definition(item_id)
	return {"valid": true, "instance_id": String(selected.get("instance_id", "")), "slot": String(definition.get("slot", "")), "unequip_first": effect_type == "remove_item" and ItemManager.get_item_equipped_owner(String(selected.get("instance_id", ""))) == character_id}


func _item_before(left: Dictionary, right: Dictionary) -> bool:
	var left_expiry := String(left.get("expiration_date", ""))
	var right_expiry := String(right.get("expiration_date", ""))
	if left_expiry.is_empty() != right_expiry.is_empty(): return not left_expiry.is_empty()
	if left_expiry != right_expiry: return left_expiry < right_expiry
	var left_purchase := String(left.get("purchase_date", ""))
	var right_purchase := String(right.get("purchase_date", ""))
	if left_purchase != right_purchase: return left_purchase < right_purchase
	return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))


func _exclusive_mutation_key(plan: Dictionary) -> String:
	var effect_type := String(plan.get("type", ""))
	match effect_type:
		"relationship_status_set":
			return "relationship_status:%d" % int(plan.get("character_id", 0))
		"relationship_marry", "relationship_divorce":
			var ids := [int(plan.get("primary_id", 0)), int(plan.get("target_id", 0))]
			ids.sort()
			return "relationship:%d:%d" % [ids[0], ids[1]]
		"accept_job_offer", "reject_job_offer", "job_remove", "salary_increase":
			return "career:%d" % int(plan.get("character_id", 0))
		"education_enroll": return "education:%d" % int(plan.get("character_id", 0))
		"remove_from_house": return "house:%d" % int(plan.get("character_id", 0))
		"business_upgrade": return "business:%s" % String(plan.get("business_id", ""))
		"queue_event": return "queue:%s" % String(plan.get("effect", {}).get("event_id", ""))
		"cancel_scheduled_event":
			var effect: Dictionary = plan.get("effect", {})
			return "cancel:%s:%s" % [String(effect.get("scheduled_event_id", "")), String(effect.get("event_id", ""))]
	return ""


func _display(effect: Dictionary, result: Dictionary) -> Dictionary:
	var feedback = effect.get("feedback", {})
	if typeof(feedback) == TYPE_DICTIONARY and String(feedback.get("mode", "auto")) == "custom":
		return {"mode": "custom", "text": String(feedback.get("text", "")), "icon_path": feedback.get("icon_path", null)}
	var text := String(effect.get("type", "")).replace("_", " ").capitalize()
	match String(effect.get("type", "")):
		"relationship_status_set": text = "Relationship updated."
		"accept_job_offer": text = "Accepted %s at %s." % [String(result.get("job_name", "a job")), String(result.get("company_name", "a company"))]
		"reject_job_offer": text = "Rejected %s at %s." % [String(result.get("job_name", "a job")), String(result.get("company_name", "a company"))]
		"job_remove": text = "Left %s at %s." % [String(result.get("job_name", "a job")), String(result.get("company_name", "a company"))]
		"salary_increase": text = "Salary at %s changed by %s%0.0f." % [String(result.get("company_name", "the company")), "+" if float(result.get("applied_amount", 0)) >= 0.0 else "", float(result.get("applied_amount", 0))]
		_:
			if result.has("applied_amount"):
				text = "%s %s%0.0f" % [text, "+" if float(result["applied_amount"]) >= 0.0 else "", float(result["applied_amount"])]
	return {"mode": "auto", "text": text, "icon_path": null}


func _character_id(effect: Dictionary, key: String, participants: Dictionary) -> int:
	var value = participants.get(String(effect.get(key, "")), null)
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] and not CharacterManager.get_character_by_id(int(value)).is_empty() else 0


func _string_target(effect: Dictionary, key: String, participants: Dictionary, context: Dictionary) -> String:
	var value = participants.get(String(effect.get(key, "")), null)
	if typeof(value) == TYPE_STRING:
		return String(value)
	return String(context.get("business_instance_id", ""))


func _has_scheduled_target(effect: Dictionary) -> bool:
	for record in EventManager.scheduled_events:
		if String(record.get("status", "")) != "scheduled": continue
		if effect.has("scheduled_event_id") and String(record.get("scheduled_event_id", "")) == String(effect.get("scheduled_event_id", "")): return true
		if effect.has("event_id") and String(record.get("event_id", "")) == String(effect.get("event_id", "")): return true
	return false


func _cancel_scheduled(effect: Dictionary) -> bool:
	if effect.has("scheduled_event_id"):
		return EventManager.cancel_scheduled_event(String(effect.get("scheduled_event_id", "")))
	for record in EventManager.scheduled_events:
		if String(record.get("status", "")) == "scheduled" and String(record.get("event_id", "")) == String(effect.get("event_id", "")):
			return EventManager.cancel_scheduled_event(String(record.get("scheduled_event_id", "")))
	return false


func _inherited_participants(effect: Dictionary, _plan: Dictionary) -> Dictionary:
	return EventManager.active_event.participants.duplicate(true) if bool(effect.get("inherit_context", true)) and EventManager.active_event != null else {}


func _inherited_context(effect: Dictionary, _plan: Dictionary) -> Dictionary:
	return EventManager.active_event.context.duplicate(true) if bool(effect.get("inherit_context", true)) and EventManager.active_event != null else {}


func _invalid(index: int, code: String, message: String) -> Dictionary:
	return {"valid": false, "failure": _failure(index, code, message)}


func _failure(index: int, code: String, message: String) -> Dictionary:
	return {"success": false, "effect_index": index, "code": code, "message": message}
