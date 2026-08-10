extends RefCounted
class_name BusinessModalDataAdapter


static func build(business_instance_id: String) -> Dictionary:
	var business: Dictionary = BusinessManager.get_business_by_instance_id(business_instance_id)
	if business.is_empty():
		return {}

	var business_type_id := str(business.get("business_type_id", ""))
	if business_type_id.is_empty():
		return {}

	var business_type: Dictionary = BusinessManager.get_business_type_by_id(business_type_id)
	if business_type.is_empty():
		return {}

	var level := int(business.get("level", 1))
	var breakdown: Dictionary = BusinessManager.get_business_monthly_breakdown(business_instance_id)

	var data: Dictionary = {
		"business_instance_id": business_instance_id,
		"id": business_instance_id,
		"display_name": str(business_type.get("display_name", business_type_id.capitalize())).to_upper(),
		"level": level,
		"monthly_income": int(breakdown.get("gross_income", 0)),
		"monthly_expense": int(breakdown.get("fixed_expense", 0)),
		"net_profit": int(breakdown.get("net_profit", 0)),
		"image_path": BusinessManager.get_business_visual_path(
			business_type_id,
			str(business.get("visual_variant_id", "")),
			level
		),
		"icon_path": _get_business_icon_path(business_type_id),
		"slots": _build_slots(business_instance_id, business_type_id, business)
	}

	var next_upgrade := _build_next_upgrade(business_type_id, level)
	if not next_upgrade.is_empty():
		data["next_upgrade"] = next_upgrade

	return data


static func _build_slots(
	business_instance_id: String,
	business_type_id: String,
	business: Dictionary
) -> Array:
	var result: Array = []
	var slots_value = business.get("slots", [])
	if typeof(slots_value) != TYPE_ARRAY:
		return result

	for slot_value in slots_value:
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue

		var slot: Dictionary = slot_value
		var slot_id := str(slot.get("slot_id", ""))
		if slot_id.is_empty():
			continue

		var slot_definition: Dictionary = BusinessManager.get_slot_definition(
			business_type_id,
			slot_id
		)
		if slot_definition.is_empty():
			continue

		var row: Dictionary = {
			"slot_id": slot_id,
			"role_name": str(slot_definition.get("role_name", slot_id)),
			"required_stats": _format_required_stats(slot_definition),
			"assigned_character_id": slot.get("assigned_character_id", null),
			"assigned_npc_id": slot.get("assigned_npc_id", null),
			"potential_income": int(slot_definition.get("base_gross_contribution", 0)),
			"income": BusinessManager.get_business_slot_gross(business_instance_id, slot_id)
		}

		_add_worker_presentation(row, slot, slot_definition)
		result.append(row)

	return result


static func _format_required_stats(slot_definition: Dictionary) -> Array:
	var result: Array = []
	var stats_value = slot_definition.get("required_stats", {})
	if typeof(stats_value) != TYPE_DICTIONARY:
		return result

	var stats: Dictionary = stats_value
	for stat_name_value in stats.keys():
		result.append(str(stat_name_value).capitalize())

	return result


static func _add_worker_presentation(
	row: Dictionary,
	slot: Dictionary,
	slot_definition: Dictionary
) -> void:
	var character_id_value = slot.get("assigned_character_id", null)
	if character_id_value != null:
		var character: Dictionary = CareerManager.get_character_by_id(int(character_id_value))
		if character.is_empty():
			return

		row["worker_name"] = _full_name(character)
		row["portrait_path"] = CharacterManager.get_avatar_path(character)
		var character_performance: Dictionary = BusinessManager.get_worker_slot_performance(
			character,
			slot_definition
		)
		row["performance_grade"] = str(character_performance.get("tier", ""))
		return

	var npc_id_value = slot.get("assigned_npc_id", null)
	if npc_id_value == null:
		return

	var npc_id := str(npc_id_value)
	if npc_id.is_empty():
		return

	var npc_manager := _get_npc_manager()
	if npc_manager == null:
		return

	var worker: Dictionary = npc_manager.get_worker_npc_by_id(npc_id)
	if worker.is_empty():
		return

	row["worker_name"] = _full_name(worker)
	row["portrait_path"] = str(worker.get("portrait_path", ""))
	var npc_performance: Dictionary = BusinessManager.get_worker_slot_performance(
		worker,
		slot_definition
	)
	row["performance_grade"] = str(npc_performance.get("tier", ""))


static func _get_npc_manager() -> Node:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null

	# Current project files have used both spellings. Prefer the canonical NPCManager.
	var manager := scene_tree.root.get_node_or_null("NPCManager")
	if manager == null:
		manager = scene_tree.root.get_node_or_null("NpcManager")
	return manager


static func _full_name(person: Dictionary) -> String:
	return (
		str(person.get("first_name", ""))
		+ " "
		+ str(person.get("last_name", ""))
	).strip_edges()


static func _build_next_upgrade(business_type_id: String, current_level: int) -> Dictionary:
	var business_type: Dictionary = BusinessManager.get_business_type_by_id(business_type_id)
	if business_type.is_empty():
		return {}

	var max_level := int(business_type.get("max_level", 1))
	if current_level >= max_level:
		return {}

	var next_level := current_level + 1
	var current_definition: Dictionary = BusinessManager.get_level_definition(
		business_type_id,
		current_level
	)
	var next_definition: Dictionary = BusinessManager.get_level_definition(
		business_type_id,
		next_level
	)
	if next_definition.is_empty():
		return {}

	var current_slots: Array = []
	var next_slots: Array = []
	var current_slots_value = current_definition.get("slot_ids", [])
	var next_slots_value = next_definition.get("slot_ids", [])
	if typeof(current_slots_value) == TYPE_ARRAY:
		current_slots = current_slots_value
	if typeof(next_slots_value) == TYPE_ARRAY:
		next_slots = next_slots_value

	var unlocked_slot_names: Array[String] = []
	var added_potential_income := 0
	for slot_id_value in next_slots:
		if current_slots.has(slot_id_value):
			continue

		var slot_definition: Dictionary = BusinessManager.get_slot_definition(
			business_type_id,
			str(slot_id_value)
		)
		if slot_definition.is_empty():
			continue

		unlocked_slot_names.append(str(slot_definition.get("role_name", str(slot_id_value))))
		added_potential_income += int(slot_definition.get("base_gross_contribution", 0))

	var current_expense := BusinessManager.get_level_fixed_monthly_expense(
		business_type_id,
		current_level
	)
	var next_expense := int(next_definition.get("fixed_monthly_expense", 0))

	var slot_text := "+ New Slot"
	if unlocked_slot_names.size() == 1:
		slot_text = "+ New %s Slot" % unlocked_slot_names[0]
	elif unlocked_slot_names.size() > 1:
		slot_text = "+ %d New Staff Slots" % unlocked_slot_names.size()

	var level_name := str(next_definition.get(
		"display_name",
		next_definition.get("name", "")
	))

	return {
		"level": next_level,
		"name": level_name,
		"new_slot_text": slot_text,
		"potential_income": added_potential_income,
		"monthly_expense": maxi(next_expense - current_expense, 0),
		"cost": int(next_definition.get("cost", 0))
	}


static func _get_business_icon_path(business_type_id: String) -> String:
	if business_type_id == "hospital":
		return "res://Resources/Icons/hospital-sign.png"
	return "res://Resources/Icons/building_icon.svg"
