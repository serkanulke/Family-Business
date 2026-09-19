extends Node


var passed := 0
var failed := 0

var saved_characters: Array = []
var saved_next_character_id := 1
var saved_house_state: Dictionary = {}
var saved_date: Dictionary = {}
var saved_education_state: Dictionary = {}
var born_occurrences: Array[Dictionary] = []


func _ready() -> void:
	saved_characters = CharacterManager.characters.duplicate(true)
	saved_next_character_id = CharacterManager.next_character_id
	saved_house_state = HouseManager.create_save_state()
	saved_date = {
		"year": TimeManager.current_year,
		"month": TimeManager.current_month,
		"day": TimeManager.current_day,
		"paused": TimeManager.is_paused
	}
	saved_education_state = {
		"queue": EducationManager.education_event_queue.duplicate(true),
		"current": EducationManager.current_education_event.duplicate(true),
		"active": EducationManager.is_education_event_active,
		"pause_active": EducationManager.is_education_pause_active,
		"resume_after": EducationManager.should_resume_time_after_education_events
	}

	CharacterManager.character_born.connect(
		_on_character_born
	)

	_test_system_name_and_gender_generation()
	_test_biological_eligibility_boundaries()
	_test_unhoused_and_full_house_rejection()
	_test_event_requirement_and_creation_effect()
	_test_newborn_education_birthday_pipeline()

	CharacterManager.character_born.disconnect(
		_on_character_born
	)
	_restore_state()

	print("========================================")
	print("Birth backend tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_system_name_and_gender_generation() -> void:
	var names_data := _load_names_data()
	var male_names: Array = names_data.get(
		"first_names",
		{}
	).get(
		"male",
		{}
	).get(
		"english",
		[]
	)
	var female_names: Array = names_data.get(
		"first_names",
		{}
	).get(
		"female",
		{}
	).get(
		"english",
		[]
	)

	seed(19091985)
	var first_gender_sequence: Array[String] = []
	for _index in 8:
		first_gender_sequence.append(
			CharacterManager.generate_system_newborn_gender()
		)

	seed(19091985)
	var second_gender_sequence: Array[String] = []
	for _index in 8:
		second_gender_sequence.append(
			CharacterManager.generate_system_newborn_gender()
		)

	var valid_genders := true
	for gender in first_gender_sequence:
		if gender not in ["male", "female"]:
			valid_genders = false

	_assert(
		first_gender_sequence == second_gender_sequence
		and valid_genders
		and "male" in first_gender_sequence
		and "female" in first_gender_sequence,
		"Newborn gender generation is deterministic under a fixed seed and always canonical"
	)

	seed(101)
	var male_name := CharacterManager.generate_system_newborn_first_name(
		"male"
	)
	seed(202)
	var female_name := CharacterManager.generate_system_newborn_first_name(
		"female"
	)
	_assert(
		male_name in male_names
		and female_name in female_names,
		"System newborn names come from the matching English gender buckets"
	)


func _test_biological_eligibility_boundaries() -> void:
	var age_49 := _setup_couple(
		49,
		2,
		true
	)
	_assert(
		RelationshipNpcManager.are_married_partners(
			age_49["carrier"],
			age_49["spouse"]
		)
		and RelationshipNpcManager.can_have_biological_child(
			age_49["carrier"]
		)
		and RelationshipNpcManager.can_use_biological_conception(
			age_49["carrier"],
			age_49["spouse"]
		)
		and bool(
			CharacterManager.get_system_biological_child_availability(
				1,
				2
			).get(
				"available",
				false
			)
		),
		"Married male/female parents with a 49-year-old carrier and one resident slot are eligible"
	)

	var age_50 := _setup_couple(
		50,
		2,
		true
	)
	_assert(
		not RelationshipNpcManager.can_have_biological_child(
			age_50["carrier"]
		)
		and not RelationshipNpcManager.can_use_biological_conception(
			age_50["carrier"],
			age_50["spouse"]
		)
		and not bool(
			CharacterManager.get_system_biological_child_availability(
				1,
				2
			).get(
				"available",
				true
			)
		),
		"A 50-year-old carrier cannot use the normal biological-child route"
	)


func _test_unhoused_and_full_house_rejection() -> void:
	_setup_couple(
		30,
		2,
		false
	)
	HouseManager.remove_character_from_house(
		1
	)
	var unhoused := CharacterManager.get_system_biological_child_availability(
		1,
		2
	)
	_assert(
		not bool(unhoused.get("available", true))
		and String(unhoused.get("code", "")) == "carrier_unhoused",
		"An Unhoused carrier cannot start the biological-child route"
	)

	_setup_couple(
		30,
		1,
		false
	)
	var before_count := CharacterManager.characters.size()
	var full := CharacterManager.get_system_biological_child_availability(
		1,
		2
	)
	var blocked_child := CharacterManager.create_system_generated_biological_child(
		1,
		2
	)
	_assert(
		not bool(full.get("available", true))
		and String(full.get("code", "")) == "house_resident_capacity_unavailable"
		and blocked_child.is_empty()
		and CharacterManager.characters.size() == before_count
		and CharacterManager.get_character_by_id(1).get("children_ids", []).is_empty()
		and CharacterManager.get_character_by_id(2).get("children_ids", []).is_empty()
		and born_occurrences.is_empty(),
		"A full House blocks creation without mutating Characters, parent links, or birth signals"
	)

	var provider := EventRuntimeQueryProvider.new()
	var evaluator := RequirementEvaluator.new(
		provider
	)
	var requirement_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "house_has_resident_capacity",
					"target": "carrier",
					"operator": "==",
					"value": true
				}
			]
		},
		{"carrier": 1},
		{}
	)
	var reasons: Array = requirement_result.get(
		"failure_reasons",
		[]
	)
	_assert(
		not bool(requirement_result.get("eligible", true))
		and not reasons.is_empty()
		and "House" in String(reasons[0].get("message", "")),
		"House capacity requirement returns a readable player-facing failure reason"
	)


func _test_event_requirement_and_creation_effect() -> void:
	var setup := _setup_couple(
		30,
		2,
		true
	)
	var carrier: Dictionary = setup["carrier"]
	var spouse: Dictionary = setup["spouse"]
	var house_instance_id := String(setup["house_instance_id"])

	_assert(
		HouseManager.can_accept_additional_resident(
			house_instance_id
		),
		"A House with exactly one free generic resident slot accepts a newborn"
	)

	var provider := EventRuntimeQueryProvider.new()
	var evaluator := RequirementEvaluator.new(
		provider
	)
	var requirement_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "house_has_resident_capacity",
					"target": "carrier",
					"operator": "==",
					"value": true
				}
			]
		},
		{"carrier": 1},
		{}
	)
	_assert(
		bool(requirement_result.get("eligible", false)),
		"Future Event requirements read live HouseManager resident capacity"
	)

	var resolver := EventEffectResolver.new(
		EventDataRegistry.new()
	)
	var effects: Array = [
		{
			"type": "create_biological_child",
			"carrier": "carrier",
			"spouse": "spouse"
		}
	]
	var preflight := resolver.preflight(
		effects,
		{
			"carrier": 1,
			"spouse": 2
		},
		{},
		GameManager.family_money,
		GameManager.diamonds
	)
	var applied := resolver.apply(
		preflight.get("plans", []),
		"birth_backend_test"
	)
	var effect_results: Array = applied.get(
		"effect_results",
		[]
	)
	var effect_result: Dictionary = (
		effect_results[0]
		if not effect_results.is_empty()
		else {}
	)
	var child := CharacterManager.get_character_by_id(
		int(effect_result.get("target_character_id", 0))
	)
	var names_data := _load_names_data()
	var gender_names: Array = names_data.get(
		"first_names",
		{}
	).get(
		String(child.get("gender", "")),
		{}
	).get(
		"english",
		[]
	)
	var child_id := int(
		child.get(
			"character_id",
			0
		)
	)
	var carrier_children: Array = carrier.get(
		"children_ids",
		[]
	)
	var spouse_children: Array = spouse.get(
		"children_ids",
		[]
	)

	_assert(
		bool(preflight.get("valid", false))
		and bool(applied.get("success", false))
		and not child.is_empty(),
		"Normal biological newborn is created through the narrow Event effect and CharacterManager"
	)
	_assert(
		String(child.get("gender", "")) in ["male", "female"]
		and String(child.get("first_name", "")) in gender_names,
		"Created newborn has a system gender and a matching canonical English first name"
	)
	_assert(
		child.get("parent_ids", []) == [1, 2]
		and carrier_children.count(child_id) == 1
		and spouse_children.count(child_id) == 1,
		"Newborn has two parent_ids and appears exactly once in both parents' children_ids"
	)
	_assert(
		String(
			HouseManager.get_character_assignment(
				child_id
			).get(
				"house_instance_id",
				""
			)
		) == house_instance_id
		and String(
			HouseManager.get_character_assignment(
				child_id
			).get(
				"assignment_type",
				""
			)
		) == "resident",
		"Successful newborn is assigned to the mother's House as a generic resident"
	)
	_assert(
		born_occurrences.size() == 1
		and int(born_occurrences[0].get("character_id", 0)) == child_id
		and int(born_occurrences[0].get("parent_one_id", 0)) == 1
		and int(born_occurrences[0].get("parent_two_id", 0)) == 2,
		"character_born still fires exactly once with both parent IDs"
	)
	_assert(
		String(child.get("life_stage", "")) == "baby"
		and child.get("school_id", 1) == null
		and String(child.get("education_status", "")) == "none"
		and child.get("job_id", 1) == null
		and int(child.get("salary", -1)) == 0
		and not bool(child.get("is_adopted", true)),
		"Existing biological newborn defaults remain intact"
	)


func _test_newborn_education_birthday_pipeline() -> void:
	var child_id := int(
		born_occurrences[0].get(
			"character_id",
			0
		)
	) if not born_occurrences.is_empty() else 0
	var child := CharacterManager.get_character_by_id(
		child_id
	)
	_reset_education_state()
	TimeManager.current_year = 1991
	TimeManager.current_month = 1
	TimeManager.current_day = 25
	EducationManager.check_birthday_education_events()

	_assert(
		not child.is_empty()
		and CharacterManager.get_character_age(child) == 6
		and EducationManager.is_current_education_event(
			child_id,
			"school_enrollment",
			"primary_school"
		),
		"A normally created newborn enters the existing Primary School flow on the sixth birthday"
	)


func _setup_couple(
	carrier_age: int,
	house_level: int,
	leave_one_resident_slot: bool
) -> Dictionary:
	_set_test_date()
	_reset_education_state()
	EventManager.reset_runtime_state()
	born_occurrences.clear()

	var carrier := _character(
		1,
		"female",
		carrier_age
	)
	var spouse := _character(
		2,
		"male",
		31
	)
	carrier["partner_id"] = 2
	spouse["partner_id"] = 1
	CharacterManager.characters = [
		carrier,
		spouse
	]

	var resident_ids: Array = [2]
	if leave_one_resident_slot:
		for character_id in range(
			3,
			7
		):
			CharacterManager.characters.append(
				_character(
					character_id,
					"female",
					25
				)
			)
			resident_ids.append(
				character_id
			)

	CharacterManager.next_character_id = (
		7
		if leave_one_resident_slot
		else 3
	)

	var houses: Array = []
	var house_instance_id := ""
	if house_level > 0:
		house_instance_id = "house_birth_test"
		houses = [
			{
				"house_instance_id": house_instance_id,
				"house_definition_id": "family_house",
				"property_id": "house_birth_test_property",
				"level": house_level,
				"role_assignments": {
					"head_of_household": 1,
					"cook": null,
					"housekeeper": null,
					"caregiver": null
				},
				"resident_character_ids": resident_ids
			}
		]

	HouseManager.restore_save_state(
		{
			"houses": houses,
			"next_house_instance_number": 2,
			"last_unhoused_penalty_date": ""
		}
	)

	return {
		"carrier": carrier,
		"spouse": spouse,
		"house_instance_id": house_instance_id
	}


func _character(
	character_id: int,
	gender: String,
	age: int
) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": "family",
		"first_name": "Parent %d" % character_id,
		"gender": gender,
		"avatar_theme": "classic",
		"genetics": {"skin_tone": "light"},
		"portrait_variant_id": "",
		"portrait_path": "res://Resources/Characters/default_avatar.png",
		"is_alive": true,
		"birth_date": "%04d-01-25" % (1985 - age),
		"death_date": null,
		"life_stage": "adult",
		"is_player_family": true,
		"parent_ids": [],
		"is_adopted": false,
		"partner_id": null,
		"children_ids": [],
		"school_id": null,
		"major_id": null,
		"education_status": "graduated",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,
		"is_retired": false,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"last_salary": 0,
		"pension": 0,
		"unemployment_start_date": null,
		"job_offer_cooldown_until": null,
		"flag_ids": [],
		"event_log": [],
		"health": 50,
		"happiness": 50,
		"logic": 50,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50
	}


func _load_names_data() -> Dictionary:
	var file := FileAccess.open(
		CharacterManager.NAMES_DATA_PATH,
		FileAccess.READ
	)
	if file == null:
		return {}
	var data = JSON.parse_string(
		file.get_as_text()
	)
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _set_test_date() -> void:
	TimeManager.current_year = 1985
	TimeManager.current_month = 1
	TimeManager.current_day = 25
	TimeManager.is_paused = false


func _reset_education_state() -> void:
	EducationManager.education_event_queue.clear()
	EducationManager.current_education_event = {}
	EducationManager.is_education_event_active = false
	EducationManager.is_education_pause_active = false
	EducationManager.should_resume_time_after_education_events = false


func _restore_state() -> void:
	CharacterManager.characters = saved_characters
	CharacterManager.next_character_id = saved_next_character_id
	HouseManager.restore_save_state(
		saved_house_state
	)
	TimeManager.current_year = int(saved_date["year"])
	TimeManager.current_month = int(saved_date["month"])
	TimeManager.current_day = int(saved_date["day"])
	TimeManager.is_paused = bool(saved_date["paused"])
	EducationManager.education_event_queue = saved_education_state["queue"]
	EducationManager.current_education_event = saved_education_state["current"]
	EducationManager.is_education_event_active = bool(saved_education_state["active"])
	EducationManager.is_education_pause_active = bool(saved_education_state["pause_active"])
	EducationManager.should_resume_time_after_education_events = bool(saved_education_state["resume_after"])
	EventManager.reset_runtime_state()


func _on_character_born(
	character_id: int,
	parent_one_id: int,
	parent_two_id: int
) -> void:
	born_occurrences.append(
		{
			"character_id": character_id,
			"parent_one_id": parent_one_id,
			"parent_two_id": parent_two_id
		}
	)


func _assert(
	condition: bool,
	test_name: String
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
