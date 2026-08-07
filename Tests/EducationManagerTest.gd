extends Node

var passed: int = 0
var failed: int = 0

var _saved_characters: Array = []
var _saved_next_character_id: int = 1
var _saved_money: int = 0
var _saved_day: int = 1
var _saved_month: int = 1
var _saved_year: int = 1985
var _saved_paused: bool = false


func _ready() -> void:
	print("")
	print("========================================")
	print("EducationManager backend tests starting")
	print("========================================")

	_save_runtime_state()
	_run_all_tests()
	_restore_runtime_state()

	print("")
	print("========================================")
	print("Education tests: ", passed, " passed / ", failed, " failed")
	print("========================================")

	if failed == 0:
		print("ALL EDUCATION TESTS PASSED.")
	else:
		push_error("Education backend has %d failing test(s)." % failed)


func _run_all_tests() -> void:
	_test_primary_birthday_event()
	_test_paid_school_affordability()
	_test_paid_school_cost_and_bonus()
	_test_stat_bonus_cap()
	_test_primary_to_middle_transition()
	_test_middle_to_high_transition()
	_test_high_to_university_transition()
	_test_university_decline()
	_test_normal_major_priority()
	_test_fallback_major_only_when_needed()
	_test_three_year_major_immediate_graduation()
	_test_long_major_graduation_date()
	_test_same_day_queue_order()
	_test_duplicate_event_protection()
	_test_pause_resume_when_time_was_running()
	_test_pause_stays_when_time_was_already_paused()
	_test_event_log_has_no_irrelevant_null_ids()


func _save_runtime_state() -> void:
	_saved_characters = CharacterManager.characters.duplicate(true)
	_saved_next_character_id = CharacterManager.next_character_id
	_saved_money = GameManager.family_money
	_saved_day = TimeManager.current_day
	_saved_month = TimeManager.current_month
	_saved_year = TimeManager.current_year
	_saved_paused = TimeManager.is_paused


func _restore_runtime_state() -> void:
	CharacterManager.characters = _saved_characters
	CharacterManager.next_character_id = _saved_next_character_id
	GameManager.set_family_money(_saved_money)
	TimeManager.current_day = _saved_day
	TimeManager.current_month = _saved_month
	TimeManager.current_year = _saved_year
	TimeManager.is_paused = _saved_paused
	_reset_education_runtime_state()


func _reset_test_world() -> void:
	CharacterManager.characters = []
	CharacterManager.next_character_id = 1
	GameManager.set_family_money(15000)
	_set_date(26, 1, 1985)
	TimeManager.is_paused = false
	_reset_education_runtime_state()


func _reset_education_runtime_state() -> void:
	EducationManager.education_event_queue.clear()
	EducationManager.current_education_event = {}
	EducationManager.is_education_event_active = false
	EducationManager.is_education_pause_active = false
	EducationManager.should_resume_time_after_education_events = false


func _set_date(day: int, month: int, year: int) -> void:
	TimeManager.current_day = day
	TimeManager.current_month = month
	TimeManager.current_year = year


func _make_character(character_id: int, birth_date: String, stats_value: int = 50) -> Dictionary:
	var character: Dictionary = {
		"character_id": character_id,
		"name": "Test %d" % character_id,
		"gender": "female",
		"birth_date": birth_date,
		"is_alive": true,
		"is_player_family": true,
		"health": stats_value,
		"happiness": stats_value,
		"logic": stats_value,
		"attractiveness": stats_value,
		"social": stats_value,
		"confidence": stats_value,
		"discipline": stats_value,
		"creativity": stats_value,
		"school_id": null,
		"major_id": null,
		"education_status": "none",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": null,
		"event_log": []
	}
	CharacterManager.characters.append(character)
	return character


func _set_active_event(character_id: int, event_type: String, education_stage: String) -> void:
	EducationManager.current_education_event = {
		"character_id": character_id,
		"event_type": event_type,
		"education_stage": education_stage
	}
	EducationManager.is_education_event_active = true


func _find_school_id(stage: String, school_type: String) -> int:
	for school_value in EducationManager.get_schools_for_stage(stage):
		if typeof(school_value) != TYPE_DICTIONARY:
			continue
		var school: Dictionary = school_value
		if String(school.get("school_type", "")) == school_type:
			return int(school.get("school_id", 0))
	return 0


func _find_major_with_duration(duration_years: int, include_fallback: bool = false) -> Dictionary:
	for major_value in CharacterManager.majors:
		if typeof(major_value) != TYPE_DICTIONARY:
			continue
		var major: Dictionary = major_value
		if not include_fallback and bool(major.get("is_fallback", false)):
			continue
		if int(major.get("duration_years", 0)) == duration_years:
			return major
	return {}


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _test_primary_birthday_event() -> void:
	_reset_test_world()
	var character := _make_character(1, "1979-01-26")
	var event_data := EducationManager.get_birthday_education_event(character)
	_assert_true(
		String(event_data.get("event_type", "")) == "school_enrollment"
		and String(event_data.get("education_stage", "")) == "primary_school",
		"Age 6 creates Primary School enrollment event"
	)


func _test_paid_school_affordability() -> void:
	_reset_test_world()
	var character := _make_character(1, "1979-01-26")
	var private_school_id := _find_school_id("primary_school", "private")
	GameManager.set_family_money(0)
	_set_active_event(1, "school_enrollment", "primary_school")
	var result := EducationManager.enroll_character_in_school(1, private_school_id)
	_assert_true(
		not result and character.get("school_id", null) == null and GameManager.family_money == 0,
		"Paid school is rejected when family cannot afford it"
	)


func _test_paid_school_cost_and_bonus() -> void:
	_reset_test_world()
	var character := _make_character(1, "1979-01-26", 50)
	var private_school_id := _find_school_id("primary_school", "private")
	var school := EducationManager.get_school_by_id(private_school_id)
	var cost := int(school.get("base_cost", 0))
	var logic_before := int(character.get("logic", 0))
	var logic_bonus := int(school.get("stat_bonus", {}).get("logic", 0))
	GameManager.set_family_money(15000)
	_set_active_event(1, "school_enrollment", "primary_school")
	var result := EducationManager.enroll_character_in_school(1, private_school_id)
	_assert_true(
		result
		and GameManager.family_money == 15000 - cost
		and int(character.get("logic", 0)) == logic_before + logic_bonus,
		"Paid enrollment deducts cost and applies school bonus once"
	)


func _test_stat_bonus_cap() -> void:
	_reset_test_world()
	var character := _make_character(1, "1979-01-26", 99)
	var prestige_school_id := _find_school_id("primary_school", "prestige")
	GameManager.set_family_money(100000)
	_set_active_event(1, "school_enrollment", "primary_school")
	var result := EducationManager.enroll_character_in_school(1, prestige_school_id)
	var all_capped := true
	for stat_name in CharacterManager.CHARACTER_STAT_NAMES:
		if int(character.get(stat_name, 0)) > 100:
			all_capped = false
	_assert_true(result and all_capped, "School bonuses never increase stats above 100")


func _test_primary_to_middle_transition() -> void:
	_reset_test_world()
	var character := _make_character(1, "1973-01-26")
	character["school_id"] = _find_school_id("primary_school", "public")
	character["education_status"] = "studying"
	EducationManager.education_event_queue.append({
		"character_id": 1,
		"event_type": "school_transition",
		"education_stage": "middle_school"
	})
	EducationManager.request_next_education_event()
	_assert_true(
		String(character.get("education_status", "")) == "graduated"
		and String(character.get("graduation_date", "")) == TimeManager.get_iso_date_string(),
		"Primary graduation happens when Middle transition becomes active"
	)


func _test_middle_to_high_transition() -> void:
	_reset_test_world()
	var character := _make_character(1, "1970-01-26")
	character["school_id"] = _find_school_id("middle_school", "public")
	character["education_status"] = "studying"
	EducationManager.education_event_queue.append({
		"character_id": 1,
		"event_type": "school_transition",
		"education_stage": "high_school"
	})
	EducationManager.request_next_education_event()
	_assert_true(String(character.get("education_status", "")) == "graduated", "Middle graduation happens when High transition becomes active")


func _test_high_to_university_transition() -> void:
	_reset_test_world()
	var character := _make_character(1, "1967-01-26")
	character["school_id"] = _find_school_id("high_school", "public")
	character["education_status"] = "studying"
	EducationManager.education_event_queue.append({
		"character_id": 1,
		"event_type": "university_choice",
		"education_stage": "university"
	})
	EducationManager.request_next_education_event()
	_assert_true(String(character.get("education_status", "")) == "graduated", "High School graduation happens when University choice becomes active")


func _test_university_decline() -> void:
	_reset_test_world()
	var character := _make_character(1, "1967-01-26")
	_set_active_event(1, "university_choice", "university")
	var result := EducationManager.decline_university(1)
	_assert_true(
		result and not EducationManager.is_education_event_active and character.get("major_id", null) == null,
		"University decline resolves the active event without assigning a major"
	)


func _test_normal_major_priority() -> void:
	_reset_test_world()
	var character := _make_character(1, "1964-01-26", 100)
	character["school_id"] = _find_school_id("university", "public")
	character["education_status"] = "studying"
	var available := EducationManager.get_available_majors_for_character(1)
	var has_normal := false
	var has_fallback := false
	for major_value in available:
		if typeof(major_value) != TYPE_DICTIONARY:
			continue
		var major: Dictionary = major_value
		if bool(major.get("is_fallback", false)):
			has_fallback = true
		else:
			has_normal = true
	_assert_true(has_normal and not has_fallback, "Eligible normal majors are offered without fallback majors")


func _test_fallback_major_only_when_needed() -> void:
	_reset_test_world()
	var character := _make_character(1, "1964-01-26", 0)
	character["school_id"] = _find_school_id("university", "public")
	character["education_status"] = "studying"
	var available := EducationManager.get_available_majors_for_character(1)
	var all_fallback := not available.is_empty()
	for major_value in available:
		if typeof(major_value) != TYPE_DICTIONARY:
			all_fallback = false
			continue
		var major: Dictionary = major_value
		if not bool(major.get("is_fallback", false)):
			all_fallback = false
	_assert_true(all_fallback, "Fallback majors are used only when no normal major is eligible")


func _test_three_year_major_immediate_graduation() -> void:
	_reset_test_world()
	var character := _make_character(1, "1964-01-26", 0)
	character["school_id"] = _find_school_id("university", "public")
	character["education_status"] = "studying"
	character["education_start_date"] = "1982-01-26"
	var major := _find_major_with_duration(3, true)
	var major_id := int(major.get("major_id", 0))
	_set_active_event(1, "major_selection", "university")
	var result := EducationManager.select_major(1, major_id)
	_assert_true(
		result
		and String(character.get("education_status", "")) == "graduated"
		and String(character.get("graduation_date", "")) == TimeManager.get_iso_date_string(),
		"Three-year fallback major graduates immediately when selected at age 21"
	)


func _test_long_major_graduation_date() -> void:
	_reset_test_world()
	var character := _make_character(1, "1964-01-26", 100)
	character["school_id"] = _find_school_id("university", "public")
	character["education_status"] = "studying"
	character["education_start_date"] = "1982-01-26"
	var major := _find_major_with_duration(4)
	if major.is_empty():
		_assert_true(false, "Four-year major test data exists")
		return
	var major_id := int(major.get("major_id", 0))
	_set_active_event(1, "major_selection", "university")
	var selected := EducationManager.select_major(1, major_id)
	var expected_date := String(character.get("expected_graduation_date", ""))
	var stayed_student := String(character.get("education_status", "")) == "studying"
	_set_date(26, 1, 1986)
	EducationManager.check_university_graduations()
	_assert_true(
		selected
		and expected_date == "1986-01-26"
		and stayed_student
		and String(character.get("education_status", "")) == "graduated",
		"Four-year major graduates on the expected age-22 birthday"
	)


func _test_same_day_queue_order() -> void:
	_reset_test_world()
	_make_character(9, "1979-01-26")
	_make_character(2, "1979-01-26")
	_make_character(5, "1979-01-26")
	EducationManager.check_birthday_education_events()
	var active_id := int(EducationManager.current_education_event.get("character_id", 0))
	var queued_ids: Array[int] = []
	for event_value in EducationManager.education_event_queue:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		queued_ids.append(int(event_value.get("character_id", 0)))
	_assert_true(active_id == 2 and queued_ids == [5, 9], "Same-day education events are processed in character-ID order")


func _test_duplicate_event_protection() -> void:
	_reset_test_world()
	_make_character(1, "1979-01-26")
	EducationManager.check_birthday_education_events()
	var first_total := EducationManager.education_event_queue.size() + (1 if EducationManager.is_education_event_active else 0)
	EducationManager.check_birthday_education_events()
	var second_total := EducationManager.education_event_queue.size() + (1 if EducationManager.is_education_event_active else 0)
	_assert_true(first_total == 1 and second_total == 1, "Duplicate education event is not queued twice")


func _test_pause_resume_when_time_was_running() -> void:
	_reset_test_world()
	_make_character(1, "1979-01-26")
	TimeManager.is_paused = false
	EducationManager.check_birthday_education_events()
	var paused_during_event := TimeManager.is_paused
	EducationManager.complete_current_education_event()
	_assert_true(paused_during_event and not TimeManager.is_paused, "Time pauses for education event and resumes when it was previously running")


func _test_pause_stays_when_time_was_already_paused() -> void:
	_reset_test_world()
	_make_character(1, "1979-01-26")
	TimeManager.is_paused = true
	EducationManager.check_birthday_education_events()
	EducationManager.complete_current_education_event()
	_assert_true(TimeManager.is_paused, "Time remains paused after education queue when player had already paused")


func _test_event_log_has_no_irrelevant_null_ids() -> void:
	_reset_test_world()
	var character := _make_character(1, "1979-01-26")
	var public_school_id := _find_school_id("primary_school", "public")
	_set_active_event(1, "school_enrollment", "primary_school")
	var result := EducationManager.enroll_character_in_school(1, public_school_id)
	var event_log: Array = character.get("event_log", [])
	var clean_log := false
	if result and event_log.size() == 1 and typeof(event_log[0]) == TYPE_DICTIONARY:
		var log_entry: Dictionary = event_log[0]
		clean_log = log_entry.has("school_id") and not log_entry.has("major_id")
	_assert_true(clean_log, "Education event log omits irrelevant null major_id")
