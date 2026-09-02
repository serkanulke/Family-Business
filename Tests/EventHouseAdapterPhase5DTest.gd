extends Node


var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_id := -1

var assignment_signals: Array[Dictionary] = []
var semantic_occurrences: Array[Dictionary] = []


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	SaveManager.current_save_id = -1

	_connect_capture_signals()

	_test_assignment_and_unhoused_transitions()
	_test_role_replacement()
	_test_divorce_death_and_bootstrap_suppression()
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


func _test_assignment_and_unhoused_transitions() -> void:
	var head := _character(1, 60, [1002])
	var resident := _character(2, 70)
	var mover := _character(3, 70)
	_setup_world(
		[head, resident, mover],
		[
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true)
		],
		_default_houses(1)
	)

	_assert(
		HouseManager.assign_character_as_resident("house_0001", 2),
		"Resident assignment succeeds through the canonical HouseManager API"
	)
	_assert(
		assignment_signals.size() == 1
		and assignment_signals[0].previous_assignment.is_empty()
		and String(assignment_signals[0].new_assignment.get("assignment_type", "")) == "resident"
		and String(assignment_signals[0].new_assignment.get("house_instance_id", "")) == "house_0001",
		"Resident assignment emits one precise post-success domain transition"
	)
	_assert(
		_semantic("house_assignment_changed").size() == 1
		and _context_matches(
			_semantic("house_assignment_changed")[0],
			{
				"character_id": 2,
				"previous_house_instance_id": "",
				"house_instance_id": "house_0001",
				"assignment_type": "resident"
			}
		),
		"Resident assignment dispatches one character-bound house_assignment_changed occurrence"
	)
	_assert(
		_semantic("character_became_unhoused").is_empty(),
		"Becoming housed never emits a false Unhoused occurrence"
	)
	_assert(
		_active_event_is("phase5d_assignment", 2),
		"Controlled assignment Event queues exactly once"
	)
	_cancel_all_events()
	_clear_captures()

	_assert(
		HouseManager.assign_character_to_role("house_0001", "cook", 2),
		"Resident can move directly into a House role through existing canonical behavior"
	)
	_assert(
		assignment_signals.size() == 1
		and String(assignment_signals[0].previous_assignment.get("assignment_type", "")) == "resident"
		and String(assignment_signals[0].new_assignment.get("assignment_type", "")) == "role"
		and String(assignment_signals[0].new_assignment.get("role_id", "")) == "cook",
		"Resident-to-role is reported as one logical transition"
	)
	_assert(
		_semantic("house_assignment_changed").size() == 1
		and _semantic("character_became_unhoused").is_empty(),
		"Resident-to-role does not expose a transient Unhoused state"
	)
	_cancel_all_events()
	_clear_captures()

	_assert(
		HouseManager.assign_character_as_resident("house_0001", 3),
		"Move fixture Character can first enter the source House"
	)
	_cancel_all_events()
	_clear_captures()

	_assert(
		HouseManager.assign_character_to_role("house_0002", "cook", 3),
		"Existing resident-to-role behavior supports a direct cross-House move"
	)
	_assert(
		assignment_signals.size() == 1
		and String(assignment_signals[0].previous_assignment.get("house_instance_id", "")) == "house_0001"
		and String(assignment_signals[0].new_assignment.get("house_instance_id", "")) == "house_0002",
		"Cross-House move preserves source and destination in one transition"
	)
	_assert(
		_semantic("character_became_unhoused").is_empty(),
		"Direct cross-House move never emits a transient Unhoused occurrence"
	)
	_cancel_all_events()
	_clear_captures()

	_assert(
		HouseManager.remove_character_from_house(2),
		"Explicit canonical House removal succeeds"
	)
	_assert(
		HouseManager.is_character_unhoused(2),
		"Explicit removal leaves the living playable Character canonically Unhoused"
	)
	_assert(
		_semantic("house_assignment_changed").size() == 1
		and _semantic("character_became_unhoused").size() == 1,
		"Explicit removal emits exactly one assignment change and one Unhoused semantic occurrence"
	)
	var counts_before := {
		"assignment": _semantic("house_assignment_changed").size(),
		"unhoused": _semantic("character_became_unhoused").size()
	}
	_assert(
		not HouseManager.remove_character_from_house(2)
		and _semantic("house_assignment_changed").size() == int(counts_before.get("assignment", 0))
		and _semantic("character_became_unhoused").size() == int(counts_before.get("unhoused", 0)),
		"Failed repeated removal emits no duplicate semantic occurrence"
	)
	_cancel_all_events()


func _test_role_replacement() -> void:
	var head := _character(1, 60)
	var displaced := _character(2, 60)
	var replacement := _character(3, 80)
	var houses := _default_houses(1)
	var roles: Dictionary = houses[0].get("role_assignments", {})
	roles["cook"] = 2
	houses[0]["role_assignments"] = roles

	_setup_world(
		[head, displaced, replacement],
		[
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true)
		],
		houses
	)

	_assert(
		HouseManager.assign_character_to_role("house_0001", "cook", 3),
		"Occupied House role replacement preserves existing canonical assignment behavior"
	)
	_assert(
		HouseManager.get_role_character_id("house_0001", "cook") == 3
		and HouseManager.get_character_assignment(2).is_empty()
		and HouseManager.is_character_unhoused(2),
		"Role replacement leaves the displaced playable Character genuinely Unhoused"
	)
	_assert(
		assignment_signals.size() == 2
		and int(assignment_signals[0].character_id) == 2
		and String(assignment_signals[0].reason) == "role_replaced"
		and int(assignment_signals[1].character_id) == 3,
		"Role replacement reports both affected Characters without changing assignment rules"
	)
	_assert(
		_semantic_for_character("house_assignment_changed", 2).size() == 1
		and _semantic_for_character("house_assignment_changed", 3).size() == 1
		and _semantic_for_character("character_became_unhoused", 2).size() == 1,
		"Role replacement dispatches precise assignment semantics and one displaced-Unhoused occurrence"
	)
	_assert(
		HouseManager.get_role_character_id("house_0001", "head_of_household") == 1,
		"Role replacement does not alter unrelated House occupants"
	)
	_cancel_all_events()


func _test_divorce_death_and_bootstrap_suppression() -> void:
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
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true)
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
		"Divorce family-exit cleanup still removes the departing spouse from House"
	)
	_assert(
		assignment_signals.size() == 1
		and String(assignment_signals[0].reason) == "family_exit",
		"HouseManager retains a precise family_exit domain transition for cleanup consumers"
	)
	_assert(
		_house_semantics().is_empty(),
		"Departing divorce spouse creates no playable-family House or Unhoused Event occurrence"
	)
	_cancel_all_events()

	var living := _character(1, 60)
	var doomed := _character(2, 60)
	houses = _default_houses(1)
	houses[0]["resident_character_ids"] = [2]
	_setup_world(
		[living, doomed],
		[
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true)
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
		assignment_signals.is_empty()
		and _house_semantics().is_empty(),
		"Death cleanup does not reinterpret a dead Character as Unhoused or as a House assignment Event"
	)
	_cancel_all_events()

	var starter := _character(1, 60)
	_setup_world(
		[starter],
		[
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true)
		],
		[]
	)
	HouseManager._on_new_game_started(starter)
	_assert(
		HouseManager.get_role_character_id("house_0001", "head_of_household") == 1,
		"Starting House bootstrap still assigns the starting Character as Head"
	)
	_assert(
		assignment_signals.is_empty()
		and _house_semantics().is_empty(),
		"Starting House bootstrap produces no gameplay House semantic occurrence"
	)
	_cancel_all_events()


func _test_upgrade_and_live_requirements() -> void:
	var head := _character(1, 60, [1002])
	var replacement := _character(2, 80)
	_setup_world(
		[head, replacement],
		[
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true),
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
		_semantic("house_upgraded").size() == 1
		and _semantic("house_assignment_changed").is_empty(),
		"House upgrade dispatches house_upgraded once and no false assignment semantic"
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
			_system_event("phase5d_assignment", "house_assignment_changed", true),
			_system_event("phase5d_unhoused", "character_became_unhoused", true),
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
		assignment_signals.is_empty()
		and _house_semantics().is_empty(),
		"House restore emits no assignment, Unhoused, or upgrade semantic replay"
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


func _active_event_is(
	event_id: String,
	character_id: int
) -> bool:
	return (
		EventManager.active_event != null
		and EventManager.active_event.event_id == event_id
		and int(
			EventManager.active_event.participants.get(
				"primary",
				0
			)
		) == character_id
	)


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


func _semantic_for_character(
	name: String,
	character_id: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in _semantic(name):
		var context = occurrence.get("context", {})
		if (
			typeof(context) == TYPE_DICTIONARY
			and int(context.get("character_id", 0)) == character_id
		):
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


func _context_matches(
	occurrence: Dictionary,
	expected: Dictionary
) -> bool:
	var context = occurrence.get("context", {})
	if typeof(context) != TYPE_DICTIONARY:
		return false
	for key in expected:
		if context.get(key, null) != expected[key]:
			return false
	return true


func _cancel_all_events() -> void:
	while EventManager.active_event != null:
		EventManager.cancel_active_event()


func _connect_capture_signals() -> void:
	HouseManager.character_house_assignment_changed.connect(
		_on_character_house_assignment_changed
	)
	EventManager.semantic_trigger_dispatched.connect(
		_on_semantic_trigger_dispatched
	)


func _disconnect_capture_signals() -> void:
	HouseManager.character_house_assignment_changed.disconnect(
		_on_character_house_assignment_changed
	)
	EventManager.semantic_trigger_dispatched.disconnect(
		_on_semantic_trigger_dispatched
	)


func _on_character_house_assignment_changed(
	character_id: int,
	previous_assignment: Dictionary,
	new_assignment: Dictionary,
	reason: String
) -> void:
	assignment_signals.append(
		{
			"character_id": character_id,
			"previous_assignment": previous_assignment.duplicate(true),
			"new_assignment": new_assignment.duplicate(true),
			"reason": reason
		}
	)


func _on_semantic_trigger_dispatched(
	occurrence: Dictionary
) -> void:
	semantic_occurrences.append(
		occurrence.duplicate(true)
	)


func _clear_captures() -> void:
	assignment_signals.clear()
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
