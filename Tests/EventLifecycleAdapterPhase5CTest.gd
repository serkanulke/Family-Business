extends Node


var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_id := -1
var original_lifespan := "normal"

var age_signals: Array[Dictionary] = []
var stage_signals: Array[Dictionary] = []
var retirement_signals: Array[Dictionary] = []
var death_signals: Array[Dictionary] = []
var birth_signals: Array[Dictionary] = []
var semantic_occurrences: Array[Dictionary] = []


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	original_lifespan = GameManager.lifespan_setting
	SaveManager.current_save_id = -1
	_connect_capture_signals()

	_test_age_reached_transition()
	_test_all_life_stage_boundaries()
	_test_retirement_transition_is_complete_before_signal()
	_test_deterministic_death_and_existing_adapter()
	_test_character_born_regression()
	_test_save_load_without_lifecycle_replay()
	_test_new_game_reset_is_domain_owned()
	_test_no_persistent_lifecycle_markers()

	_disconnect_capture_signals()
	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.current_save_id = original_save_id
	GameManager.lifespan_setting = original_lifespan

	print("========================================")
	print("Event Phase 5C lifecycle adapter tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_age_reached_transition() -> void:
	var character := _character(1, "1965-01-26", "young_adult")
	_setup_world([character], [_system_event("phase5c_age", "age_reached")])

	_assert(age_signals.is_empty() and _semantic("age_reached").is_empty(), "Day before birthday has no age_reached occurrence")
	TimeManager.advance_day()

	var signals := age_signals.duplicate(true)
	var occurrences := _semantic("age_reached")
	_assert(signals.size() == 1 and int(signals[0].character_id) == 1 and int(signals[0].age) == 20, "Birthday progression emits one age_reached domain signal with the canonical age")
	_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1,"age":20}), "age_reached bridge dispatches canonical Character and age context")
	_assert(String(occurrences[0].occurrence_id) == "age_reached:1:20:1985-01-26" and _active_event_is("phase5c_age", 1), "age_reached uses stable identity and queues one matching Event")

	TimeManager.advance_day()
	_assert(age_signals.size() == 1 and _semantic("age_reached").size() == 1 and EventManager.queued_events.is_empty(), "Next date processing emits no duplicate birthday occurrence")
	EventManager.cancel_active_event()


func _test_all_life_stage_boundaries() -> void:
	var boundaries: Array[int] = []
	for age in range(1, 100):
		if CharacterManager.get_life_stage_from_age(age - 1) != CharacterManager.get_life_stage_from_age(age):
			boundaries.append(age)
	_assert(boundaries.size() == 5, "Canonical CharacterManager exposes exactly five life-stage boundaries")

	for boundary_age in boundaries:
		var previous_stage := CharacterManager.get_life_stage_from_age(boundary_age - 1)
		var new_stage := CharacterManager.get_life_stage_from_age(boundary_age)
		var birth_year := 1985 - boundary_age
		var character := _character(1, "%04d-01-26" % birth_year, previous_stage)
		_setup_world([character], [_system_event("phase5c_stage", "life_stage_changed")])

		TimeManager.current_day = 26
		CharacterManager._on_date_changed(TimeManager.get_date_string())

		var occurrences := _semantic("life_stage_changed")
		_assert(String(character.life_stage) == new_stage and stage_signals.size() == 1, "%s to %s boundary applies once at canonical age %d" % [previous_stage, new_stage, boundary_age])
		_assert(stage_signals[0] == {"character_id":1,"previous_stage":previous_stage,"new_stage":new_stage}, "%s to %s domain signal preserves exact old/new values" % [previous_stage, new_stage])
		_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1,"previous_stage":previous_stage,"life_stage":new_stage}) and _active_event_is("phase5c_stage", 1), "%s to %s bridge uses canonical life_stage context and Character binding" % [previous_stage, new_stage])
		EventManager.cancel_active_event()


func _test_retirement_transition_is_complete_before_signal() -> void:
	var character := _character(1, "1920-01-26", "elder")
	character.salary = 12000
	var businesses := [{"business_instance_id":"phase5c_business","slots":[{"slot_id":"slot_1","assigned_character_id":1,"assigned_npc_id":null},{"slot_id":"slot_2","assigned_character_id":2,"assigned_npc_id":null}]}]
	_setup_world([character, _character(2, "1940-01-26", "adult")], [_system_event("phase5c_retired", "retired")], businesses)

	TimeManager.advance_day()

	var occurrences := _semantic("retired")
	_assert(bool(character.is_retired) and int(character.last_salary) == 12000 and int(character.pension) == 1200 and int(character.salary) == 0, "Age-65 progression completes the unchanged canonical retirement calculation")
	_assert(BusinessManager.get_character_assignment(1).is_empty() and String(BusinessManager.get_character_assignment(2).get("slot_id", "")) == "slot_2", "Retirement removes only the retiree's Family Business assignment")
	_assert(retirement_signals.size() == 1 and bool(retirement_signals[0].state_final) and bool(retirement_signals[0].business_cleanup_complete), "character_retired emits once only after retirement and Business cleanup are complete")
	_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1}) and String(occurrences[0].occurrence_id) == "retired:1:1985-01-26" and _active_event_is("phase5c_retired", 1), "retired bridge queues once with minimal canonical context and stable identity")

	TimeManager.advance_day()
	_assert(retirement_signals.size() == 1 and _semantic("retired").size() == 1, "Already-retired Character emits no duplicate domain or semantic retirement")
	EventManager.cancel_active_event()


func _test_deterministic_death_and_existing_adapter() -> void:
	var character := _character(1, "1897-01-25", "elder")
	character.is_retired = true
	character.health = 50
	_setup_world([character], [_system_event("phase5c_death", "character_died")])
	GameManager.lifespan_setting = "normal"

	_assert(CharacterManager.get_annual_death_chance(character) == 1.0, "Existing lifespan and health algorithm provides a deterministic canonical death condition")
	TimeManager.advance_day()

	var occurrences := _semantic("character_died")
	_assert(not bool(character.is_alive) and String(character.death_date) == "1985-01-26", "Canonical death commits is_alive and death_date before adaptation")
	_assert(death_signals.size() == 1 and bool(death_signals[0].state_final), "Existing character_died signal emits once from completed CharacterManager death")
	_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1,"death_date":"1985-01-26"}) and String(occurrences[0].occurrence_id) == "character_died:1:1985-01-26", "Existing death bridge preserves canonical context and stable occurrence identity")
	_assert(_active_event_is("phase5c_death", 1), "A controlled character_died Event accepts the dead trigger Character and queues exactly once")

	CharacterManager.update_all_death_checks()
	_assert(death_signals.size() == 1 and _semantic("character_died").size() == 1 and EventManager.queued_events.is_empty(), "Dead Character cannot die or queue a death Event again")
	EventManager.cancel_active_event()


func _test_character_born_regression() -> void:
	var parent_one := _character(1, "1960-01-01", "adult")
	var parent_two := _character(2, "1960-01-01", "adult")
	_setup_world([parent_one, parent_two], [_system_event("phase5c_birth", "character_born")])
	CharacterManager.next_character_id = 3

	var baby := CharacterManager.create_baby_character("Phase Five", "female", 1, 2)
	var occurrences := _semantic("character_born")

	_assert(not baby.is_empty() and int(baby.character_id) == 3 and birth_signals.size() == 1, "Existing Character birth flow still creates and signals exactly one baby")
	_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":3,"parent_ids":[1,2]}) and String(occurrences[0].occurrence_id) == "character_born:3:1985-01-25", "Existing character_born bridge preserves parent context and stable identity")
	_assert(_active_event_is("phase5c_birth", 3) and EventManager.queued_events.is_empty(), "Existing birth adapter queues exactly one controlled Event with the baby as primary")
	EventManager.cancel_active_event()


func _test_save_load_without_lifecycle_replay() -> void:
	var birthday_character := _character(1, "1979-01-26", "child")
	var retired_character := _character(2, "1920-01-26", "elder")
	retired_character.salary = 10000
	var dead_character := _character(3, "1900-01-01", "elder")
	dead_character.is_alive = false
	dead_character.death_date = "1985-01-26"
	var completed_retiree := _character(4, "1910-01-01", "elder")
	completed_retiree.is_retired = true
	completed_retiree.last_salary = 5000
	completed_retiree.pension = 500
	var events := [_system_event("phase5c_load_age", "age_reached"), _system_event("phase5c_load_stage", "life_stage_changed"), _system_event("phase5c_load_retired", "retired"), _system_event("phase5c_load_death", "character_died")]
	var businesses := [{"business_instance_id":"phase5c_load_business","slots":[{"slot_id":"slot_1","assigned_character_id":2,"assigned_npc_id":null}]}]
	_setup_world([birthday_character, retired_character, dead_character, completed_retiree], events, businesses)
	TimeManager.current_day = 26
	EventManager.dispatch_system_trigger("age_reached", {"trigger_character_id":1,"trigger_participants":{"primary":1},"context":{"character_id":1,"age":6}}, "age_reached:1:6:1985-01-26", "CharacterManager")
	var active_instance_id := EventManager.active_event.instance_id
	var snapshot = JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))

	_clear_captures()
	CharacterManager.characters = []
	EventManager.reset_runtime_state()
	var loaded := SaveManager.apply_save_snapshot(snapshot)
	var restored_retiree := CharacterManager.get_character_by_id(2)
	var restored_dead := CharacterManager.get_character_by_id(3)
	var restored_completed_retiree := CharacterManager.get_character_by_id(4)

	_assert(loaded and String(CharacterManager.get_character_by_id(1).life_stage) == "child", "Load restores post-birthday life-stage domain state without transition replay")
	_assert(bool(restored_retiree.is_retired) and int(restored_retiree.last_salary) == 10000 and int(restored_retiree.pension) == 1000 and BusinessManager.get_character_assignment(2).is_empty(), "Load normalizes an eligible legacy Character through canonical retirement and Business cleanup")
	_assert(bool(restored_completed_retiree.is_retired) and int(restored_completed_retiree.pension) == 500, "Load preserves an already-completed retirement without recalculation")
	_assert(not bool(restored_dead.is_alive) and String(restored_dead.death_date) == "1985-01-26", "Load restores completed death state without calling death again")
	_assert(age_signals.is_empty() and stage_signals.is_empty() and retirement_signals.is_empty() and death_signals.is_empty(), "Save restoration emits no lifecycle domain signal")
	_assert(_lifecycle_semantics().is_empty(), "Save restoration dispatches no age, stage, retirement, or death semantic occurrence")
	_assert(EventManager.active_event != null and EventManager.active_event.instance_id == active_instance_id and EventManager.active_event.event_id == "phase5c_load_age" and EventManager.queued_events.is_empty(), "Existing pre-save lifecycle Event state persists without a second queued occurrence")
	EventManager.cancel_active_event()


func _test_new_game_reset_is_domain_owned() -> void:
	var stale_character := _character(
		1,
		"1979-01-26",
		"child"
	)
	_setup_world(
		[stale_character],
		[
			_system_event(
				"phase5c_stale_age",
				"age_reached"
			)
		]
	)

	GameManager.new_game_starting.emit()
	TimeManager.reset_time()

	_assert(
		CharacterManager.characters.is_empty()
		and CharacterManager.next_character_id == 1,
		"New-game start clears Character domain state before the Time reset"
	)
	_assert(
		age_signals.is_empty()
		and stage_signals.is_empty()
		and retirement_signals.is_empty()
		and death_signals.is_empty()
		and _lifecycle_semantics().is_empty(),
		"New-game Time reset cannot replay lifecycle transitions from the previous family"
	)


func _test_no_persistent_lifecycle_markers() -> void:
	var character := _character(1, "1965-01-26", "young_adult")
	_setup_world([character])
	var forbidden := ["last_age_reached", "last_birthday_event", "last_life_stage_event", "retirement_event_sent", "death_event_sent", "funeral_status"]
	var absent := true
	for field_name in forbidden:
		absent = absent and not character.has(field_name)
	_assert(
		absent
		and int(SaveManager.SAVE_VERSION) == 6,
		"Phase 5C adds no persistent Character lifecycle marker and leaves save version 6 unchanged"
	)
	_assert(
		not _object_has_property(
			CharacterManager,
			"_suppress_lifecycle_semantics"
		),
		"CharacterManager keeps no Event-only lifecycle suppression state"
	)


func _setup_world(characters: Array, events: Array = [], businesses: Array = []) -> void:
	SaveManager.current_save_id = -1
	CharacterManager.characters = characters
	CharacterManager.next_character_id = 20
	CareerManager.active_job_offers.clear()
	BusinessManager.businesses = businesses
	HouseManager.houses = []
	GameManager.lifespan_setting = "normal"
	TimeManager.current_year = 1985
	TimeManager.current_month = 1
	TimeManager.current_day = 25
	TimeManager.speed_multiplier = 1.0
	TimeManager.is_paused = true
	TimeManager.day_timer = 0.0
	_configure(events)
	_clear_captures()


func _configure(events: Array) -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_from_json_sources({"age_lifecycle.json":JSON.stringify({"schema_version":1,"category":"age_lifecycle","pools":[],"events":events})})
	_assert(loaded, "Phase 5C fixture registry validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 53)


func _system_event(event_id: String, semantic_event: String) -> Dictionary:
	return {"event_id":event_id,"category":"age_lifecycle","domain":"lifecycle","subtype":"phase5c_fixture","enabled":true,"rarity":"common","weight":1.0,"priority":0,"exclusive_group":null,"trigger":{"type":"system","event":semantic_event},"participants":{"primary":{"type":"character","source":"trigger"}},"requirements":{"all":[]},"repeat":{"mode":"repeatable"},"cooldown":null,"behavior":{"blocking":false,"pause_game":false},"content":{"title":event_id,"description":"Phase 5C fixture"},"presentation":{"template":"standard_event"},"choices":[{"choice_id":"continue","title":"Continue","requirements":{"all":[]},"resolution":{"mode":"deterministic","effects":[]}}]}


func _character(character_id: int, birth_date: String, life_stage: String) -> Dictionary:
	return {"character_id":character_id,"character_type":"family","linked_character_id":null,"first_name":"Lifecycle","last_name":"Adapter","gender":"female","birth_date":birth_date,"death_date":null,"life_stage":life_stage,"is_alive":true,"is_player_family":true,"parent_ids":[],"children_ids":[],"partner_id":null,"relationship_cooldown_until":null,"flag_ids":[],"health":100,"happiness":100,"logic":100,"attractiveness":100,"social":100,"confidence":100,"discipline":100,"creativity":100,"job_id":null,"company_id":null,"salary":0,"school_id":null,"major_id":null,"education_status":"graduated","education_start_date":null,"major_selection_date":null,"expected_graduation_date":null,"graduation_date":null,"unemployment_start_date":null,"job_offer_cooldown_until":null,"event_log":[],"is_retired":false,"last_salary":0,"pension":0,"avatar_theme":"default","genetics":{"skin_tone":"light"},"portrait_variant_id":"","portrait_path":"res://Resources/Characters/default_avatar.png"}


func _active_event_is(event_id: String, character_id: int) -> bool:
	return EventManager.active_event != null and EventManager.active_event.event_id == event_id and int(EventManager.active_event.participants.get("primary", 0)) == character_id


func _semantic(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(occurrence.get("semantic_event", "")) == name:
			result.append(occurrence)
	return result


func _lifecycle_semantics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(occurrence.get("semantic_event", "")) in ["age_reached", "life_stage_changed", "retired", "character_died"]:
			result.append(occurrence)
	return result


func _context_matches(occurrence: Dictionary, expected: Dictionary) -> bool:
	var context = occurrence.get("context", {})
	if typeof(context) != TYPE_DICTIONARY:
		return false
	for key in expected:
		if context.get(key, null) != expected[key]:
			return false
	return true


func _connect_capture_signals() -> void:
	CharacterManager.age_reached.connect(_on_age_reached)
	CharacterManager.life_stage_changed.connect(_on_life_stage_changed)
	CharacterManager.character_retired.connect(_on_character_retired)
	CharacterManager.character_died.connect(_on_character_died)
	CharacterManager.character_born.connect(_on_character_born)
	EventManager.semantic_trigger_dispatched.connect(_on_semantic_trigger_dispatched)


func _disconnect_capture_signals() -> void:
	CharacterManager.age_reached.disconnect(_on_age_reached)
	CharacterManager.life_stage_changed.disconnect(_on_life_stage_changed)
	CharacterManager.character_retired.disconnect(_on_character_retired)
	CharacterManager.character_died.disconnect(_on_character_died)
	CharacterManager.character_born.disconnect(_on_character_born)
	EventManager.semantic_trigger_dispatched.disconnect(_on_semantic_trigger_dispatched)


func _on_age_reached(character_id: int, age: int) -> void:
	age_signals.append({"character_id":character_id,"age":age})


func _on_life_stage_changed(character_id: int, previous_stage: String, new_stage: String) -> void:
	stage_signals.append({"character_id":character_id,"previous_stage":previous_stage,"new_stage":new_stage})


func _on_character_retired(character_id: int) -> void:
	var character := CharacterManager.get_character_by_id(character_id)
	retirement_signals.append({"character_id":character_id,"state_final":bool(character.get("is_retired", false)) and int(character.get("salary", -1)) == 0,"business_cleanup_complete":BusinessManager.get_character_assignment(character_id).is_empty()})


func _on_character_died(character_id: int, death_date: String) -> void:
	var character := CharacterManager.get_character_by_id(character_id)
	death_signals.append({"character_id":character_id,"death_date":death_date,"state_final":not bool(character.get("is_alive", true)) and String(character.get("death_date", "")) == death_date})


func _on_character_born(character_id: int, parent_one_id: int, parent_two_id: int) -> void:
	birth_signals.append({"character_id":character_id,"parent_ids":[parent_one_id,parent_two_id]})


func _on_semantic_trigger_dispatched(occurrence: Dictionary) -> void:
	semantic_occurrences.append(occurrence.duplicate(true))


func _clear_captures() -> void:
	age_signals.clear()
	stage_signals.clear()
	retirement_signals.clear()
	death_signals.clear()
	birth_signals.clear()
	semantic_occurrences.clear()


func _object_has_property(
	object: Object,
	property_name: String
) -> bool:
	for property_value in object.get_property_list():
		if typeof(property_value) != TYPE_DICTIONARY:
			continue

		var property: Dictionary = property_value
		if String(
			property.get(
				"name",
				""
			)
		) == property_name:
			return true

	return false


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
