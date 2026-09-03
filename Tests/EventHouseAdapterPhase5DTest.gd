extends Node


var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_id := -1

var semantic_occurrences: Array[Dictionary] = []


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	SaveManager.current_save_id = -1

	_connect_capture_signals()

	_test_assignment_mutations_stay_domain_only()
	_test_divorce_death_and_bootstrap_cleanup()
	_test_upgrade_and_live_requirements()
	_test_save_load_without_house_semantic_replay()

	_disconnect_capture_signals()
	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.current_save_id = original_save_id

	print("========================================")
	print("Event Phase 5D House adapter tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_assignment_mutations_stay_domain_only() -> void:
	var head := _character(1, 60)
	var resident := _character(2, 70)
	var replacement := _character(3, 80)
	_setup_world(
		[head, resident, replacement],
		[
			_system_event("phase5d_assignment_should_not_fire", "house_assignment_changed", true),
			_system_event("phase5d_unhoused_should_not_fire", "character_became_unhoused", true)
		],
		_default_houses(1)
	)

	_assert(
		HouseManager.assign_character_as_resident("house_0001", 2),
		"Resident assignment remains a canonical HouseManager mutation"
	)
	_assert(
		HouseManager.get_character_assignment(2).get("assignment_type", "") == "resident",
		"Resident assignment updates authoritative House state"
	)
	_assert(
		_semantic("house_assignment_changed").is_empty()
		and _semantic("character_became_unhoused").is_empty()
		and EventManager.active_event == null,
		"House assignment does not create Event-only assignment or Unhoused semantics"
	)

	_assert(
		HouseManager.assign_character_to_role("house_0001", "cook", 2),
		"Resident-to-role transition remains HouseManager-owned"
	)
	_assert(
		String(HouseManager.get_character_assignment(2).get("role_id", "")) == "cook"
		and _semantic("house_assignment_changed").is_empty()
		and _semantic("character_became_unhoused").is_empty(),
		"Resident-to-role transition stays outside Event semantic dispatch"
	)

	_assert(
		HouseManager.assign_character_to_role("house_0001", "cook", 3),
		"Occupied House role replacement remains supported"
	)
	_assert(
		HouseManager.get_role_character_id("house_0001", "cook") == 3
		and HouseManager.is_character_unhoused(2),
		"Role replacement preserves canonical final House state"
	)
	_assert(
		_semantic("house_assignment_changed").is_empty()
		and _semantic("character_became_unhoused").is_empty(),
		"Displaced occupant does not create an Event-only Unhoused transition"
	)

	_assert(
		HouseManager.remove_character_from_house(3),
		"Explicit House removal remains supported"
	)
	_assert(
		HouseManager.is_character_unhoused(3)
		and _semantic("house_assignment_changed").is_empty()
		and _semantic("character_became_unhoused").is_empty()
		and EventManager.active_event == null,
		"Explicit House removal changes domain state without fabricating an Event occurrence"
	)


func _test_divorce_death_and_bootstrap_cleanup() -> void:
	var family_character := _character(1, 60)
	family_character.partner_id = 2
	var spouse := _character(2, 60)
	spouse.character_type = "relationship_npc"
	spouse.relationship_status = "married"
	spouse.partner_id = 1
	spouse.linked_character_id = null

	var houses := _default_houses(1)
	houses[0]["resident_character_ids"] = [2]
	_setup_world(
		[family_character, spouse],
		[
			_system_event("phase5d_assignment_should_not_fire", "house_assignment_changed", true),
			_system_event("phase5d_unhoused_should_not_fire", "character_became_unhoused", true)
		],
		houses
	)

	_assert(
		RelationshipNpcManager.divorce_characters(1, 2),
		"Canonical divorce succeeds with a housed Relationship spouse"
	)
	_assert(
		HouseManager.get_character_assignment(2).is_empty()
		and not bool(spouse.get("is_player_family", true)),
		"Divorce still removes the departing spouse from the House"
	)
	_assert(
		_house_semantics().is_empty()
		and EventManager.active_event == null,
		"Divorce House cleanup creates no Event-only House transition"
	)

	var living := _character(1, 60)
	var doomed := _character(2, 60)
	houses = _default_houses(1)
	houses[0]["resident_character_ids"] = [2]
	_setup_world(
		[living, doomed],
		[
			_system_event("phase5d_assignment_should_not_fire", "house_assignment_changed", true),
			_system_event("phase5d_unhoused_should_not_fire", "character_became_unhoused", true)
		],
		houses
	)

	CharacterManager.kill_character(doomed)
	_assert(
		not bool(doomed.get("is_alive", true))
		and HouseManager.get_character_assignment(2).is_empty(),
		"Existing death cleanup still removes the dead Character from House"
	)
	_assert(
		_house_semantics().is_empty(),
		"Death cleanup creates no House assignment or Unhoused Event semantic"
	)

	var starter := _character(1, 60)
	_setup_world(
		[starter],
		[
			_system_event("phase5d_assignment_should_not_fire", "house_assignment_changed", true),
			_system_event("phase5d_unhoused_should_not_fire", "character_became_unhoused", true)
		],
		[]
	)
	HouseManager._on_new_game_started(starter)
	_assert(
		HouseManager.get_role_character_id("house_0001", "head_of_household") == 1,
		"Starting House bootstrap still assigns the starting Character as Head"
	)
	_assert(
		_house_semantics().is_empty(),
		"Starting House bootstrap creates no gameplay House semantic occurrence"
	)


func _test_upgrade_and_live_requirements() -> void:
	var head := _character(1, 60, [1002])
	var replacement := _character(2, 80)
	_setup_world(
		[head, replacement],
		[
			_system_event("phase5d_upgrade", "house_upgraded", false)
		],
		_default_houses(1, 1)
	)

	GameManager.family_money = 1000000
	_assert(
		HouseManager.upgrade_house("house_0001"),
		"House upgrade remains owned by HouseManager"
	)
	_assert(
		int(HouseManager.get_house_by_instance_id("house_0001").get("level", 0)) == 2,
		"Canonical House level mutation remains unchanged"
	)
	_assert(
		_semantic("house_upgraded").size() == 1,
		"House upgrade still dispatches the canonical house_upgraded semantic exactly once"
	)
	_cancel_all_events()
	_clear_captures()

	var provider := EventRuntimeQueryProvider.new()
	var evaluator := RequirementEvaluator.new(provider)
	var status_id := String(
		HouseManager.get_household_status("house_0001").get("status_id", "")
	)
	var status_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "household_status",
					"operator": "==",
					"value": status_id
				}
			]
		},
		{},
		{"house_instance_id": "house_0001"}
	)
	_assert(
		not status_id.is_empty()
		and bool(status_result.get("eligible", false)),
		"household_status Event requirement reads the live authoritative HouseManager result"
	)

	var perk_ids := HouseManager.get_active_household_perk_ids("house_0001")
	var perk_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "household_perk",
					"operator": "contains",
					"value": "artistic"
				}
			]
		},
		{},
		{"house_instance_id": "house_0001"}
	)
	_assert(
		"artistic" in perk_ids
		and bool(perk_result.get("eligible", false)),
		"household_perk Event requirement reads live canonical Head/Flag-derived Perks"
	)

	_assert(
		HouseManager.assign_character_to_role(
			"house_0001",
			"head_of_household",
			2
		),
		"Canonical Head replacement succeeds for live Perk reevaluation"
	)
	var perk_result_after := evaluator.evaluate(
		{
			"all": [
				{
					"type": "household_perk",
					"operator": "contains",
					"value": "artistic"
				}
			]
		},
		{},
		{"house_instance_id": "house_0001"}
	)
	_assert(
		HouseManager.get_active_household_perk_ids("house_0001").is_empty()
		and not bool(perk_result_after.get("eligible", true)),
		"Household Perk requirement updates live without stored duplicate Perk state"
	)
	_cancel_all_events()


func _test_save_load_without_house_semantic_replay() -> void:
	var head := _character(1, 60)
	var resident := _character(2, 60)
	_setup_world(
		[head, resident],
		[
			_system_event("phase5d_upgrade", "house_upgraded", false)
		],
		_default_houses(1)
	)

	HouseManager.assign_character_as_resident("house_0001", 2)
	_cancel_all_events()
	HouseManager.remove_character_from_house(2)
	_cancel_all_events()
	GameManager.family_money = 1000000
	HouseManager.upgrade_house("house_0001")
	var expected_level := int(
		HouseManager.get_house_by_instance_id("house_0001").get("level", 0)
	)
	var snapshot = JSON.parse_string(
		JSON.stringify(SaveManager.create_save_snapshot())
	)

	_clear_captures()
	HouseManager.houses = []
	EventManager.reset_runtime_state()
	var loaded := SaveManager.apply_save_snapshot(snapshot)

	_assert(
		loaded
		and HouseManager.is_character_unhoused(2)
		and int(
			HouseManager.get_house_by_instance_id("house_0001").get(
				"level",
				0
			)
		) == expected_level,
		"Save/load restores House, upgrade, and Unhoused domain state"
	)
	_assert(
		_house_semantics().is_empty(),
		"House restore emits no House semantic replay"
	)
	_assert(
		int(SaveManager.SAVE_VERSION) == 6,
		"Phase 5D leaves save schema version 6 unchanged"
	)
	_cancel_all_events()


func _setup_world(
	characters: Array,
	events: Array,
	houses: Array
) -> void:
	SaveManager.current_save_id = -1
	CharacterManager.characters = characters
	CharacterManager.next_character_id = 50
	RelationshipNpcManager.relationship_candidate_ids = []
	CareerManager.active_job_offers.clear()
	BusinessManager.businesses = []
	GameManager.family_money = 1000000
	GameManager.diamonds = 100
	TimeManager.current_year = 1985
	TimeManager.current_month = 1
	TimeManager.current_day = 25
	TimeManager.speed_multiplier = 1.0
	TimeManager.is_paused = true
	TimeManager.day_timer = 0.0

	HouseManager.restore_save_state(
		{
			"houses": houses,
			"next_house_instance_number": 3,
			"last_unhoused_penalty_date": ""
		}
	)
	_configure(events)
	_clear_captures()


func _default_houses(
	head_character_id: int,
	level: int = 2
) -> Array:
	return [
		{
			"house_instance_id": "house_0001",
			"house_definition_id": "family_house",
			"property_id": "house_01",
			"level": level,
			"role_assignments": {
				"head_of_household": head_character_id,
				"cook": null,
				"housekeeper": null,
				"caregiver": null
			},
			"resident_character_ids": []
		},
		{
			"house_instance_id": "house_0002",
			"house_definition_id": "family_house",
			"property_id": "house_02",
			"level": level,
			"role_assignments": {
				"head_of_household": null,
				"cook": null,
				"housekeeper": null,
				"caregiver": null
			},
			"resident_character_ids": []
		}
	]


func _configure(events: Array) -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_from_json_sources(
		{
			"household.json": JSON.stringify(
				{
					"schema_version": 1,
					"category": "household",
					"pools": [],
					"events": events
				}
			)
		}
	)
	_assert(
		loaded,
		"Phase 5D fixture registry validates",
		registry.get_diagnostic_text()
	)
	EventManager.configure_runtime(registry, null, 71)


func _system_event(
	event_id: String,
	semantic_event: String,
	with_primary: bool
) -> Dictionary:
	var participants: Dictionary = {}
	if with_primary:
		participants = {
			"primary": {
				"type": "character",
				"source": "trigger"
			}
		}
	return {
		"event_id": event_id,
		"category": "household",
		"domain": "house",
		"subtype": "phase5d_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 0,
		"exclusive_group": null,
		"trigger": {
			"type": "system",
			"event": semantic_event
		},
		"participants": participants,
		"requirements": {"all": []},
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {
			"blocking": false,
			"pause_game": false
		},
		"content": {
			"title": event_id,
			"description": "Phase 5D fixture"
		},
		"presentation": {
			"template": "standard_event"
		},
		"choices": [
			{
				"choice_id": "continue",
				"title": "Continue",
				"requirements": {"all": []},
				"resolution": {
					"mode": "deterministic",
					"effects": []
				}
			}
		]
	}


func _character(
	character_id: int,
	score: int = 60,
	flags: Array = []
) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": "family",
		"linked_character_id": null,
		"relationship_status": "",
		"first_name": "House",
		"last_name": "Adapter",
		"gender": "female",
		"birth_date": "1960-01-01",
		"death_date": null,
		"life_stage": "adult",
		"is_alive": true,
		"is_player_family": true,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"relationship_cooldown_until": null,
		"flag_ids": flags.duplicate(),
		"health": score,
		"happiness": 50,
		"logic": score,
		"attractiveness": score,
		"social": score,
		"confidence": score,
		"discipline": score,
		"creativity": score,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"school_id": null,
		"major_id": null,
		"education_status": "graduated",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,
		"unemployment_start_date": null,
		"job_offer_cooldown_until": null,
		"event_log": [],
		"is_retired": false,
		"last_salary": 0,
		"pension": 0,
		"avatar_theme": "default",
		"genetics": {"skin_tone": "light"},
		"portrait_variant_id": "",
		"portrait_path": "res://Resources/Characters/default_avatar.png"
	}


func _semantic(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(
			occurrence.get(
				"semantic_event",
				""
			)
		) == name:
			result.append(occurrence)
	return result


func _house_semantics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(
			occurrence.get(
				"semantic_event",
				""
			)
		) in [
			"house_assignment_changed",
			"character_became_unhoused",
			"house_upgraded"
		]:
			result.append(occurrence)
	return result


func _cancel_all_events() -> void:
	while EventManager.active_event != null:
		EventManager.cancel_active_event()


func _connect_capture_signals() -> void:
	EventManager.semantic_trigger_dispatched.connect(
		_on_semantic_trigger_dispatched
	)


func _disconnect_capture_signals() -> void:
	EventManager.semantic_trigger_dispatched.disconnect(
		_on_semantic_trigger_dispatched
	)


func _on_semantic_trigger_dispatched(
	occurrence: Dictionary
) -> void:
	semantic_occurrences.append(
		occurrence.duplicate(true)
	)


func _clear_captures() -> void:
	semantic_occurrences.clear()


func _assert(
	condition: bool,
	name: String,
	detail: String = ""
) -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
