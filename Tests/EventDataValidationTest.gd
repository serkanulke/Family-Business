extends Node


const ITEM_ID := "accessory_common_black_gold_browline_sunglasses_007"

var passed := 0
var failed := 0


func _ready() -> void:
	print("")
	print("========================================")
	print("Event Phase 1 static data tests starting")
	print("========================================")

	_run_all_tests()

	print("")
	print("========================================")
	print("Event Phase 1 tests: ", passed, " passed / ", failed, " failed")
	print("========================================")

	if failed == 0:
		print("ALL EVENT PHASE 1 TESTS PASSED.")
	else:
		push_error("Event Phase 1 has %d failing test(s)." % failed)

	get_tree().quit(0 if failed == 0 else 1)


func _run_all_tests() -> void:
	_test_all_production_category_files_load()
	_test_valid_registry_lookups()
	_test_category_file_mismatch()
	_test_unsupported_schema_version()
	_test_malformed_and_root_invalid_json()
	_test_duplicate_event_id_across_files()
	_test_duplicate_choice_and_outcome_ids()
	_test_pool_validation()
	_test_trigger_validation()
	_test_calendar_exact_date_and_window_validation()
	_test_optional_metadata_validation()
	_test_participant_validation()
	_test_requirement_validation()
	_test_repeat_and_cooldown_validation()
	_test_family_agency_cooldown_rule()
	_test_presentation_and_cost_validation()
	_test_resolution_validation()
	_test_effect_validation()
	_test_event_flow_references_and_cycles()
	_test_job_event_tags_schema()
	_test_complete_effect_whitelist_and_score_check()
	_test_all_trigger_repeat_and_cooldown_constructs()
	_test_all_requirement_constructs()


func _test_all_production_category_files_load() -> void:
	var registry := EventDataRegistry.new()
	var loaded := registry.load_all()
	_assert_true(
		loaded
		and registry.is_valid
		and registry.files_by_category.size() == 12
		and registry.events_by_id.is_empty()
		and registry.pools_by_id.is_empty(),
		"All 12 empty production category files load successfully",
		registry.get_diagnostic_text()
	)

	var all_categories_indexed := true
	for category in EventDataRegistry.CATEGORY_FILES:
		if not registry.events_by_category.has(category):
			all_categories_indexed = false
			break
	_assert_true(
		all_categories_indexed,
		"Empty production categories still receive category lookups"
	)


func _test_valid_registry_lookups() -> void:
	var event := _base_event("registry_event", "general")
	event["pool_id"] = "general_pool"
	var registry := _registry_for(
		"general",
		[event],
		[{
			"pool_id": "general_pool",
			"selection_mode": "weighted_one",
			"max_events": 1
		}]
	)
	_assert_true(
		registry.is_valid
		and registry.get_event("registry_event").get("event_id", "") == "registry_event"
		and registry.get_pool("general_pool").get("category", "") == "general"
		and registry.get_events_for_category("general").size() == 1
		and registry.get_events_for_pool("general_pool").size() == 1,
		"Valid registry exposes event, category, and pool lookups",
		registry.get_diagnostic_text()
	)


func _test_category_file_mismatch() -> void:
	var document := _document("general", [])
	document["category"] = "health"
	_expect_invalid_sources(
		{"general.json": JSON.stringify(document)},
		"Category/file mismatch is rejected",
		"does not match filename category"
	)


func _test_unsupported_schema_version() -> void:
	var document := _document("general", [])
	document["schema_version"] = 2
	_expect_invalid_sources(
		{"general.json": JSON.stringify(document)},
		"Unsupported schema version is rejected",
		"Unsupported schema_version"
	)


func _test_malformed_and_root_invalid_json() -> void:
	_expect_invalid_sources(
		{"general.json": "{ invalid json"},
		"Malformed Event JSON is rejected safely",
		"Malformed JSON"
	)
	_expect_invalid_sources(
		{"general.json": "[]"},
		"Non-Dictionary Event root is rejected",
		"root must be a Dictionary"
	)
	var document := _document("general", [])
	document.erase("pools")
	_expect_invalid_sources(
		{"general.json": JSON.stringify(document)},
		"Missing/invalid root structure is rejected",
		"Required root member is missing"
	)


func _test_duplicate_event_id_across_files() -> void:
	var general_event := _base_event("duplicate_global", "general")
	var health_event := _base_event("duplicate_global", "health")
	_expect_invalid_sources(
		{
			"general.json": JSON.stringify(_document("general", [general_event])),
			"health.json": JSON.stringify(_document("health", [health_event]))
		},
		"Duplicate event_id across category files is rejected",
		"Duplicate global event_id"
	)


func _test_duplicate_choice_and_outcome_ids() -> void:
	var duplicate_choice := _base_event("duplicate_choice", "general")
	duplicate_choice["choices"].append(duplicate_choice["choices"][0].duplicate(true))
	_expect_invalid_event(
		duplicate_choice,
		"Duplicate choice_id inside an Event is rejected",
		"Duplicate choice_id"
	)

	var duplicate_outcome := _base_event("duplicate_outcome", "general")
	duplicate_outcome["choices"][0]["resolution"] = {
		"mode": "weighted",
		"outcomes": [
			{"outcome_id": "same", "weight": 1, "effects": []},
			{"outcome_id": "same", "weight": 1, "effects": []}
		]
	}
	_expect_invalid_event(
		duplicate_outcome,
		"Duplicate outcome_id inside a resolution is rejected",
		"Duplicate outcome_id"
	)


func _test_pool_validation() -> void:
	var missing_pool := _base_event("missing_pool", "general")
	missing_pool["pool_id"] = "does_not_exist"
	_expect_invalid_event(
		missing_pool,
		"Missing pool reference is rejected",
		"does not exist"
	)

	var bad_mode_registry := _registry_for(
		"general",
		[],
		[{"pool_id": "bad", "selection_mode": "random", "max_events": 1}]
	)
	_assert_invalid(
		bad_mode_registry,
		"Unsupported pool selection mode is rejected",
		"Unsupported pool selection_mode"
	)

	var bad_max_registry := _registry_for(
		"general",
		[],
		[{"pool_id": "bad_max", "selection_mode": "weighted_multiple", "max_events": 0}]
	)
	_assert_invalid(
		bad_max_registry,
		"Invalid pool max_events is rejected",
		"max_events must be a positive integer"
	)


func _test_trigger_validation() -> void:
	var bad_type := _base_event("bad_trigger", "general")
	bad_type["trigger"] = {"type": "signal"}
	_expect_invalid_event(
		bad_type,
		"Unsupported trigger type is rejected",
		"Unsupported trigger type"
	)

	var bad_cadence := _base_event("bad_cadence", "general")
	bad_cadence["trigger"] = {
		"type": "calendar",
		"cadence": {"unit": "quarter", "interval": 0}
	}
	var registry := _registry_for("general", [bad_cadence])
	_assert_true(
		not registry.is_valid
		and _diagnostics_contain(registry, "Unsupported calendar cadence unit")
		and _diagnostics_contain(registry, "interval must be a positive integer"),
		"Invalid calendar cadence unit and interval are rejected",
		registry.get_diagnostic_text()
	)

	var bad_manual := _base_event("bad_manual", "general")
	bad_manual["trigger"] = {
		"type": "manual",
		"source": "relationship",
		"mode": "pool"
	}
	_expect_invalid_event(
		bad_manual,
		"Manual pool trigger requires pool_id",
		"Required value must be a non-empty String"
	)

	var direct_with_pool := _base_event("direct_with_pool", "general")
	direct_with_pool["trigger"] = {
		"type": "manual",
		"source": "lifestyle",
		"mode": "direct",
		"pool_id": "unexpected"
	}
	_expect_invalid_event(
		direct_with_pool,
		"Direct manual trigger rejects a pool reference",
		"must not reference a pool"
	)


func _test_calendar_exact_date_and_window_validation() -> void:
	var exact := _base_event("exact_date", "general")
	exact["trigger"] = {
		"type": "calendar",
		"exact_date": {"month": 1, "day": 1}
	}
	var window := _base_event("date_window", "general")
	window["trigger"] = {
		"type": "calendar",
		"date_window": {
			"start": {"month": 12, "day": 20},
			"end": {"month": 1, "day": 5}
		}
	}
	var valid_registry := _registry_for("general", [exact, window])
	_assert_true(
		valid_registry.is_valid,
		"Valid annual exact-date and calendar-window structures load",
		valid_registry.get_diagnostic_text()
	)

	var invalid := _base_event("invalid_date_window", "general")
	invalid["trigger"] = {
		"type": "calendar",
		"date_window": {
			"start": {"month": 13, "day": 1},
			"end": "January"
		}
	}
	_expect_invalid_event(
		invalid,
		"Malformed exact-date/date-window structure is rejected",
		"Date month must be an integer from 1 to 12"
	)

	var impossible_annual := _base_event("impossible_annual_date", "general")
	impossible_annual["trigger"] = {
		"type": "calendar",
		"exact_date": {"month": 4, "day": 31}
	}
	_expect_invalid_event(
		impossible_annual,
		"Impossible annual calendar date is rejected",
		"Date day is not valid for the selected month"
	)

	var impossible_iso := _base_event("impossible_iso_date", "general")
	impossible_iso["trigger"] = {
		"type": "calendar",
		"exact_date": "2025-02-29"
	}
	_expect_invalid_event(
		impossible_iso,
		"Impossible ISO calendar date is rejected",
		"Date day is not valid for the selected month"
	)


func _test_optional_metadata_validation() -> void:
	var valid := _base_event("valid_metadata", "general")
	valid["metadata"] = {"authoring_note": "Static data only"}
	var valid_registry := _registry_for("general", [valid])
	_assert_true(
		valid_registry.is_valid,
		"Optional Event metadata Dictionary is accepted",
		valid_registry.get_diagnostic_text()
	)

	var invalid := _base_event("invalid_metadata", "general")
	invalid["metadata"] = "not-a-dictionary"
	_expect_invalid_event(
		invalid,
		"Non-Dictionary Event metadata is rejected",
		"metadata must be a Dictionary"
	)


func _test_participant_validation() -> void:
	var bad_group := _base_event("bad_group", "general")
	bad_group["participants"]["travel_group"] = {
		"type": "character_group",
		"source": "player_selected",
		"min": 5,
		"max": 3,
		"selection_ui": {
			"title": "Travel group",
			"description": "Select family members",
			"show_ineligible": true,
			"show_relevant_stats": ["health"]
		}
	}
	_expect_invalid_event(
		bad_group,
		"Participant group min greater than max is rejected",
		"min must not exceed max"
	)

	var bad_relation := _base_event("bad_relation", "general")
	bad_relation["participants"]["target"] = {
		"type": "character",
		"source": "relation",
		"relation": "neighbor",
		"from": "missing"
	}
	var registry := _registry_for("general", [bad_relation])
	_assert_true(
		not registry.is_valid
		and _diagnostics_contain(registry, "Unsupported relation")
		and _diagnostics_contain(registry, "does not exist"),
		"Structurally invalid participant relation references are rejected",
		registry.get_diagnostic_text()
	)

	var bad_ui := _base_event("bad_selection_ui", "general")
	bad_ui["participants"]["travel_group"] = {
		"type": "character_group",
		"source": "player_selected",
		"min": 1,
		"max": 2,
		"selection_ui": {"title": "Select", "description": "Pick", "show_ineligible": "yes"}
	}
	_expect_invalid_event(
		bad_ui,
		"Malformed participant selection_ui is rejected",
		"show_ineligible must be a bool"
	)


func _test_requirement_validation() -> void:
	var unsupported := _base_event("bad_requirement", "general")
	unsupported["requirements"] = {
		"all": [{"type": "favorite_color", "target": "primary", "operator": "==", "value": "blue"}]
	}
	_expect_invalid_event(
		unsupported,
		"Unsupported requirement type is rejected",
		"Unsupported requirement type"
	)

	for removed_type in [
		"career_level", "education_level", "relationship_exists",
		"relationship_status", "relationship_level"
	]:
		var removed := _base_event("removed_requirement_%s" % removed_type, "general")
		removed["requirements"] = {"all": [{
			"type": removed_type,
			"target": "primary",
			"operator": "==",
			"value": 0
		}]}
		_expect_invalid_event(
			removed,
			"D-156/D-157 rejects removed requirement %s" % removed_type,
			"Unsupported requirement type"
		)

	var recursive := _base_event("bad_recursive", "general")
	recursive["requirements"] = {"all": {"type": "age"}}
	_expect_invalid_event(
		recursive,
		"Invalid recursive requirement structure is rejected",
		"must be an Array"
	)

	var stat := _base_event("bad_stat", "general")
	stat["requirements"] = {
		"all": [{"type": "stat", "target": "primary", "stat": "strength", "operator": ">=", "value": 50}]
	}
	_expect_invalid_event(
		stat,
		"Unknown canonical stat name is rejected",
		"Unknown canonical stat"
	)

	var operator := _base_event("bad_operator", "general")
	operator["requirements"] = {
		"all": [{"type": "gender", "target": "primary", "operator": ">", "value": "female"}]
	}
	_expect_invalid_event(
		operator,
		"Incompatible requirement operator is rejected",
		"does not support numeric comparison"
	)

	var invalid_reference := _base_event("bad_reference", "general")
	invalid_reference["requirements"] = {
		"all": [{"type": "job", "target": "primary", "operator": "==", "value": 999999}]
	}
	_expect_invalid_event(
		invalid_reference,
		"Unknown statically resolvable data reference is rejected",
		"Unknown job_id reference"
	)


func _test_repeat_and_cooldown_validation() -> void:
	var bad_repeat := _base_event("bad_repeat", "general")
	bad_repeat["repeat"] = {"mode": "daily"}
	_expect_invalid_event(bad_repeat, "Invalid repeat mode is rejected", "Unsupported repeat mode")

	for case in [
		{"name": "Invalid cooldown scope is rejected", "cooldown": {"scope": "global", "unit": "month", "value": 1}, "message": "Unsupported cooldown scope"},
		{"name": "Invalid cooldown unit is rejected", "cooldown": {"scope": "event", "unit": "hour", "value": 1}, "message": "Unsupported cooldown unit"},
		{"name": "Invalid cooldown value is rejected", "cooldown": {"scope": "event", "unit": "month", "value": 0}, "message": "positive integer"}
	]:
		var event := _base_event("cooldown_%s" % passed, "general")
		event["cooldown"] = case["cooldown"]
		_expect_invalid_event(event, case["name"], case["message"])


func _test_family_agency_cooldown_rule() -> void:
	var month_event := _base_event("agency_60_months", "family_agency")
	month_event["cooldown"] = {"scope": "event", "unit": "month", "value": 60}
	var month_registry := _registry_for("family_agency", [month_event])
	_assert_true(month_registry.is_valid, "Family Agency 60-month event cooldown is valid", month_registry.get_diagnostic_text())

	var year_event := _base_event("agency_5_years", "family_agency")
	year_event["cooldown"] = {"scope": "event", "unit": "year", "value": 5}
	var year_registry := _registry_for("family_agency", [year_event])
	_assert_true(year_registry.is_valid, "Family Agency 5-year event cooldown is valid", year_registry.get_diagnostic_text())

	var below := _base_event("agency_below", "family_agency")
	below["cooldown"] = {"scope": "event", "unit": "month", "value": 59}
	_expect_invalid_event(below, "Family Agency cooldown below 60 months is rejected", "at least 60 calendar months", "family_agency")

	var wrong_scope := _base_event("agency_family_scope", "family_agency")
	wrong_scope["cooldown"] = {"scope": "family", "unit": "year", "value": 10}
	_expect_invalid_event(wrong_scope, "Family Agency global/family cooldown is rejected", "must use event scope", "family_agency")

	var no_cooldown := _base_event("agency_none", "family_agency")
	no_cooldown["cooldown"] = null
	_expect_invalid_event(no_cooldown, "Family Agency Event without cooldown is rejected", "requires its own event-scoped cooldown", "family_agency")

	var days := _base_event("agency_days", "family_agency")
	days["cooldown"] = {"scope": "event", "unit": "day", "value": 1825}
	_expect_invalid_event(days, "Arbitrary day count is not treated as 60 calendar months", "day/week conversions are not accepted", "family_agency")


func _test_presentation_and_cost_validation() -> void:
	var presentation := _base_event("bad_presentation", "general")
	presentation["presentation"] = {
		"template": "",
		"art_path": "res://missing/event_art.png",
		"padding": 24
	}
	var presentation_registry := _registry_for("general", [presentation])
	_assert_true(
		not presentation_registry.is_valid
		and _diagnostics_contain(presentation_registry, "Required value must be a non-empty String")
		and _diagnostics_contain(presentation_registry, "Referenced resource does not exist")
		and _diagnostics_contain(presentation_registry, "UI geometry/style belongs in scenes"),
		"Invalid presentation/resource/scene-geometry structure is rejected",
		presentation_registry.get_diagnostic_text()
	)

	var cost := _base_event("bad_cost", "general")
	cost["choices"][0]["cost"] = {"currency": "stars", "amount": 10}
	_expect_invalid_event(cost, "Invalid cost currency is rejected", "money or diamonds")

	var negative_cost := _base_event("negative_cost", "general")
	negative_cost["cost"] = {"currency": "money", "amount": -1}
	_expect_invalid_event(negative_cost, "Negative Event cost is rejected", "non-negative number")


func _test_resolution_validation() -> void:
	var mode := _base_event("bad_resolution_mode", "general")
	mode["choices"][0]["resolution"] = {"mode": "random", "effects": []}
	_expect_invalid_event(mode, "Invalid resolution mode is rejected", "Unsupported resolution mode")

	var weighted := _base_event("bad_weighted", "general")
	weighted["choices"][0]["resolution"] = {
		"mode": "weighted",
		"outcomes": [{
			"outcome_id": "bad",
			"weight": 0,
			"weight_modifiers": [{"requirements": {"all": []}, "add_weight": "more"}],
			"effects": "not-an-array"
		}]
	}
	var registry := _registry_for("general", [weighted])
	_assert_true(
		not registry.is_valid
		and _diagnostics_contain(registry, "weight must be positive")
		and _diagnostics_contain(registry, "add_weight must be numeric")
		and _diagnostics_contain(registry, "effects must be an Array"),
		"Invalid weighted outcome weight/modifier/effects structure is rejected",
		registry.get_diagnostic_text()
	)


func _test_effect_validation() -> void:
	var unsupported := _base_event("bad_effect", "general")
	unsupported["choices"][0]["resolution"]["effects"] = [{"type": "run_method", "method": "cheat"}]
	var unsupported_registry := _registry_for("general", [unsupported])
	_assert_true(
		not unsupported_registry.is_valid
		and _diagnostics_contain(unsupported_registry, "Unsupported effect type")
		and _diagnostics_contain(unsupported_registry, "Executable code/method references are forbidden"),
		"Unsupported effect and arbitrary method name are rejected",
		unsupported_registry.get_diagnostic_text()
	)

	var target := _base_event("bad_effect_target", "general")
	target["choices"][0]["resolution"]["effects"] = [{
		"type": "stat_change",
		"target": "missing_character",
		"stat": "health",
		"amount": 5
	}]
	_expect_invalid_event(target, "Invalid effect participant target is rejected", "not a defined participant/context")

	var reference := _base_event("bad_effect_reference", "general")
	reference["choices"][0]["resolution"]["effects"] = [{
		"type": "education_enroll",
		"target": "primary",
		"school_id": 999999
	}]
	_expect_invalid_event(reference, "Invalid effect data reference is rejected", "Unknown school_id reference")

	var bad_feedback_mode := _base_event("bad_effect_feedback_mode", "general")
	bad_feedback_mode["choices"][0]["resolution"]["effects"] = [{"type":"money_change","amount":1,"feedback":{"mode":"silent"}}]
	_expect_invalid_event(bad_feedback_mode, "Unsupported effect feedback mode is rejected", "feedback mode must be auto or custom")

	var missing_custom_text := _base_event("missing_custom_feedback_text", "general")
	missing_custom_text["choices"][0]["resolution"]["effects"] = [{"type":"money_change","amount":1,"feedback":{"mode":"custom","text":""}}]
	_expect_invalid_event(missing_custom_text, "Custom effect feedback requires player-facing text", "custom feedback requires player-facing text")

	var valid_custom_feedback := _base_event("valid_custom_feedback", "general")
	valid_custom_feedback["choices"][0]["resolution"]["effects"] = [{"type":"add_flag","target":"primary","flag_id":1001,"feedback":{"mode":"custom","text":"A story state changed.","icon_path":null}}]
	var feedback_registry := _registry_for("general", [valid_custom_feedback])
	_assert_true(feedback_registry.is_valid, "Valid custom effect feedback is accepted", feedback_registry.get_diagnostic_text())

	var leaking_flag_feedback := _base_event("leaking_flag_feedback", "general")
	leaking_flag_feedback["choices"][0]["resolution"]["effects"] = [{"type":"add_flag","target":"primary","flag_id":1001,"feedback":{"mode":"custom","text":"Flag 1001 gained."}}]
	_expect_invalid_event(leaking_flag_feedback, "Custom feedback cannot expose an internal flag ID", "must not expose the internal flag_id")

	var timed_flag := _base_event("unsupported_timed_flag", "general")
	timed_flag["choices"][0]["resolution"]["effects"] = [{
		"type": "add_flag",
		"target": "primary",
		"flag_id": 1001,
		"duration": {"unit": "month", "value": 1}
	}]
	_expect_invalid_event(
		timed_flag,
		"Event-owned temporary flag duration is rejected",
		"add_flag does not support duration"
	)

	var generic_business := _base_event("unsupported_generic_business_effect", "business")
	generic_business["participants"]["business"] = {"type": "business", "source": "owned_business"}
	generic_business["choices"][0]["resolution"]["effects"] = [{
		"type": "business_effect",
		"business": "business",
		"effect": "approved_domain_operation"
	}]
	_expect_invalid_event(
		generic_business,
		"D-154 rejects the removed generic business_effect",
		"Unsupported effect type",
		"business"
	)

	var damage_item := _base_event("unsupported_damage_item_effect", "general")
	damage_item["choices"][0]["resolution"]["effects"] = [{
		"type": "damage_item",
		"target": "primary",
		"item_id": ITEM_ID,
		"amount": 1
	}]
	_expect_invalid_event(
		damage_item,
		"D-155 rejects the removed damage_item effect",
		"Unsupported effect type"
	)

	for removed_effect_type in [
		"relationship_start", "relationship_change",
		"relationship_status_change", "relationship_end", "job_assign",
		"job_change", "career_progress", "education_change",
		"education_complete", "house_assignment", "business_role_change"
	]:
		var removed_effect := _base_event("removed_effect_%s" % removed_effect_type, "general")
		removed_effect["choices"][0]["resolution"]["effects"] = [{
			"type": removed_effect_type
		}]
		_expect_invalid_event(
			removed_effect,
			"D-156/D-157 rejects removed effect %s" % removed_effect_type,
			"Unsupported effect type"
		)


func _test_event_flow_references_and_cycles() -> void:
	var missing := _base_event("missing_event_target", "general")
	missing["choices"][0]["resolution"]["effects"] = [{
		"type": "schedule_event",
		"event_id": "not_found",
		"delay": {"unit": "month", "value": 1}
	}]
	_expect_invalid_event(missing, "Missing queued/scheduled Event target is rejected", "does not exist")

	var event_a := _base_event("cycle_a", "general")
	var event_b := _base_event("cycle_b", "general")
	event_a["choices"][0]["resolution"]["effects"] = [{"type": "queue_event", "event_id": "cycle_b"}]
	event_b["choices"][0]["resolution"]["effects"] = [{"type": "schedule_event", "event_id": "cycle_a", "delay": {"unit": "day", "value": 1}}]
	var cycle_registry := _registry_for("general", [event_a, event_b])
	_assert_invalid(cycle_registry, "Statically detectable Event chain cycle is rejected", "circular Event queue/schedule chain")

	var self_cycle := _base_event("self_cycle", "general")
	self_cycle["choices"][0]["resolution"]["effects"] = [{"type": "queue_event", "event_id": "self_cycle"}]
	_expect_invalid_event(self_cycle, "Direct self-queue chain is rejected", "circular Event queue/schedule chain")


func _test_job_event_tags_schema() -> void:
	var absent_validator := EventDataValidator.new()
	_assert_true(
		absent_validator.validate_job_records([{"job_id": 1}]),
		"Optional Job event_tags may be absent"
	)

	var present_validator := EventDataValidator.new()
	_assert_true(
		present_validator.validate_job_records([{"job_id": 1, "event_tags": ["artist", "visual_art"]}]),
		"Valid Job event_tags String Array is accepted"
	)

	var malformed_validator := EventDataValidator.new()
	var malformed_valid := malformed_validator.validate_job_records([{"job_id": 1, "event_tags": "artist"}])
	_assert_true(
		not malformed_valid and _validator_diagnostics_contain(malformed_validator, "must be an Array"),
		"Malformed Job event_tags is rejected"
	)

	var bad_element_validator := EventDataValidator.new()
	var bad_element_valid := bad_element_validator.validate_job_records([{"job_id": 1, "event_tags": ["artist", 7]}])
	_assert_true(
		not bad_element_valid and _validator_diagnostics_contain(bad_element_validator, "must be a non-empty String"),
		"Non-String Job event_tag is rejected"
	)


func _test_complete_effect_whitelist_and_score_check() -> void:
	var follow_up := _base_event("follow_up", "general")
	follow_up["trigger"] = {"type": "scheduled"}
	var event := _base_event("all_effects", "general")
	event["participants"] = {
		"primary": {"type": "character", "source": "trigger"},
		"target": {"type": "character", "source": "relation", "relation": "spouse", "from": "primary"},
		"house": {"type": "house", "source": "primary_house"},
		"business": {"type": "business", "source": "owned_business"}
	}
	event["choices"][0]["resolution"]["effects"] = _all_valid_effects()
	var registry := _registry_for("general", [event, follow_up])
	_assert_true(
		registry.is_valid,
		"Complete approved effect whitelist is structurally representable",
		registry.get_diagnostic_text()
	)

	var score_event := _base_event("score_check", "general")
	score_event["choices"][0]["resolution"] = {
		"mode": "score_check",
		"sources": [
			{"source": "stat", "target": "primary", "stat": "logic", "weight": 0.5},
			{"source": "lifestyle_score", "target": "primary", "weight": 0.5}
		],
		"threshold": 60,
		"success": {"outcome_id": "pass", "effects": []},
		"failure": {"outcome_id": "fail", "effects": []}
	}
	var score_registry := _registry_for("general", [score_event])
	_assert_true(
		score_registry.is_valid,
		"Valid score_check resolution structure is accepted",
		score_registry.get_diagnostic_text()
	)


func _test_all_trigger_repeat_and_cooldown_constructs() -> void:
	var pools := [{"pool_id": "manual_pool", "selection_mode": "all_eligible"}]
	var trigger_definitions := [
		{"type": "system", "event": "age_reached", "parameters": {"age": 18}},
		{"type": "calendar", "cadence": {"unit": "week", "interval": 2}},
		{"type": "manual", "source": "lifestyle", "mode": "direct"},
		{"type": "manual", "source": "relationship", "mode": "pool", "pool_id": "manual_pool"},
		{"type": "chain"},
		{"type": "scheduled"}
	]
	var events: Array = []
	for index in trigger_definitions.size():
		var event := _base_event("trigger_valid_%d" % index, "general")
		event["trigger"] = trigger_definitions[index]
		events.append(event)
	var trigger_registry := _registry_for("general", events, pools)
	_assert_true(
		trigger_registry.is_valid,
		"All five trigger families and valid manual/calendar structures are representable",
		trigger_registry.get_diagnostic_text()
	)

	events.clear()
	for index in EventDataValidator.REPEAT_MODES.size():
		var event := _base_event("repeat_valid_%d" % index, "general")
		event["repeat"] = {"mode": EventDataValidator.REPEAT_MODES[index]}
		events.append(event)
	var repeat_registry := _registry_for("general", events)
	_assert_true(
		repeat_registry.is_valid,
		"All seven approved repeat modes are representable",
		repeat_registry.get_diagnostic_text()
	)

	events.clear()
	for index in EventDataValidator.COOLDOWN_SCOPES.size():
		var event := _base_event("cooldown_valid_%d" % index, "general")
		event["cooldown"] = {
			"scope": EventDataValidator.COOLDOWN_SCOPES[index],
			"unit": EventDataValidator.CALENDAR_UNITS[index % EventDataValidator.CALENDAR_UNITS.size()],
			"value": index + 1
		}
		events.append(event)
	var cooldown_registry := _registry_for("general", events)
	_assert_true(
		cooldown_registry.is_valid,
		"All approved cooldown scopes and calendar units are representable",
		cooldown_registry.get_diagnostic_text()
	)


func _test_all_requirement_constructs() -> void:
	var outcome_source := _base_event("outcome_source", "general")
	outcome_source["choices"][0]["resolution"] = {
		"mode": "weighted",
		"outcomes": [{"outcome_id": "known_outcome", "weight": 1, "effects": []}]
	}
	var event := _base_event("all_requirements", "general")
	event["requirements"] = {"all": [
		{"type": "stat", "target": "primary", "stat": "health", "operator": ">=", "value": 50},
		{"type": "flag", "target": "primary", "operator": "==", "value": 1001},
		{"type": "age", "target": "primary", "operator": ">=", "value": 18},
		{"type": "life_stage", "target": "primary", "operator": "in", "value": ["young_adult", "adult"]},
		{"type": "gender", "target": "primary", "operator": "==", "value": "female"},
		{"type": "is_alive", "target": "primary", "operator": "==", "value": true},
		{"type": "is_family_member", "target": "primary", "operator": "==", "value": true},
		{"type": "has_child", "target": "primary", "operator": "==", "value": false},
		{"type": "has_parent", "target": "primary", "operator": "==", "value": true},
		{"type": "has_spouse", "target": "primary", "operator": "==", "value": true},
		{"type": "family_member_count", "operator": ">=", "value": 2},
		{"type": "employment_status", "target": "primary", "operator": "==", "value": "employed"},
		{"type": "job", "target": "primary", "operator": "==", "value": 1001},
		{"type": "education_stage", "target": "primary", "operator": "==", "value": "university"},
		{"type": "school", "target": "primary", "operator": "==", "value": 1001},
		{"type": "school_type", "target": "primary", "operator": "==", "value": "public"},
		{"type": "major", "target": "primary", "operator": "==", "value": 5001},
		{"type": "lifestyle_score", "target": "primary", "operator": ">=", "value": 60},
		{"type": "equipped_item", "target": "primary", "operator": "==", "value": ITEM_ID},
		{"type": "item_type", "target": "primary", "operator": "==", "value": "accessory"},
		{"type": "item_rarity", "target": "primary", "operator": "==", "value": "common"},
		{"type": "item_flag", "target": "primary", "operator": "==", "value": 1001},
		{"type": "money", "operator": ">=", "value": 100},
		{"type": "diamonds", "operator": ">=", "value": 1},
		{"type": "house_assignment", "target": "primary", "operator": "==", "value": true},
		{"type": "house_level", "target": "primary", "operator": ">=", "value": 1},
		{"type": "household_status", "operator": "==", "value": "orderly"},
		{"type": "household_perk", "operator": "==", "value": "artistic"},
		{"type": "business_owned", "operator": "==", "value": true},
		{"type": "business_type", "target": "primary", "operator": "==", "value": "cafe"},
		{"type": "business_level", "target": "primary", "operator": ">=", "value": 1},
		{"type": "business_role", "target": "primary", "operator": "==", "value": "manager"},
		{"type": "event_seen", "operator": "==", "value": "outcome_source"},
		{"type": "event_completed", "operator": "==", "value": "outcome_source"},
		{"type": "event_not_completed", "operator": "==", "value": "all_requirements"},
		{"type": "choice_made", "operator": "==", "value": {"event_id": "outcome_source", "choice_id": "continue"}},
		{"type": "outcome_reached", "operator": "==", "value": {"event_id": "outcome_source", "outcome_id": "known_outcome"}},
		{"type": "entitlement", "operator": "==", "value": "caravan_event_pack"},
		{"type": "date", "operator": ">=", "value": "1985-01-26"},
		{"type": "year", "operator": ">=", "value": 1985},
		{"type": "month", "operator": "in", "value": [1, 12]}
	]}
	var registry := _registry_for("general", [event, outcome_source])
	_assert_true(
		registry.is_valid,
		"All approved requirement families except unauthored Job tags are structurally representable",
		registry.get_diagnostic_text()
	)


func _all_valid_effects() -> Array:
	return [
		{"type": "stat_change", "target": "primary", "stat": "health", "amount": 5},
		{"type": "stat_set", "target": "primary", "stat": "happiness", "value": 80},
		{"type": "add_flag", "target": "primary", "flag_id": 1001},
		{"type": "remove_flag", "target": "primary", "flag_id": 1001},
		{"type": "relationship_marry", "primary": "primary", "target": "target"},
		{"type": "relationship_divorce", "primary": "primary", "target": "target"},
		{"type": "money_change", "amount": 100},
		{"type": "diamond_change", "amount": 1},
		{"type": "accept_job_offer", "target": "primary"},
		{"type": "reject_job_offer", "target": "primary"},
		{"type": "job_remove", "target": "primary"},
		{"type": "salary_increase", "target": "primary", "amount": 100},
		{"type": "education_enroll", "target": "primary", "school_id": 1001},
		{"type": "add_item", "target": "primary", "item_id": ITEM_ID},
		{"type": "remove_item", "target": "primary", "item_id": ITEM_ID},
		{"type": "equip_item", "target": "primary", "item_id": ITEM_ID},
		{"type": "unequip_item", "target": "primary", "item_id": ITEM_ID},
		{"type": "remove_from_house", "target": "primary"},
		{"type": "business_upgrade", "business": "business"},
		{"type": "queue_event", "event_id": "follow_up"},
		{"type": "schedule_event", "event_id": "follow_up", "delay": {"unit": "month", "value": 1}, "inherit_context": true},
		{"type": "cancel_scheduled_event", "event_id": "follow_up"}
	]


func _base_event(event_id: String, category: String) -> Dictionary:
	return {
		"event_id": event_id,
		"category": category,
		"domain": category,
		"subtype": "regression_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1,
		"priority": 0,
		"exclusive_group": null,
		"trigger": {"type": "chain"},
		"participants": {
			"primary": {"type": "character", "source": "trigger"}
		},
		"requirements": {"all": []},
		"repeat": {"mode": "once"},
		"cooldown": null,
		"behavior": {"blocking": true, "pause_game": true},
		"content": {"title": "Regression Event", "description": "Controlled test definition."},
		"presentation": {"template": "standard_event"},
		"choices": [{
			"choice_id": "continue",
			"title": "Continue",
			"resolution": {"mode": "deterministic", "effects": []}
		}]
	}


func _document(category: String, events: Array, pools: Array = []) -> Dictionary:
	return {
		"schema_version": 1,
		"category": category,
		"pools": pools,
		"events": events
	}


func _registry_for(category: String, events: Array, pools: Array = []) -> EventDataRegistry:
	var registry := EventDataRegistry.new()
	registry.load_from_json_sources({
		category + ".json": JSON.stringify(_document(category, events, pools))
	})
	return registry


func _expect_invalid_event(
	event: Dictionary,
	test_name: String,
	expected_message: String,
	category: String = "general"
) -> void:
	var registry := _registry_for(category, [event])
	_assert_invalid(registry, test_name, expected_message)


func _expect_invalid_sources(sources: Dictionary, test_name: String, expected_message: String) -> void:
	var registry := EventDataRegistry.new()
	registry.load_from_json_sources(sources)
	_assert_invalid(registry, test_name, expected_message)


func _assert_invalid(registry: EventDataRegistry, test_name: String, expected_message: String) -> void:
	_assert_true(
		not registry.is_valid and _diagnostics_contain(registry, expected_message),
		test_name,
		registry.get_diagnostic_text()
	)


func _diagnostics_contain(registry: EventDataRegistry, expected: String) -> bool:
	for diagnostic in registry.diagnostics:
		if expected.to_lower() in String(diagnostic.get("message", "")).to_lower():
			return true
	return false


func _validator_diagnostics_contain(validator: EventDataValidator, expected: String) -> bool:
	for diagnostic in validator.diagnostics:
		if expected.to_lower() in String(diagnostic.get("message", "")).to_lower():
			return true
	return false


func _assert_true(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)
		if not detail.is_empty():
			print(detail)
