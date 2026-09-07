extends Node


var passed := 0
var failed := 0
var registry: EventDataRegistry


func _ready() -> void:
	registry = EventDataRegistry.new()
	_assert(
		registry.load_all(),
		"Production Event registry validates",
		registry.get_diagnostic_text()
	)

	if registry.get_event("career_performance_review").is_empty():
		_finish()
		return

	_test_definition()
	_test_external_employee_eligibility()
	_test_unemployed_ineligibility()
	_test_family_business_worker_ineligibility()
	_test_probability_formulas()
	_test_percentage_salary_increase()
	_test_company_restructuring_definition()
	_test_company_restructuring_probability()
	_test_company_restructuring_job_loss()
	_test_workplace_conflict_definition()
	_test_workplace_conflict_probability()
	_test_heavy_workload_definition()
	_test_heavy_workload_probability()
	_test_new_career_event_eligibility()
	_test_character_event_templates()

	_finish()


func _test_definition() -> void:
	var event := registry.get_event("career_performance_review")
	var pool_record := registry.get_pool("career_random")
	var pool: Dictionary = pool_record.get("definition", {})

	_assert(
		String(event.get("category", "")) == "career"
		and String(event.get("pool_id", "")) == "career_random"
		and is_equal_approx(float(event.get("weight", 0.0)), 1.0),
		"Performance Review belongs to Career pool with weight 1"
	)

	_assert(
		String(pool.get("selection_mode", "")) == "weighted_one"
		and String(pool.get("selection_scope", "")) == "save"
		and is_equal_approx(float(pool.get("activation_chance", -1.0)), 0.015)
		and int(pool.get("max_events", 0)) == 1,
		"Career random pool uses one monthly save-scoped 1.5% activation roll"
	)

	var cooldown: Dictionary = event.get("cooldown", {})
	_assert(
		String(cooldown.get("scope", "")) == "character"
		and String(cooldown.get("unit", "")) == "year"
		and int(cooldown.get("value", 0)) == 5,
		"Performance Review uses a 5-year Character cooldown"
	)

	var choices: Array = event.get("choices", [])
	_assert(
		choices.size() == 3
		and String(choices[0].get("choice_id", "")) == "request_raise_25"
		and String(choices[1].get("choice_id", "")) == "request_raise_15"
		and String(choices[2].get("choice_id", "")) == "request_raise_5",
		"Performance Review exposes exactly the approved 25%, 15%, and 5% choices"
	)

	var description := String(event.get("content", {}).get("description", "")).to_lower()
	_assert(
		not description.contains("increased your salary")
		and not description.contains("gave you a raise"),
		"Event description does not claim a raise happened before the player chooses"
	)


func _test_external_employee_eligibility() -> void:
	_setup_external_employee()
	EventManager.configure_runtime(registry, null, 71)

	var availability := EventManager.runtime_service.get_availability(
		"career_performance_review",
		{"trigger_character_id": 1}
	)

	_assert(
		String(availability.get("status", "")) == EventRuntimeService.AVAILABLE,
		"Externally employed family Character is eligible for Performance Review",
		_str_reasons(availability)
	)


func _test_unemployed_ineligibility() -> void:
	_setup_base_character()
	EventManager.configure_runtime(registry, null, 72)

	var availability := EventManager.runtime_service.get_availability(
		"career_performance_review",
		{"trigger_character_id": 1}
	)

	_assert(
		String(availability.get("status", "")) != EventRuntimeService.AVAILABLE,
		"Unemployed Character is not eligible for Performance Review"
	)


func _test_family_business_worker_ineligibility() -> void:
	_setup_base_character()
	BusinessManager.businesses = [{
		"business_instance_id": "career_test_business",
		"slots": [{
			"slot_id": "manager",
			"assigned_character_id": 1,
			"assigned_npc_id": null
		}]
	}]
	EventManager.configure_runtime(registry, null, 73)

	var availability := EventManager.runtime_service.get_availability(
		"career_performance_review",
		{"trigger_character_id": 1}
	)

	_assert(
		String(availability.get("status", "")) != EventRuntimeService.AVAILABLE,
		"Family Business worker is excluded from external-company Performance Review"
	)


func _test_probability_formulas() -> void:
	_setup_external_employee()
	var character := CharacterManager.get_character_by_id(1)
	character["confidence"] = 30
	character["social"] = 20
	EventManager.configure_runtime(registry, null, 74)

	var event := registry.get_event("career_performance_review")
	var choices: Array = event.get("choices", [])

	var result_25 := EventManager.resolution_resolver.resolve(
		choices[0].get("resolution", {}),
		{"primary": 1},
		{}
	)
	var chance_25 := float(result_25.get("details", {}).get("chance_percent", -1.0))
	_assert(
		bool(result_25.get("valid", false))
		and is_equal_approx(chance_25, 18.75),
		"25% request uses ((Confidence + Social) / 2) × 0.75; 30/20 gives 18.75%",
		str(result_25)
	)

	var result_15 := EventManager.resolution_resolver.resolve(
		choices[1].get("resolution", {}),
		{"primary": 1},
		{}
	)
	var chance_15 := float(result_15.get("details", {}).get("chance_percent", -1.0))
	_assert(
		bool(result_15.get("valid", false))
		and is_equal_approx(chance_15, 27.0),
		"15% request uses Confidence × 0.90; Confidence 30 gives 27%",
		str(result_15)
	)

	var failure_25: Dictionary = choices[0].get("resolution", {}).get("failure", {})
	var failure_15: Dictionary = choices[1].get("resolution", {}).get("failure", {})
	_assert(
		failure_25.get("effects", []).is_empty()
		and failure_15.get("effects", []).is_empty(),
		"Failed 25% and 15% requests give no salary increase and no extra effect"
	)

	_assert(
		String(choices[2].get("resolution", {}).get("mode", "")) == "deterministic",
		"5% request is guaranteed and uses no stat check"
	)


func _test_percentage_salary_increase() -> void:
	_setup_external_employee()
	var character := CharacterManager.get_character_by_id(1)
	character["salary"] = 10000
	EventManager.configure_runtime(registry, null, 75)

	var effects: Array = [{
		"type": "salary_increase",
		"target": "primary",
		"amount": 5,
		"amount_mode": "percentage"
	}]

	var preflight := EventManager.effect_resolver.preflight(
		effects,
		{"primary": 1},
		{},
		GameManager.family_money,
		GameManager.diamonds
	)
	_assert(
		bool(preflight.get("valid", false)),
		"Percentage salary_increase passes Event effect preflight",
		str(preflight)
	)
	if not bool(preflight.get("valid", false)):
		return

	var applied := EventManager.effect_resolver.apply(
		preflight.get("plans", []),
		"career_production_test"
	)
	_assert(
		bool(applied.get("success", false))
		and int(character.get("salary", 0)) == 10500,
		"5% salary increase changes 10,000 salary to 10,500 through CareerManager",
		str(applied)
	)


func _test_company_restructuring_definition() -> void:
	var event := registry.get_event("career_company_restructuring")
	_assert(
		not event.is_empty(),
		"Company Restructuring production Event exists"
	)
	if event.is_empty():
		return

	_assert(
		String(event.get("category", "")) == "career"
		and String(event.get("pool_id", "")) == "career_random"
		and is_equal_approx(float(event.get("weight", 0.0)), 1.0),
		"Company Restructuring uses the Career random pool with weight 1"
	)

	var content: Dictionary = event.get("content", {})
	var choices: Array = event.get("choices", [])
	var descriptions_ok := String(content.get("description", "")).length() <= 40
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			descriptions_ok = false
			continue
		var choice: Dictionary = choice_value
		if String(choice.get("description", "")).length() > 40:
			descriptions_ok = false

	_assert(
		descriptions_ok,
		"Company Restructuring Event and choice descriptions stay within 40 characters"
	)

	_assert(
		choices.size() == 3
		and String(choices[0].get("choice_id", "")) == "do_not_object"
		and String(choices[1].get("choice_id", "")) == "challenge_decision"
		and String(choices[2].get("choice_id", "")) == "stand_your_ground",
		"Company Restructuring exposes exactly the approved three choices"
	)

	if choices.size() < 3:
		return

	var first_effects: Array = choices[0].get("resolution", {}).get("effects", [])
	_assert(
		first_effects.size() == 1
		and String(first_effects[0].get("type", "")) == "job_remove",
		"Don't object deterministically removes the external job"
	)

	var second_resolution: Dictionary = choices[1].get("resolution", {})
	var second_failure: Dictionary = second_resolution.get("failure", {})
	var second_failure_effects: Array = second_failure.get("effects", [])
	_assert(
		String(second_resolution.get("mode", "")) == "score_check"
		and String(second_resolution.get("check_mode", "")) == "probability"
		and second_failure_effects.size() == 1
		and String(second_failure_effects[0].get("type", "")) == "job_remove",
		"Challenge the decision uses probability and loses the job on failure"
	)

	var third_requirements: Dictionary = choices[2].get("requirements", {})
	var third_all: Array = third_requirements.get("all", [])
	var confidence_gate_ok := false
	for requirement_value in third_all:
		if typeof(requirement_value) != TYPE_DICTIONARY:
			continue
		var requirement: Dictionary = requirement_value
		if (
			String(requirement.get("type", "")) == "stat"
			and String(requirement.get("stat", "")) == "confidence"
			and String(requirement.get("operator", "")) == ">="
			and int(requirement.get("value", -1)) == 80
		):
			confidence_gate_ok = true
			break

	_assert(
		confidence_gate_ok
		and String(choices[2].get("resolution", {}).get("mode", "")) == "deterministic"
		and choices[2].get("resolution", {}).get("effects", []).is_empty(),
		"Stand your ground requires 80 Confidence and keeps the job"
	)


func _test_company_restructuring_probability() -> void:
	_setup_external_employee()
	var character := CharacterManager.get_character_by_id(1)
	character["confidence"] = 30
	character["discipline"] = 20
	EventManager.configure_runtime(registry, null, 76)

	var event := registry.get_event("career_company_restructuring")
	var choices: Array = event.get("choices", [])
	if choices.size() < 2:
		_assert(false, "Company Restructuring probability test has its approved second choice")
		return

	var result := EventManager.resolution_resolver.resolve(
		choices[1].get("resolution", {}),
		{"primary": 1},
		{}
	)
	var chance := float(result.get("details", {}).get("chance_percent", -1.0))

	_assert(
		bool(result.get("valid", false))
		and is_equal_approx(chance, 20.0),
		"Challenge uses ((Confidence + Discipline) / 2) × 0.80; 30/20 gives 20%",
		str(result)
	)


func _test_company_restructuring_job_loss() -> void:
	_setup_external_employee()
	var character := CharacterManager.get_character_by_id(1)
	EventManager.configure_runtime(registry, null, 77)

	var event := registry.get_event("career_company_restructuring")
	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		_assert(false, "Company Restructuring job-loss test has its first choice")
		return

	var effects: Array = choices[0].get("resolution", {}).get("effects", [])
	var preflight := EventManager.effect_resolver.preflight(
		effects,
		{"primary": 1},
		{},
		GameManager.family_money,
		GameManager.diamonds
	)
	_assert(
		bool(preflight.get("valid", false)),
		"Company Restructuring job_remove passes Event effect preflight",
		str(preflight)
	)
	if not bool(preflight.get("valid", false)):
		return

	var applied := EventManager.effect_resolver.apply(
		preflight.get("plans", []),
		"career_company_restructuring_test"
	)

	_assert(
		bool(applied.get("success", false))
		and character.get("job_id", null) == null
		and character.get("company_id", null) == null
		and int(character.get("salary", 0)) == 0,
		"Don't object removes external employment through CareerManager",
		str(applied)
	)


func _test_workplace_conflict_definition() -> void:
	var event := registry.get_event("career_workplace_conflict")
	_assert(not event.is_empty(), "Workplace Conflict production Event exists")
	if event.is_empty():
		return

	var choices: Array = event.get("choices", [])
	_assert(
		String(event.get("pool_id", "")) == "career_random"
		and is_equal_approx(float(event.get("weight", 0.0)), 1.0),
		"Workplace Conflict uses Career pool with weight 1"
	)
	_assert(_descriptions_within_limit(event, 40), "Workplace Conflict descriptions stay within 40 characters")
	_assert(
		choices.size() == 3
		and String(choices[0].get("choice_id", "")) == "seek_compromise"
		and String(choices[1].get("choice_id", "")) == "defend_yourself"
		and String(choices[2].get("choice_id", "")) == "push_back_hard",
		"Workplace Conflict exposes the approved three choices"
	)
	if choices.size() < 3:
		return

	_assert(
		String(choices[0].get("resolution", {}).get("mode", "")) == "deterministic"
		and choices[0].get("resolution", {}).get("effects", []).is_empty(),
		"Seek compromise produces no gameplay change"
	)

	var defend_success: Array = choices[1].get("resolution", {}).get("success", {}).get("effects", [])
	var defend_failure: Array = choices[1].get("resolution", {}).get("failure", {}).get("effects", [])
	_assert(
		_has_stat_change(defend_success, "confidence", 3)
		and _has_stat_change(defend_failure, "social", -3),
		"Defend yourself gives +3 Confidence on success and -3 Social on failure"
	)

	var hard_success: Array = choices[2].get("resolution", {}).get("success", {}).get("effects", [])
	var hard_failure: Array = choices[2].get("resolution", {}).get("failure", {}).get("effects", [])
	_assert(
		_has_stat_change(hard_success, "confidence", 5)
		and _has_stat_change(hard_failure, "social", -5),
		"Push back hard uses the stronger +5/-5 outcome"
	)


func _test_workplace_conflict_probability() -> void:
	_setup_external_employee()
	var character := CharacterManager.get_character_by_id(1)
	character["confidence"] = 30
	character["social"] = 20
	EventManager.configure_runtime(registry, null, 78)

	var choices: Array = registry.get_event("career_workplace_conflict").get("choices", [])
	if choices.size() < 3:
		_assert(false, "Workplace Conflict probability choices exist")
		return

	var defend := EventManager.resolution_resolver.resolve(
		choices[1].get("resolution", {}),
		{"primary": 1},
		{}
	)
	var hard := EventManager.resolution_resolver.resolve(
		choices[2].get("resolution", {}),
		{"primary": 1},
		{}
	)

	_assert(
		bool(defend.get("valid", false))
		and is_equal_approx(float(defend.get("details", {}).get("chance_percent", -1.0)), 20.0),
		"Defend yourself uses ((Confidence + Social) / 2) x 0.80; 30/20 gives 20%",
		str(defend)
	)
	_assert(
		bool(hard.get("valid", false))
		and is_equal_approx(float(hard.get("details", {}).get("chance_percent", -1.0)), 15.0),
		"Push back hard uses ((Confidence + Social) / 2) x 0.60; 30/20 gives 15%",
		str(hard)
	)


func _test_heavy_workload_definition() -> void:
	var event := registry.get_event("career_heavy_workload")
	_assert(not event.is_empty(), "Heavy Workload production Event exists")
	if event.is_empty():
		return

	var choices: Array = event.get("choices", [])
	_assert(
		String(event.get("pool_id", "")) == "career_random"
		and is_equal_approx(float(event.get("weight", 0.0)), 1.0),
		"Heavy Workload uses Career pool with weight 1"
	)
	_assert(_descriptions_within_limit(event, 40), "Heavy Workload descriptions stay within 40 characters")
	_assert(
		choices.size() == 3
		and String(choices[0].get("choice_id", "")) == "keep_your_pace"
		and String(choices[1].get("choice_id", "")) == "push_through"
		and String(choices[2].get("choice_id", "")) == "ask_for_compensation",
		"Heavy Workload exposes the approved three choices"
	)
	if choices.size() < 3:
		return

	_assert(
		String(choices[0].get("resolution", {}).get("mode", "")) == "deterministic"
		and choices[0].get("resolution", {}).get("effects", []).is_empty(),
		"Keep your pace produces no gameplay change"
	)

	var push_success: Array = choices[1].get("resolution", {}).get("success", {}).get("effects", [])
	var push_failure: Array = choices[1].get("resolution", {}).get("failure", {}).get("effects", [])
	_assert(
		_has_stat_change(push_success, "discipline", 3)
		and _has_stat_change(push_failure, "health", -3)
		and _has_stat_change(push_failure, "happiness", -3),
		"Push through gives +3 Discipline or -3 Health/-3 Happiness"
	)

	var comp_success: Array = choices[2].get("resolution", {}).get("success", {}).get("effects", [])
	var comp_failure: Array = choices[2].get("resolution", {}).get("failure", {}).get("effects", [])
	_assert(
		comp_success.size() == 1
		and String(comp_success[0].get("type", "")) == "salary_increase"
		and int(comp_success[0].get("amount", 0)) == 5
		and String(comp_success[0].get("amount_mode", "")) == "percentage"
		and comp_failure.is_empty(),
		"Ask for compensation gives +5% salary on success and no change on failure"
	)


func _test_heavy_workload_probability() -> void:
	_setup_external_employee()
	var character := CharacterManager.get_character_by_id(1)
	character["discipline"] = 30
	character["health"] = 20
	character["confidence"] = 30
	character["social"] = 20
	EventManager.configure_runtime(registry, null, 79)

	var choices: Array = registry.get_event("career_heavy_workload").get("choices", [])
	if choices.size() < 3:
		_assert(false, "Heavy Workload probability choices exist")
		return

	var push := EventManager.resolution_resolver.resolve(
		choices[1].get("resolution", {}),
		{"primary": 1},
		{}
	)
	var compensation := EventManager.resolution_resolver.resolve(
		choices[2].get("resolution", {}),
		{"primary": 1},
		{}
	)

	_assert(
		bool(push.get("valid", false))
		and is_equal_approx(float(push.get("details", {}).get("chance_percent", -1.0)), 20.0),
		"Push through uses ((Discipline + Health) / 2) x 0.80; 30/20 gives 20%",
		str(push)
	)
	_assert(
		bool(compensation.get("valid", false))
		and is_equal_approx(float(compensation.get("details", {}).get("chance_percent", -1.0)), 17.5),
		"Ask for compensation uses ((Confidence + Social) / 2) x 0.70; 30/20 gives 17.5%",
		str(compensation)
	)


func _test_new_career_event_eligibility() -> void:
	_setup_external_employee()
	EventManager.configure_runtime(registry, null, 80)

	var conflict := EventManager.runtime_service.get_availability(
		"career_workplace_conflict",
		{"trigger_character_id": 1}
	)
	var workload := EventManager.runtime_service.get_availability(
		"career_heavy_workload",
		{"trigger_character_id": 1}
	)
	_assert(
		String(conflict.get("status", "")) == EventRuntimeService.AVAILABLE
		and String(workload.get("status", "")) == EventRuntimeService.AVAILABLE,
		"New Career Events are available to externally employed family Characters"
	)

	_setup_base_character()
	BusinessManager.businesses = [{
		"business_instance_id": "career_new_event_business",
		"slots": [{
			"slot_id": "manager",
			"assigned_character_id": 1,
			"assigned_npc_id": null
		}]
	}]
	EventManager.configure_runtime(registry, null, 81)

	conflict = EventManager.runtime_service.get_availability(
		"career_workplace_conflict",
		{"trigger_character_id": 1}
	)
	workload = EventManager.runtime_service.get_availability(
		"career_heavy_workload",
		{"trigger_character_id": 1}
	)
	_assert(
		String(conflict.get("status", "")) != EventRuntimeService.AVAILABLE
		and String(workload.get("status", "")) != EventRuntimeService.AVAILABLE,
		"New Career Events exclude Family Business workers"
	)


func _descriptions_within_limit(event: Dictionary, limit: int) -> bool:
	if String(event.get("content", {}).get("description", "")).length() > limit:
		return false
	for choice_value in event.get("choices", []):
		if typeof(choice_value) != TYPE_DICTIONARY:
			return false
		var choice: Dictionary = choice_value
		if String(choice.get("description", "")).length() > limit:
			return false
	return true


func _has_stat_change(effects: Array, stat_name: String, amount: int) -> bool:
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if (
			String(effect.get("type", "")) == "stat_change"
			and String(effect.get("stat", "")) == stat_name
			and int(effect.get("amount", 0)) == amount
		):
			return true
	return false


func _test_character_event_templates() -> void:
	var event_ids := [
		"career_performance_review",
		"career_company_restructuring",
		"career_workplace_conflict",
		"career_heavy_workload"
	]
	var all_character_templates := true
	for event_id in event_ids:
		var event := registry.get_event(event_id)
		if (
			event.is_empty()
			or String(event.get("presentation", {}).get("template", "")) != "character_event"
		):
			all_character_templates = false
			break

	_assert(
		all_character_templates,
		"All Career production Events request the character_event presentation template"
	)


func _setup_external_employee() -> void:
	_setup_base_character()
	var character := CharacterManager.get_character_by_id(1)
	character["job_id"] = 2076
	character["company_id"] = "central_city_administration"
	character["salary"] = 10000
	character["unemployment_start_date"] = null


func _setup_base_character() -> void:
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	TimeManager.is_paused = false
	TimeManager.speed_multiplier = 1.0
	GameManager.family_money = 10000
	GameManager.diamonds = 0

	BusinessManager.businesses.clear()
	CareerManager.active_job_offers.clear()

	CharacterManager.characters = [{
		"character_id": 1,
		"character_type": "family",
		"first_name": "Career Test",
		"gender": "female",
		"birth_date": "1975-01-01",
		"life_stage": "young_adult",
		"is_alive": true,
		"is_player_family": true,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"flag_ids": [],
		"happiness": 50,
		"health": 100,
		"logic": 50,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50,
		"school_id": 4001,
		"major_id": null,
		"education_status": "graduated",
		"education_start_date": null,
		"major_selection_date": null,
		"expected_graduation_date": null,
		"graduation_date": "1999-01-01",
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"unemployment_start_date": "1999-01-01",
		"job_offer_cooldown_until": null,
		"is_retired": false,
		"event_log": []
	}]
	CharacterManager.next_character_id = 2


func _str_reasons(value: Dictionary) -> String:
	return str(value.get("failure_reasons", []))


func _finish() -> void:
	print("========================================")
	print("Event Career production tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
