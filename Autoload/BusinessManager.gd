extends Node


signal family_business_slot_changed(
	business_instance_id: String,
	slot_id: String,
	character_id: int
)


const BUSINESS_DATA_PATH := "res://Resources/Json/Business.json"


var businesses: Array = []


func _ready() -> void:
	load_business_data()


func load_business_data() -> void:
	businesses = CharacterManager.load_json_array(
		BUSINESS_DATA_PATH,
		"businesses"
	)

	print(
		"Family businesses loaded: ",
		businesses.size()
	)


func get_business_by_instance_id(
	business_instance_id: String
) -> Dictionary:
	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value

		if String(
			business.get(
				"business_instance_id",
				""
			)
		) == business_instance_id:
			return business

	return {}


func get_slot(
	business_instance_id: String,
	slot_id: String
) -> Dictionary:
	var business := get_business_by_instance_id(
		business_instance_id
	)

	if business.is_empty():
		return {}

	for slot_value in business.get(
		"slots",
		[]
	):
		if typeof(slot_value) != TYPE_DICTIONARY:
			continue

		var slot: Dictionary = slot_value

		if String(
			slot.get(
				"slot_id",
				""
			)
		) == slot_id:
			return slot

	return {}


func get_character_assignment(
	character_id: int
) -> Dictionary:
	for business_value in businesses:
		if typeof(business_value) != TYPE_DICTIONARY:
			continue

		var business: Dictionary = business_value

		var business_instance_id := String(
			business.get(
				"business_instance_id",
				""
			)
		)

		for slot_value in business.get(
			"slots",
			[]
		):
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue

			var slot: Dictionary = slot_value

			var assigned_character_id = slot.get(
				"assigned_character_id",
				null
			)

			if assigned_character_id == null:
				continue

			if int(assigned_character_id) != character_id:
				continue

			return {
				"business_instance_id": business_instance_id,
				"slot_id": String(
					slot.get(
						"slot_id",
						""
					)
				)
			}

	return {}


func is_character_assigned(
	character_id: int
) -> bool:
	return not get_character_assignment(
		character_id
	).is_empty()


func can_assign_character(
	character_id: int
) -> bool:
	var character := CareerManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		return false

	if not bool(
		character.get(
			"is_alive",
			true
		)
	):
		return false

	if not bool(
		character.get(
			"is_player_family",
			false
		)
	):
		return false

	if bool(
		character.get(
			"is_retired",
			false
		)
	):
		return false

	if is_character_assigned(
		character_id
	):
		return false

	return true


func assign_character_to_slot(
	business_instance_id: String,
	slot_id: String,
	character_id: int
) -> bool:
	var slot := get_slot(
		business_instance_id,
		slot_id
	)

	if slot.is_empty():
		return false

	if slot.get(
		"assigned_character_id",
		null
	) != null:
		return false

	if not can_assign_character(
		character_id
	):
		return false

	var character := CareerManager.get_character_by_id(
		character_id
	)

	if character.is_empty():
		return false

	# Family-business assignment immediately ends
	# any existing external employment.
	character["job_id"] = null
	character["company_id"] = null
	character["salary"] = 0

	# A pending external offer cannot remain active after
	# the character enters a family-business slot.
	CareerManager.active_job_offers.erase(
		character_id
	)

	character[
		"unemployment_start_date"
	] = null

	character[
		"job_offer_cooldown_until"
	] = null

	slot["assigned_character_id"] = (
		character_id
	)

	family_business_slot_changed.emit(
		business_instance_id,
		slot_id,
		character_id
	)

	print(
		"FAMILY BUSINESS ASSIGNED | Character: ",
		character_id,
		" | Business: ",
		business_instance_id,
		" | Slot: ",
		slot_id
	)

	return true


func remove_character_from_slot(
	business_instance_id: String,
	slot_id: String
) -> bool:
	var slot := get_slot(
		business_instance_id,
		slot_id
	)

	if slot.is_empty():
		return false

	var character_id_value = slot.get(
		"assigned_character_id",
		null
	)

	if character_id_value == null:
		return false

	var character_id := int(
		character_id_value
	)

	slot["assigned_character_id"] = null

	var character := CareerManager.get_character_by_id(
		character_id
	)

	if not character.is_empty():
		character["job_id"] = null
		character["company_id"] = null
		character["salary"] = 0

		character[
			"unemployment_start_date"
		] = TimeManager.get_iso_date_string()

		character[
			"job_offer_cooldown_until"
		] = null

	family_business_slot_changed.emit(
		business_instance_id,
		slot_id,
		0
	)

	print(
		"FAMILY BUSINESS REMOVED | Character: ",
		character_id,
		" | Business: ",
		business_instance_id,
		" | Slot: ",
		slot_id,
		" | External offers enabled again"
	)

	return true


func remove_character_from_any_slot(
	character_id: int
) -> bool:
	var assignment := get_character_assignment(
		character_id
	)

	if assignment.is_empty():
		return false

	return remove_character_from_slot(
		String(
			assignment.get(
				"business_instance_id",
				""
			)
		),
		String(
			assignment.get(
				"slot_id",
				""
			)
		)
	)
