extends Node


var passed := 0
var failed := 0
var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_id := -1
var semantic_occurrences: Array[Dictionary] = []
var legacy_requests: Array[Dictionary] = []
var legacy_major_requests: Array[int] = []


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	SaveManager.current_save_id = -1
	_connect_capture_signals()

	_test_primary_school_due_and_running_time()
	_test_middle_school_transition_due()
	_test_high_school_transition_due()
	_test_university_choice_due()
	_test_major_selection_due()
	_test_successful_enrollment_and_event_queue()
	_test_failed_enrollment_paths()
	_test_graduation_and_event_queue()
	_test_major_selection_and_university_decline_remain_legacy_owned()
	_test_manually_paused_time_remains_paused()
	_test_save_load_emits_no_domain_occurrences()

	_disconnect_capture_signals()
	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.current_save_id = original_save_id

	print("========================================")
	print("Event Phase 5A Education adapter tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_primary_school_due_and_running_time() -> void:
	_setup_world(_character(1, "1979-01-26"), [], false)
	EducationManager.check_birthday_education_events()
	var due := _semantic("education_stage_due")
	_assert(EducationManager.is_current_education_event(1, "school_enrollment", "primary_school"), "Primary birthday keeps the canonical legacy Education event active")
	_assert(legacy_requests.size() == 1 and legacy_requests[0].event_type == "school_enrollment" and legacy_requests[0].education_stage == "primary_school", "Primary birthday emits the existing legacy presentation request once")
	_assert(due.size() == 1 and _context_matches(due[0], {"character_id":1,"event_type":"school_enrollment","education_stage":"primary_school"}), "Primary birthday reaches EventManager once with canonical due context")
	_assert(TimeManager.is_paused and EventManager.active_event == null and not EventManager._pause_state_captured, "Empty production-style Event registry does not acquire a second pause")
	EducationManager.check_birthday_education_events()
	_assert(_semantic("education_stage_due").size() == 1 and legacy_requests.size() == 1, "Repeated birthday check does not duplicate the active Education occurrence")
	EducationManager.complete_current_education_event()
	_assert(not TimeManager.is_paused, "Legacy Education flow restores previously running time")


func _test_middle_school_transition_due() -> void:
	var character := _character(1, "1973-01-26")
	character.school_id = _find_school_id("primary_school", "public")
	character.education_status = "studying"
	_setup_world(character)
	EducationManager.check_birthday_education_events()
	var due := _semantic("education_stage_due")
	var graduated := _semantic("school_graduated")
	_assert(character.education_status == "graduated" and EducationManager.is_current_education_event(1, "school_transition", "middle_school"), "Middle transition keeps canonical Primary graduation and legacy queue behavior")
	_assert(due.size() == 1 and _context_matches(due[0], {"character_id":1,"event_type":"school_transition","education_stage":"middle_school"}), "Middle transition emits one education_stage_due occurrence")
	_assert(graduated.size() == 1 and _context_matches(graduated[0], {"character_id":1,"school_id":character.school_id,"education_stage":"primary_school","graduation_date":"1985-01-26"}), "Primary graduation emits one authoritative school_graduated occurrence")


func _test_high_school_transition_due() -> void:
	var character := _character(1, "1970-01-26")
	character.school_id = _find_school_id("middle_school", "public")
	character.education_status = "studying"
	_setup_world(character)
	EducationManager.check_birthday_education_events()
	_assert(character.education_status == "graduated" and EducationManager.is_current_education_event(1, "school_transition", "high_school"), "High transition keeps canonical Middle graduation and legacy queue behavior")
	_assert(_semantic("education_stage_due").size() == 1 and _context_matches(_semantic("education_stage_due")[0], {"event_type":"school_transition","education_stage":"high_school"}), "High transition emits one education_stage_due occurrence")
	_assert(_semantic("school_graduated").size() == 1 and _context_matches(_semantic("school_graduated")[0], {"education_stage":"middle_school"}), "Middle graduation emits one school_graduated occurrence")


func _test_university_choice_due() -> void:
	var character := _character(1, "1967-01-26")
	character.school_id = _find_school_id("high_school", "public")
	character.education_status = "studying"
	_setup_world(character)
	EducationManager.check_birthday_education_events()
	_assert(character.education_status == "graduated" and EducationManager.is_current_education_event(1, "university_choice", "university"), "University choice keeps canonical High School graduation and legacy flow")
	_assert(_semantic("education_stage_due").size() == 1 and _context_matches(_semantic("education_stage_due")[0], {"event_type":"university_choice","education_stage":"university"}), "University choice emits one education_stage_due occurrence")
	_assert(_semantic("school_graduated").size() == 1 and _context_matches(_semantic("school_graduated")[0], {"education_stage":"high_school"}), "High School graduation emits one school_graduated occurrence")


func _test_major_selection_due() -> void:
	var character := _character(1, "1964-01-26", 100)
	character.school_id = _find_school_id("university", "public")
	character.education_status = "studying"
	character.education_start_date = "1982-01-26"
	_setup_world(character)
	EducationManager.check_birthday_education_events()
	var due := _semantic("education_stage_due")
	_assert(EducationManager.is_current_education_event(1, "major_selection", "university") and legacy_major_requests == [1], "Major-selection legacy request remains active and emits once")
	_assert(due.size() == 1 and _context_matches(due[0], {"character_id":1,"event_type":"major_selection","education_stage":"university"}), "Major selection reaches the existing education_stage_due bridge once")
	EducationManager.check_birthday_education_events()
	_assert(_semantic("education_stage_due").size() == 1 and legacy_major_requests == [1], "Major-selection due bridge is not duplicated")
	_assert(_semantic("major_selected").is_empty(), "No unapproved major_selected semantic trigger is invented")


func _test_successful_enrollment_and_event_queue() -> void:
	var character := _character(1, "1979-01-26", 50)
	_setup_world(character, [_system_event("phase5a_enrolled", "school_enrolled")], false)
	EducationManager.check_birthday_education_events()
	semantic_occurrences.clear()
	var school_id := _find_school_id("primary_school", "private")
	var school := EducationManager.get_school_by_id(school_id)
	var money_before := GameManager.family_money
	var stats_before := _stat_values(character)
	var enrolled := EducationManager.enroll_character_in_school(1, school_id)
	var money_after := GameManager.family_money
	var stats_after := _stat_values(character)
	var occurrences := _semantic("school_enrolled")
	_assert(enrolled and money_after == money_before - int(school.base_cost), "Successful enrollment spends the School.json cost exactly once")
	_assert(_stats_match_bonus(stats_before, stats_after, school.stat_bonus), "Successful enrollment applies each School.json stat bonus exactly once")
	_assert(character.school_id == school_id and character.education_status == "studying" and character.education_start_date == "1985-01-26", "Successful enrollment writes canonical Education fields once")
	_assert(occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1,"school_id":school_id,"education_stage":"primary_school","school_type":"private"}), "Successful enrollment dispatches one school_enrolled semantic context")
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == "phase5a_enrolled" and EventManager.active_event.participants.primary == 1 and EventManager.queued_events.is_empty(), "Real Education enrollment queues the matching test Event exactly once")
	var second := EducationManager.enroll_character_in_school(1, school_id)
	_assert(not second and GameManager.family_money == money_after and _stat_values(character) == stats_after and _semantic("school_enrolled").size() == 1, "A second call cannot duplicate cost, bonus, state, or semantic occurrence")
	_assert(not TimeManager.is_paused and not EventManager._pause_state_captured, "Non-blocking adapter fixture does not interfere with legacy Education resume")
	EventManager.cancel_active_event()


func _test_failed_enrollment_paths() -> void:
	var character := _character(1, "1979-01-26")
	_setup_world(character, [_system_event("phase5a_enrolled", "school_enrolled")])
	_set_active_education_event(1, "school_enrollment", "primary_school")
	_assert(not EducationManager.enroll_character_in_school(1, 999999) and _semantic("school_enrolled").is_empty(), "Invalid school emits no school_enrolled occurrence")

	_setup_world(_character(1, "1979-01-26"), [_system_event("phase5a_enrolled", "school_enrolled")])
	_set_active_education_event(1, "school_enrollment", "primary_school")
	_assert(not EducationManager.enroll_character_in_school(1, _find_school_id("middle_school", "public")) and _semantic("school_enrolled").is_empty(), "Wrong-stage school emits no school_enrolled occurrence")

	_setup_world(_character(1, "1979-01-26"), [_system_event("phase5a_enrolled", "school_enrolled")])
	_set_active_education_event(1, "school_enrollment", "primary_school")
	GameManager.family_money = 0
	_assert(not EducationManager.enroll_character_in_school(1, _find_school_id("primary_school", "private")) and _semantic("school_enrolled").is_empty(), "Unaffordable school emits no school_enrolled occurrence")

	_setup_world(_character(1, "1979-01-26"), [_system_event("phase5a_enrolled", "school_enrolled")])
	_assert(not EducationManager.enroll_character_in_school(1, _find_school_id("primary_school", "public")) and _semantic("school_enrolled").is_empty() and EventManager.active_event == null, "Enrollment without an active legacy flow emits and queues nothing")


func _test_graduation_and_event_queue() -> void:
	var primary := _character(1, "1973-01-26")
	primary.school_id = _find_school_id("primary_school", "public")
	primary.education_status = "studying"
	_setup_world(primary, [_system_event("phase5a_graduated", "school_graduated")])
	var graduated := EducationManager.graduate_current_school(primary, "primary_school")
	var occurrences := _semantic("school_graduated")
	_assert(graduated and occurrences.size() == 1 and _context_matches(occurrences[0], {"character_id":1,"school_id":primary.school_id,"education_stage":"primary_school","graduation_date":"1985-01-26"}), "Successful Primary graduation dispatches one canonical context")
	_assert(EventManager.active_event != null and EventManager.active_event.event_id == "phase5a_graduated" and EventManager.active_event.participants.primary == 1, "Real graduation queues the matching test Event exactly once")
	var second := EducationManager.graduate_current_school(primary, "primary_school")
	_assert(not second and _semantic("school_graduated").size() == 1 and EventManager.queued_events.is_empty(), "Graduation cannot dispatch or queue twice")
	EventManager.cancel_active_event()

	var university := _character(1, "1963-01-26", 100)
	university.school_id = _find_school_id("university", "public")
	university.education_status = "studying"
	university.major_id = _find_major_id_with_duration(4)
	_setup_world(university, [_system_event("phase5a_graduated", "school_graduated")])
	_assert(EducationManager.graduate_current_school(university, "university") and _semantic("school_graduated").size() == 1 and _context_matches(_semantic("school_graduated")[0], {"education_stage":"university","major_id":university.major_id}), "University graduation includes the authoritative major when available")
	EventManager.cancel_active_event()

	var invalid := _character(1, "1973-01-26")
	invalid.school_id = _find_school_id("primary_school", "public")
	_setup_world(invalid, [_system_event("phase5a_graduated", "school_graduated")])
	_assert(not EducationManager.graduate_current_school(invalid, "primary_school") and not EducationManager.graduate_current_school(invalid, "middle_school") and _semantic("school_graduated").is_empty() and EventManager.active_event == null, "Failed graduation emits and queues nothing")


func _test_major_selection_and_university_decline_remain_legacy_owned() -> void:
	var student := _character(1, "1964-01-26", 100)
	student.school_id = _find_school_id("university", "public")
	student.education_status = "studying"
	student.education_start_date = "1982-01-26"
	_setup_world(student)
	_set_active_education_event(1, "major_selection", "university")
	var major_id := _find_major_id_with_duration(4)
	var selected := EducationManager.select_major(1, major_id)
	_assert(selected and student.major_id == major_id and student.expected_graduation_date == "1986-01-26" and not EducationManager.is_education_event_active, "Existing major selection remains EducationManager-owned and duration-based")
	_assert(_semantic("major_selected").is_empty() and _semantic("school_graduated").is_empty(), "Successful long-major selection invents no semantic trigger or instant graduation")

	var candidate := _character(1, "1967-01-26")
	_setup_world(candidate, [], false)
	_set_active_education_event(1, "university_choice", "university")
	EducationManager.is_education_pause_active = true
	EducationManager.should_resume_time_after_education_events = true
	TimeManager.is_paused = true
	var declined := EducationManager.decline_university(1)
	_assert(declined and candidate.major_id == null and not EducationManager.is_education_event_active and not TimeManager.is_paused, "University decline remains canonical and preserves legacy completion/resume")
	_assert(_semantic("education_declined").is_empty() and _semantic("university_rejected").is_empty(), "University decline invents no unapproved semantic trigger")


func _test_manually_paused_time_remains_paused() -> void:
	_setup_world(_character(1, "1979-01-26"), [], true)
	EducationManager.check_birthday_education_events()
	var paused_during := TimeManager.is_paused
	EducationManager.complete_current_education_event()
	_assert(paused_during and TimeManager.is_paused and not EventManager._pause_state_captured and EventManager.active_event == null, "Manually paused game remains paused and Event adapter owns no pause")


func _test_save_load_emits_no_domain_occurrences() -> void:
	var character := _character(1, "1970-01-26", 70)
	character.school_id = _find_school_id("middle_school", "public")
	character.education_status = "graduated"
	character.graduation_date = "1985-01-26"
	_setup_world(character, [_system_event("phase5a_enrolled", "school_enrolled"), _system_event("phase5a_graduated", "school_graduated")])
	var snapshot = JSON.parse_string(JSON.stringify(SaveManager.create_save_snapshot()))
	character.school_id = null
	character.education_status = "none"
	character.graduation_date = null
	semantic_occurrences.clear()
	var loaded := SaveManager.apply_save_snapshot(snapshot)
	var restored := CharacterManager.get_character_by_id(1)
	_assert(loaded and int(snapshot.save_version) == 6 and int(SaveManager.SAVE_VERSION) == 6, "Phase 5A keeps save schema version 6")
	_assert(restored.school_id == _find_school_id("middle_school", "public") and restored.education_status == "graduated" and restored.graduation_date == "1985-01-26", "Save/load restores existing Education state without domain operations")
	_assert(_semantic("school_enrolled").is_empty() and _semantic("school_graduated").is_empty() and EventManager.active_event == null, "Deserialization emits no fresh enrollment/graduation semantic occurrence")


func _setup_world(character: Dictionary, events: Array = [], paused: bool = false) -> void:
	SaveManager.current_save_id = -1
	CharacterManager.characters = [character]
	CharacterManager.next_character_id = 2
	GameManager.family_money = 50000
	TimeManager.current_year = 1985
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	TimeManager.speed_multiplier = 2.0
	TimeManager.is_paused = paused
	TimeManager.day_timer = 0.0
	_reset_education_runtime()
	_configure(events)
	semantic_occurrences.clear()
	legacy_requests.clear()
	legacy_major_requests.clear()


func _reset_education_runtime() -> void:
	EducationManager.education_event_queue.clear()
	EducationManager.current_education_event = {}
	EducationManager.is_education_event_active = false
	EducationManager.is_education_pause_active = false
	EducationManager.should_resume_time_after_education_events = false


func _set_active_education_event(character_id: int, event_type: String, education_stage: String) -> void:
	EducationManager.current_education_event = {"character_id":character_id,"event_type":event_type,"education_stage":education_stage}
	EducationManager.is_education_event_active = true


func _configure(events: Array) -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_from_json_sources({"education.json":JSON.stringify({"schema_version":1,"category":"education","pools":[],"events":events})})
	_assert(loaded, "Phase 5A fixture registry validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 51)


func _system_event(event_id: String, semantic_event: String) -> Dictionary:
	return {"event_id":event_id,"category":"education","domain":"education","subtype":"phase5a_fixture","enabled":true,"rarity":"common","weight":1.0,"priority":0,"exclusive_group":null,"trigger":{"type":"system","event":semantic_event},"participants":{"primary":{"type":"character","source":"trigger"}},"requirements":{"all":[]},"repeat":{"mode":"repeatable"},"cooldown":null,"behavior":{"blocking":false,"pause_game":false},"content":{"title":event_id,"description":"Phase 5A fixture"},"presentation":{"template":"standard_event"},"choices":[{"choice_id":"continue","title":"Continue","requirements":{"all":[]},"resolution":{"mode":"deterministic","effects":[]}}]}


func _character(character_id: int, birth_date: String, stats: int = 50) -> Dictionary:
	return {"character_id":character_id,"character_type":"family","linked_character_id":null,"first_name":"Education","last_name":"Adapter","gender":"female","birth_date":birth_date,"life_stage":"young_adult","is_alive":true,"is_player_family":true,"parent_ids":[],"children_ids":[],"partner_id":null,"relationship_cooldown_until":null,"flag_ids":[],"health":stats,"happiness":stats,"logic":stats,"attractiveness":stats,"social":stats,"confidence":stats,"discipline":stats,"creativity":stats,"job_id":null,"company_id":null,"salary":0,"school_id":null,"major_id":null,"education_status":"none","education_start_date":null,"major_selection_date":null,"expected_graduation_date":null,"graduation_date":null,"event_log":[],"is_retired":false,"last_salary":0,"pension":0,"avatar_theme":"default","genetics":{"skin_tone":"light"},"portrait_variant_id":"","portrait_path":"res://Resources/Characters/default_avatar.png"}


func _find_school_id(stage: String, school_type: String) -> int:
	for value in EducationManager.get_schools_for_stage(stage):
		if typeof(value) == TYPE_DICTIONARY and String(value.get("school_type", "")) == school_type:
			return int(value.get("school_id", 0))
	return 0


func _find_major_id_with_duration(duration: int) -> int:
	for value in CharacterManager.majors:
		if typeof(value) == TYPE_DICTIONARY and not bool(value.get("is_fallback", false)) and int(value.get("duration_years", 0)) == duration:
			return int(value.get("major_id", 0))
	return 0


func _stat_values(character: Dictionary) -> Dictionary:
	var values := {}
	for stat_name in CharacterManager.CHARACTER_STAT_NAMES:
		values[stat_name] = int(character.get(stat_name, 0))
	return values


func _stats_match_bonus(before: Dictionary, after: Dictionary, bonuses: Dictionary) -> bool:
	for stat_name in CharacterManager.CHARACTER_STAT_NAMES:
		if int(after.get(stat_name, 0)) != mini(int(before.get(stat_name, 0)) + int(bonuses.get(stat_name, 0)), 100):
			return false
	return true


func _semantic(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(occurrence.get("semantic_event", "")) == name:
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
	EventManager.semantic_trigger_dispatched.connect(_on_semantic_trigger_dispatched)
	EducationManager.education_event_requested.connect(_on_legacy_education_requested)
	EducationManager.major_selection_requested.connect(_on_legacy_major_requested)


func _disconnect_capture_signals() -> void:
	EventManager.semantic_trigger_dispatched.disconnect(_on_semantic_trigger_dispatched)
	EducationManager.education_event_requested.disconnect(_on_legacy_education_requested)
	EducationManager.major_selection_requested.disconnect(_on_legacy_major_requested)


func _on_semantic_trigger_dispatched(occurrence: Dictionary) -> void:
	semantic_occurrences.append(occurrence.duplicate(true))


func _on_legacy_education_requested(character_id: int, event_type: String, education_stage: String) -> void:
	legacy_requests.append({"character_id":character_id,"event_type":event_type,"education_stage":education_stage})


func _on_legacy_major_requested(character_id: int) -> void:
	legacy_major_requests.append(character_id)


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
