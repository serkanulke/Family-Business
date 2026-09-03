extends Node


class TestHistoryProvider:
	extends EventHistoryQueryProvider
	var seen_ids: Array[String] = ["story_seen"]
	var completed_ids: Array[String] = ["story_completed"]

	func has_seen(event_id: String, _participants: Dictionary, _context: Dictionary) -> bool:
		return event_id in seen_ids

	func has_completed(event_id: String, _participants: Dictionary, _context: Dictionary) -> bool:
		return event_id in completed_ids

	func has_choice(event_id: String, choice_id: String, _participants: Dictionary, _context: Dictionary) -> bool:
		return event_id == "story_completed" and choice_id == "choice_a"

	func has_outcome(event_id: String, outcome_id: String, _participants: Dictionary, _context: Dictionary) -> bool:
		return event_id == "story_completed" and outcome_id == "outcome_a"


class TestEntitlementProvider:
	extends EntitlementQueryProvider
	var owned: Array[String] = ["caravan_event_pack"]

	func owns_entitlement(entitlement_id: String) -> bool:
		return entitlement_id in owned


class TestAvailabilityProvider:
	extends EventAvailabilityStateProvider
	var cooldown_ids: Array[String] = ["manual_cooldown"]
	var completed_ids: Array[String] = ["manual_completed"]

	func is_on_cooldown(event: Dictionary, _participants: Dictionary, _context: Dictionary) -> bool:
		return String(event.get("event_id", "")) in cooldown_ids

	func is_completed_non_repeatable(event: Dictionary, _participants: Dictionary, _context: Dictionary) -> bool:
		return String(event.get("event_id", "")) in completed_ids


var passed := 0
var failed := 0
var original_state: Dictionary = {}
var query_provider: EventRuntimeQueryProvider
var evaluator: RequirementEvaluator
var state_provider: TestAvailabilityProvider
var registry: EventDataRegistry
var service: EventRuntimeService


func _ready() -> void:
	_store_state()
	_setup_runtime_state()
	_run_tests()
	_restore_state()
	print("========================================")
	print("Event Phase 2 tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	if failed == 0:
		print("ALL EVENT PHASE 2 TESTS PASSED.")
	else:
		push_error("Event Phase 2 has %d failing test(s)." % failed)
	get_tree().quit(0 if failed == 0 else 1)


func _run_tests() -> void:
	_test_recursive_logic()
	_test_all_operators_and_invalid_runtime_values()
	_test_every_requirement_type()
	_test_item_flag_is_unsupported_at_runtime()
	_test_lifestyle_exact_boundary()
	_test_job_tag_absent()
	_test_family_business_counts_as_employment()
	_test_relationship_candidate_pool_is_manager_owned()
	_test_participant_sources()
	_test_group_candidate_preparation_and_validation()
	_test_registry_runtime_access()
	_test_manual_discovery_and_availability()
	_test_final_revalidation_and_instances()
	_test_read_only_behavior()


func _setup_runtime_state() -> void:
	TimeManager.current_day = 1
	TimeManager.current_month = 9
	TimeManager.current_year = 1985
	GameManager.family_money = 50000
	GameManager.diamonds = 10
	CharacterManager.jobs.append({
		"job_id": 9901, "job_name": "Gallery Artist",
		"event_tags": ["artist", "visual_art"]
	})
	CharacterManager.characters = [
		_character(1, "Alice", true, "1955-09-01", 60, [1001, 1002], 9901),
		_character(2, "Blake", true, "1954-01-01", 70, [], null),
		_character(3, "Casey", true, "1930-01-01", 65, [], null),
		_character(4, "Drew", true, "1970-01-01", 55, [], null),
		_character(5, "Evan", true, "1965-01-01", 40, [], null),
		_character(6, "River", false, "1958-01-01", 75, [], null),
		_character(7, "Sage", true, "1962-01-01", 80, [], null)
	]
	CharacterManager.characters[0]["partner_id"] = 2
	CharacterManager.characters[0]["parent_ids"] = [3]
	CharacterManager.characters[0]["children_ids"] = [4]
	CharacterManager.characters[0]["relationship_status"] = "married"
	CharacterManager.characters[0]["education_stage"] = "university"
	CharacterManager.characters[0]["school_id"] = 4001
	CharacterManager.characters[0]["major_id"] = 5001
	CharacterManager.characters[1]["partner_id"] = 1
	CharacterManager.characters[2]["children_ids"] = [1]
	CharacterManager.characters[3]["parent_ids"] = [1]
	CharacterManager.characters[5]["character_type"] = "relationship_npc"
	CharacterManager.characters[5]["relationship_status"] = "candidate"
	CharacterManager.characters[5]["linked_character_id"] = 1

	var unpooled_relationship_character := _character(
		8,
		"Morgan",
		false,
		"1960-01-01",
		70,
		[],
		null
	)
	unpooled_relationship_character["character_type"] = "relationship_npc"
	unpooled_relationship_character["relationship_status"] = "candidate"
	unpooled_relationship_character["linked_character_id"] = 1
	CharacterManager.characters.append(
		unpooled_relationship_character
	)

	RelationshipNpcManager.relationship_candidate_ids = [6]

	ItemManager.catalog = [
		_item_definition("item_accessory", "Silk Scarf", "accessory", "rare", 20),
		_item_definition("item_outfit", "Tailored Outfit", "outfit", "epic", 20),
		_item_definition("item_vehicle", "City Car", "vehicle", "common", 19)
	]
	ItemManager.catalog_by_id = {}
	for item in ItemManager.catalog:
		ItemManager.catalog_by_id[String(item["id"])] = item
	ItemManager.family_inventory = [
		{"instance_id": "instance_accessory", "item_id": "item_accessory"},
		{"instance_id": "instance_outfit", "item_id": "item_outfit"},
		{"instance_id": "instance_vehicle", "item_id": "item_vehicle"}
	]
	ItemManager.equipped_assignments = {"1": {
		"accessory": "instance_accessory", "outfit": "instance_outfit", "vehicle": "instance_vehicle"
	}}

	HouseManager.houses = [{
		"house_instance_id": "house_phase2", "house_definition_id": "family_house",
		"property_id": "house_phase2_plot", "level": 3,
		"role_assignments": {"head_of_household": 1, "cook": null, "housekeeper": null, "caregiver": null},
		"resident_character_ids": [2, 3, 4, 5]
	}]
	BusinessManager.businesses = [{
		"business_instance_id": "business_phase2", "business_type_id": "cafe",
		"plot_id": "business_phase2_plot", "level": 2,
		"slots": [{"slot_id": "cafe_manager_01", "assigned_character_id": 1, "assigned_npc_id": null}]
	}]

	query_provider = EventRuntimeQueryProvider.new(TestHistoryProvider.new(), TestEntitlementProvider.new())
	evaluator = RequirementEvaluator.new(query_provider)
	state_provider = TestAvailabilityProvider.new()
	registry = _manual_registry()
	service = EventRuntimeService.new(registry, query_provider, state_provider)


func _test_recursive_logic() -> void:
	var participants := {"primary": 1}
	_assert(evaluator.evaluate({"all": [_stat(">=", 60), _stat("<=", 60)]}, participants).eligible, "Recursive all true")
	_assert(not evaluator.evaluate({"all": [_stat(">", 60), _stat("==", 60)]}, participants).eligible, "Recursive all false")
	_assert(evaluator.evaluate({"any": [_stat("<", 60), _stat("==", 60)]}, participants).eligible, "Recursive any true")
	_assert(not evaluator.evaluate({"any": [_stat("<", 60), _stat(">", 60)]}, participants).eligible, "Recursive any false")
	_assert(evaluator.evaluate({"none": [_stat("<", 60), _stat(">", 60)]}, participants).eligible, "Recursive none true")
	_assert(not evaluator.evaluate({"none": [_stat("==", 60)]}, participants).eligible, "Recursive none false")
	var nested := {"all": [
		{"any": [_stat("==", 59), _stat("==", 60)]},
		{"none": [{"all": [_stat(">", 60), _stat("<", 70)]}]}
	]}
	_assert(evaluator.evaluate(nested, participants).eligible, "Nested all/any/none combination")


func _test_all_operators_and_invalid_runtime_values() -> void:
	var participants := {"primary": 1}
	var requirements := [
		_stat("==", 60), _stat("!=", 59), _stat(">", 59), _stat(">=", 60),
		_stat("<", 61), _stat("<=", 60), _stat("in", [59, 60]), _stat("not_in", [58, 59]),
		{"type": "flag", "target": "primary", "operator": "contains", "value": 1001},
		{"type": "flag", "target": "primary", "operator": "not_contains", "value": 1999}
	]
	var names := ["==", "!=", ">", ">=", "<", "<=", "in", "not_in", "contains", "not_contains"]
	for index in requirements.size():
		_assert(evaluator.evaluate({"all": [requirements[index]]}, participants).eligible, "Operator %s works" % names[index])
	CharacterManager.characters[0]["logic"] = "60"
	var invalid := evaluator.evaluate({"all": [_stat(">=", 60)]}, participants)
	_assert(not invalid.eligible and _reason_code(invalid, "invalid_runtime_value"), "Invalid runtime value is rejected without coercion")
	CharacterManager.characters[0]["logic"] = 60


func _test_every_requirement_type() -> void:
	var participants := {"primary": 1, "business": "business_phase2", "house": "house_phase2"}
	var context := {"business_instance_id": "business_phase2", "house_instance_id": "house_phase2"}
	var status_id := String(HouseManager.get_household_status("house_phase2").get("status_id", ""))
	var requirements := [
		{"type":"stat","target":"primary","stat":"logic","operator":">=","value":60},
		{"type":"flag","target":"primary","operator":"==","value":1001},
		{"type":"age","target":"primary","operator":">=","value":30},
		{"type":"life_stage","target":"primary","operator":"==","value":"young_adult"},
		{"type":"gender","target":"primary","operator":"==","value":"female"},
		{"type":"is_alive","target":"primary","operator":"==","value":true},
		{"type":"is_family_member","target":"primary","operator":"==","value":true},
		{"type":"has_child","target":"primary","operator":"==","value":true},
		{"type":"has_parent","target":"primary","operator":"==","value":true},
		{"type":"has_spouse","target":"primary","operator":"==","value":true},
		{"type":"family_member_count","operator":">=","value":5},
		{"type":"employment_status","target":"primary","operator":"==","value":"employed"},
		{"type":"job","target":"primary","operator":"==","value":9901},
		{"type":"job_tag","target":"primary","operator":"==","value":"artist"},
		{"type":"education_stage","target":"primary","operator":"==","value":"university"},
		{"type":"school","target":"primary","operator":"==","value":4001},
		{"type":"school_type","target":"primary","operator":"==","value":"public"},
		{"type":"major","target":"primary","operator":"==","value":5001},
		{"type":"lifestyle_score","target":"primary","operator":">=","value":59},
		{"type":"equipped_item","target":"primary","operator":"==","value":"item_accessory"},
		{"type":"item_type","target":"primary","operator":"==","value":"accessory"},
		{"type":"item_rarity","target":"primary","operator":"==","value":"rare"},
		{"type":"money","operator":">=","value":50000},
		{"type":"diamonds","operator":">=","value":10},
		{"type":"house_assignment","target":"primary","operator":"==","value":true},
		{"type":"house_level","target":"house","operator":">=","value":3},
		{"type":"household_status","operator":"==","value":status_id},
		{"type":"household_perk","operator":"==","value":"artistic"},
		{"type":"business_owned","operator":"==","value":true},
		{"type":"business_type","target":"business","operator":"==","value":"cafe"},
		{"type":"business_level","target":"business","operator":">=","value":2},
		{"type":"business_role","target":"primary","operator":"==","value":"cafe_manager_01"},
		{"type":"event_seen","operator":"==","value":"story_seen"},
		{"type":"event_completed","operator":"==","value":"story_completed"},
		{"type":"event_not_completed","operator":"==","value":"story_not_done"},
		{"type":"choice_made","operator":"==","value":{"event_id":"story_completed","choice_id":"choice_a"}},
		{"type":"outcome_reached","operator":"==","value":{"event_id":"story_completed","outcome_id":"outcome_a"}},
		{"type":"entitlement","operator":"==","value":"caravan_event_pack"},
		{"type":"date","operator":"==","value":"1985-09-01"},
		{"type":"year","operator":"==","value":1985},
		{"type":"month","operator":"==","value":9}
	]
	for requirement in requirements:
		var result := evaluator.evaluate({"all": [requirement]}, participants, context)
		_assert(result.eligible, "Requirement type %s evaluates from authoritative/query-provider state" % requirement.type, _messages(result))
	var missing_entitlement := evaluator.evaluate({"all":[{
		"type":"entitlement","operator":"==","value":"missing_event_pack"
	}]}, participants, context)
	_assert(not missing_entitlement.eligible and String(missing_entitlement.failure_reasons[0].message).contains("Missing Event Pack"), "Missing entitlement cleanly returns a readable locked reason")


func _test_item_flag_is_unsupported_at_runtime() -> void:
	var participants := {
		"primary": 1
	}
	var requirement := {
		"type": "item_flag",
		"target": "primary",
		"operator": "==",
		"value": 1001
	}
	var result := evaluator.evaluate(
		{
			"all": [
				requirement
			]
		},
		participants
	)

	_assert(
		not result.eligible
		and _reason_code(
			result,
			"runtime_value_unavailable"
		),
		"Unsupported item_flag requirement cannot fall back to Item data",
		_messages(result)
	)


func _test_lifestyle_exact_boundary() -> void:
	var requirement := {"all": [{"type":"lifestyle_score","target":"primary","operator":">=","value":60}]}
	_assert(not evaluator.evaluate(requirement, {"primary":1}).eligible, "Lifestyle 59 does not satisfy >= 60")
	ItemManager.catalog_by_id["item_vehicle"]["lifestyle_value"] = 20
	_assert(evaluator.evaluate(requirement, {"primary":1}).eligible, "Lifestyle 60 satisfies >= 60")
	ItemManager.catalog_by_id["item_vehicle"]["lifestyle_value"] = 19


func _test_job_tag_absent() -> void:
	CharacterManager.characters[0]["job_id"] = null
	var requirement := {"all": [{"type":"job_tag","target":"primary","operator":"==","value":"artist"}]}
	_assert(not evaluator.evaluate(requirement, {"primary":1}).eligible, "Job without event_tags does not satisfy job_tag")
	CharacterManager.characters[0]["job_id"] = 9901


func _test_family_business_counts_as_employment() -> void:
	var character: Dictionary = CharacterManager.characters[0]
	var previous_job_id = character.get("job_id", null)
	var previous_retired := bool(character.get("is_retired", false))
	var slot: Dictionary = BusinessManager.businesses[0]["slots"][0]
	var previous_slot_character = slot.get("assigned_character_id", null)

	character["job_id"] = null
	character["is_retired"] = false
	slot["assigned_character_id"] = 1

	var employed := evaluator.evaluate(
		{"all": [{
			"type": "employment_status",
			"target": "primary",
			"operator": "==",
			"value": "employed"
		}]},
		{"primary": 1}
	)
	_assert(
		employed.eligible,
		"Family Business assignment counts as employed without an external job",
		_messages(employed)
	)

	slot["assigned_character_id"] = null
	var unemployed := evaluator.evaluate(
		{"all": [{
			"type": "employment_status",
			"target": "primary",
			"operator": "==",
			"value": "unemployed"
		}]},
		{"primary": 1}
	)
	_assert(
		unemployed.eligible,
		"Character with neither external job nor Family Business assignment is unemployed",
		_messages(unemployed)
	)

	slot["assigned_character_id"] = 1
	character["is_retired"] = true
	var retired := evaluator.evaluate(
		{"all": [{
			"type": "employment_status",
			"target": "primary",
			"operator": "==",
			"value": "retired"
		}]},
		{"primary": 1}
	)
	_assert(
		retired.eligible,
		"Retirement remains authoritative over employment sources",
		_messages(retired)
	)

	character["job_id"] = previous_job_id
	character["is_retired"] = previous_retired
	slot["assigned_character_id"] = previous_slot_character


func _test_relationship_candidate_pool_is_manager_owned() -> void:
	RelationshipNpcManager.relationship_candidate_ids.append(999999)

	_assert(
		query_provider.get_relationship_npc_ids(1) == [6],
		"Relationship Event lookup uses only the RelationshipNPCManager candidate pool"
	)
	_assert(
		query_provider.get_relationship_npc_ids(2).is_empty(),
		"Relationship candidate lookup respects the manager-owned linked Character"
	)

	RelationshipNpcManager.relationship_candidate_ids.erase(999999)


func _test_participant_sources() -> void:
	var resolver := service.participant_resolver
	var trigger_event := _base_event("trigger_participants")
	trigger_event.participants = {"primary":{"type":"character","source":"trigger"}}
	_assert(resolver.resolve(trigger_event, {"trigger_participants":{"primary":1}}).participants.primary == 1, "Trigger primary resolves")

	var event := _base_event("participant_sources")
	event.participants = {
		"primary":{"type":"character","source":"player_selected"},
		"spouse":{"type":"character","source":"relation","relation":"spouse","from":"primary"},
		"parent":{"type":"character","source":"relation","relation":"parent","from":"primary"},
		"child":{"type":"character","source":"relation","relation":"child","from":"primary"},
		"candidate":{"type":"relationship_npc","source":"relationship_npc"},
		"house":{"type":"house","source":"primary_house"},
		"business":{"type":"business","source":"owned_business"},
		"provided":{"type":"context","source":"context"}
	}
	var resolved := resolver.resolve(event, {
		"selected_participants":{"primary":1},
		"context":{"provided":{"source":"inherited"},"business_instance_id":"business_phase2"}
	})
	_assert(resolved.ready and resolved.participants.spouse == 2 and resolved.participants.parent == 3 and resolved.participants.child == 4, "Spouse, parent, and child resolve from canonical family links", _messages(resolved))
	_assert(resolved.participants.candidate == 6, "Relationship NPC source resolves an existing candidate")
	_assert(resolved.participants.house == "house_phase2", "Primary House source resolves")
	_assert(resolved.participants.business == "business_phase2", "Owned family Business context resolves")
	_assert(typeof(resolved.participants.provided) == TYPE_DICTIONARY, "Inherited/provided Event context resolves")


func _test_group_candidate_preparation_and_validation() -> void:
	var event := _group_event("exact_group", 5, 5)
	var pending := service.participant_resolver.resolve(event, {})
	var group: Dictionary = pending.candidate_groups.travel_group
	_assert(pending.pending_selections == ["travel_group"] and group.candidates.size() == 6, "Exact group prepares all family candidates")
	_assert(not bool(group.candidates[4].eligible) and not group.candidates[4].failure_reasons.is_empty(), "Candidate result includes readable ineligibility reasons")
	_assert(service.participant_resolver.resolve(event, {"selected_participants":{"travel_group":[1,2,3,4,7]}}).ready, "Exact five-person group accepts five eligible family members")
	_assert(not service.participant_resolver.resolve(event, {"selected_participants":{"travel_group":[1,2,3,4]}}).valid, "Exact group rejects too few")
	var ranged := _group_event("ranged_group", 2, 4)
	_assert(service.participant_resolver.resolve(ranged, {"selected_participants":{"travel_group":[1,2]}}).ready, "Ranged group accepts minimum")
	_assert(not service.participant_resolver.resolve(ranged, {"selected_participants":{"travel_group":[1,2,3,4,5]}}).valid, "Ranged group rejects too many")
	_assert(not service.participant_resolver.resolve(ranged, {"selected_participants":{"travel_group":[1,1]}}).valid, "Group rejects duplicate Character IDs")
	_assert(not service.participant_resolver.resolve(ranged, {"selected_participants":{"travel_group":[1,5]}}).valid, "Group rejects an ineligible candidate")
	_assert(service.participant_resolver.resolve(event, {"selected_participants":{"travel_group":[1,2,3,4,5]}}).valid == false, "Exact group rechecks every selected Character")


func _test_registry_runtime_access() -> void:
	_assert(not service.get_definition("manual_available").is_empty(), "Runtime definition lookup by event_id")
	_assert(service.get_definitions_by_category("general", true).size() == 10, "Runtime lookup by category with enabled filter")
	_assert(service.get_definitions_by_domain("lifestyle", true).size() == 10, "Runtime lookup by domain")
	_assert(service.get_definitions_by_manual_source("lifestyle").size() == 9, "Runtime lookup by manual source includes disabled when requested")
	_assert(service.get_definitions_by_pool("manual_pool", true).size() == 1, "Runtime lookup by pool_id")
	_assert(service.get_content("manual_available").title == "Manual Available", "Runtime content lookup")
	_assert(service.get_presentation("manual_available").template == "standard_event", "Runtime presentation lookup")


func _test_manual_discovery_and_availability() -> void:
	var context := {"selected_participants":{"primary":1}}
	var direct := service.discover_manual("lifestyle", context, "direct")
	_assert(direct.events.size() == 8 and not direct.weighted_selection_performed, "Direct manual discovery returns definitions without selection")
	_assert(_status_for(direct.events, "manual_available") == EventRuntimeService.AVAILABLE, "Manual available state")
	_assert(_status_for(direct.events, "manual_locked") == EventRuntimeService.LOCKED_REQUIREMENTS, "Manual locked_requirements state")
	_assert(_status_for(direct.events, "manual_cost") == EventRuntimeService.LOCKED_COST, "Manual locked_cost state")
	_assert(_status_for(direct.events, "manual_cooldown") == EventRuntimeService.LOCKED_COOLDOWN, "Manual locked_cooldown provider state")
	_assert(_status_for(direct.events, "manual_completed") == EventRuntimeService.COMPLETED_NON_REPEATABLE, "Manual completed_non_repeatable provider state")
	_assert(_status_for(direct.events, "manual_disabled") == EventRuntimeService.DISABLED, "Disabled manual definition is explicit")
	var locked := _availability_for(direct.events, "manual_locked")
	_assert(String(locked.failure_reasons[0].message).contains("Money"), "Locked result contains a player-readable reason")
	var pool := service.discover_manual("lifestyle", context, "pool", "manual_pool")
	_assert(pool.events.size() == 1 and pool.events[0].event_id == "manual_pool_event" and not pool.weighted_selection_performed, "Pool discovery returns eligible candidates without weighted execution")
	_assert(service.discover_manual("relationship", context, "direct").events.size() == 1, "Relationship manual source uses common discovery")
	_assert(service.discover_manual("family_agency", context, "direct").events.size() == 1, "Family Agency manual source uses common discovery")
	var group := service.get_availability("manual_group", {})
	_assert(group.status == EventRuntimeService.REQUIRES_PARTICIPANTS and group.candidate_groups.has("travel_group"), "Manual discovery prepares participant-group selection")


func _test_final_revalidation_and_instances() -> void:
	var runtime_context := {"selected_participants":{"primary":1}}
	var first := service.create_activatable_instance("manual_available", runtime_context)
	var second := service.create_activatable_instance("manual_available", runtime_context, "evt_00000000")
	_assert(first.created and second.created, "Available manual Event creates activatable instances")
	var one: EventInstance = first.instance
	var two: EventInstance = second.instance
	_assert(one.instance_id == "evt_00000001" and two.instance_id == "evt_00000002", "Runtime instance IDs are deterministic and unique")
	_assert(one.event_id == "manual_available" and one.definition_version == 1 and one.trigger_type == "manual", "EventInstance links definition and trigger")
	_assert(one.participants.primary == 1 and one.context.is_empty() and two.source_instance_id == "evt_00000000", "EventInstance preserves participants, context, and source instance")
	var serialized := one.to_dictionary()
	_assert(not serialized.has("title") and not serialized.has("description") and not serialized.has("presentation"), "EventInstance does not duplicate static display data")
	var discovered := service.get_availability("manual_available", runtime_context)
	CharacterManager.characters[0]["is_alive"] = false
	var stale := service.create_activatable_instance("manual_available", runtime_context)
	_assert(discovered.available and not stale.created and stale.availability.status == EventRuntimeService.LOCKED_REQUIREMENTS, "Definition and participant are revalidated immediately before activation")
	CharacterManager.characters[0]["is_alive"] = true
	var rediscovered := service.get_availability("manual_available", runtime_context)
	registry.events_by_id["manual_available"]["enabled"] = false
	var disabled_after_discovery := service.create_activatable_instance("manual_available", runtime_context)
	_assert(rediscovered.available and not disabled_after_discovery.created and disabled_after_discovery.availability.status == EventRuntimeService.DISABLED, "Definition enabled state is revalidated before activation")
	registry.events_by_id["manual_available"]["enabled"] = true


func _test_read_only_behavior() -> void:
	var before := _gameplay_snapshot()
	service.discover_manual("lifestyle", {"selected_participants":{"primary":1}})
	service.create_activatable_instance("manual_available", {"selected_participants":{"primary":1}})
	var after := _gameplay_snapshot()
	_assert(before == after, "Phase 2 discovery/evaluation/instance creation does not mutate gameplay state")


func _manual_registry() -> EventDataRegistry:
	var events := [
		_manual_event("manual_available", true, "direct", {"all":[{"type":"money","operator":">=","value":100}]}),
		_manual_event("manual_locked", true, "direct", {"all":[{"type":"money","operator":">=","value":999999}]}),
		_manual_event("manual_cost", true, "direct", {"all":[]}, {"currency":"diamonds","amount":999}),
		_manual_event("manual_cooldown", true, "direct"),
		_manual_event("manual_completed", true, "direct"),
		_manual_event("manual_disabled", false, "direct"),
		_manual_event("manual_group", true, "direct", {"all":[]}, null, true),
		_manual_event("manual_extra", true, "direct"),
		_manual_event("manual_pool_event", true, "pool", {"all":[]}, null, false, "manual_pool"),
		_manual_event("relationship_direct", true, "direct", {"all":[]}, null, false, "", "relationship"),
		_manual_event("agency_direct", true, "direct", {"all":[]}, null, false, "", "family_agency")
	]
	var document := {"schema_version":1,"category":"general","pools":[{"pool_id":"manual_pool","selection_mode":"weighted_one"}],"events":events}
	var result := EventDataRegistry.new()
	var loaded := result.load_from_json_sources({"general.json":JSON.stringify(document)})
	_assert(loaded, "Phase 2 manual fixture registry validates", result.get_diagnostic_text())
	return result


func _manual_event(
	event_id: String,
	enabled: bool,
	mode: String,
	requirements: Dictionary = {"all":[]},
	cost = null,
	group := false,
	pool_id := "",
	source := "lifestyle"
) -> Dictionary:
	var event := _base_event(event_id)
	event.enabled = enabled
	event.requirements = requirements
	event.content.title = event_id.replace("_", " ").capitalize()
	event.trigger = {"type":"manual","source":source,"mode":mode}
	if mode == "pool": event.trigger.pool_id = pool_id
	event.participants = {
		"travel_group": {
			"type":"character_group","source":"player_selected","min":5,"max":5,
			"requirements":{"all":[{"type":"is_alive","target":"travel_group","operator":"==","value":true}]},
			"selection_ui":{"title":"Travel Group","description":"Select family","show_ineligible":true}
		}
	} if group else {"primary":{"type":"character","source":"player_selected"}}
	if cost != null: event.cost = cost
	return event


func _group_event(event_id: String, minimum: int, maximum: int) -> Dictionary:
	var event := _base_event(event_id)
	event.participants = {"travel_group":{
		"type":"character_group","source":"player_selected","min":minimum,"max":maximum,
		"requirements":{"all":[{"type":"stat","target":"travel_group","stat":"health","operator":">=","value":50}]},
		"selection_ui":{"title":"Group","description":"Choose","show_ineligible":true}
	}}
	return event


func _base_event(event_id: String) -> Dictionary:
	return {
		"event_id":event_id,"category":"general","domain":"lifestyle","subtype":"phase2_fixture","enabled":true,
		"rarity":"common","weight":1,"priority":0,"exclusive_group":null,
		"trigger":{"type":"chain"},"participants":{},"requirements":{"all":[]},
		"repeat":{"mode":"once"},"cooldown":null,"behavior":{"blocking":true,"pause_game":true},
		"content":{"title":"Phase 2 Event","description":"Runtime test"},
		"presentation":{"template":"standard_event"},
		"choices":[{"choice_id":"continue","title":"Continue","resolution":{"mode":"deterministic","effects":[]}}]
	}


func _character(id: int, name: String, family: bool, birth_date: String, stat: int, flags: Array, job_id) -> Dictionary:
	return {
		"character_id":id,"first_name":name,"gender":"female","birth_date":birth_date,
		"life_stage":"young_adult","is_alive":true,"is_player_family":family,
		"parent_ids":[],"children_ids":[],"partner_id":null,"flag_ids":flags.duplicate(),
		"happiness":stat,"health":stat,"logic":stat,"attractiveness":stat,
		"social":stat,"confidence":stat,"discipline":stat,"creativity":stat,
		"job_id":job_id,"is_retired":false,"school_id":null,"major_id":null,
		"education_status":"graduated","event_log":[]
	}


func _item_definition(
	id: String,
	name: String,
	slot: String,
	rarity: String,
	lifestyle: int
) -> Dictionary:
	return {
		"id": id,
		"display_name": name,
		"slot": slot,
		"rarity": rarity,
		"lifestyle_value": lifestyle,
		"is_heirloom": true
	}


func _stat(operator: String, value) -> Dictionary:
	return {"type":"stat","target":"primary","stat":"logic","operator":operator,"value":value}


func _store_state() -> void:
	original_state = {
		"characters":CharacterManager.characters.duplicate(true), "jobs":CharacterManager.jobs.duplicate(true),
		"relationship_ids":RelationshipNpcManager.relationship_candidate_ids.duplicate(),
		"catalog":ItemManager.catalog.duplicate(true), "catalog_by_id":ItemManager.catalog_by_id.duplicate(true),
		"inventory":ItemManager.family_inventory.duplicate(true), "equipment":ItemManager.equipped_assignments.duplicate(true),
		"houses":HouseManager.houses.duplicate(true), "businesses":BusinessManager.businesses.duplicate(true),
		"money":GameManager.family_money,"diamonds":GameManager.diamonds,
		"day":TimeManager.current_day,"month":TimeManager.current_month,"year":TimeManager.current_year
	}


func _restore_state() -> void:
	CharacterManager.characters = original_state.characters
	CharacterManager.jobs = original_state.jobs
	RelationshipNpcManager.relationship_candidate_ids = original_state.relationship_ids
	ItemManager.catalog = original_state.catalog
	ItemManager.catalog_by_id = original_state.catalog_by_id
	ItemManager.family_inventory = original_state.inventory
	ItemManager.equipped_assignments = original_state.equipment
	HouseManager.houses = original_state.houses
	BusinessManager.businesses = original_state.businesses
	GameManager.family_money = original_state.money
	GameManager.diamonds = original_state.diamonds
	TimeManager.current_day = original_state.day
	TimeManager.current_month = original_state.month
	TimeManager.current_year = original_state.year


func _gameplay_snapshot() -> Dictionary:
	return {
		"characters":CharacterManager.characters.duplicate(true),"money":GameManager.family_money,"diamonds":GameManager.diamonds,
		"inventory":ItemManager.family_inventory.duplicate(true),"equipment":ItemManager.equipped_assignments.duplicate(true),
		"houses":HouseManager.houses.duplicate(true),"businesses":BusinessManager.businesses.duplicate(true),
		"date":TimeManager.get_iso_date_string()
	}


func _status_for(values: Array, event_id: String) -> String:
	return String(_availability_for(values, event_id).get("status", ""))


func _availability_for(values: Array, event_id: String) -> Dictionary:
	for value in values:
		if typeof(value) == TYPE_DICTIONARY and String(value.get("event_id", "")) == event_id:
			return value
	return {}


func _reason_code(result: Dictionary, code: String) -> bool:
	for reason in result.get("failure_reasons", []):
		if typeof(reason) == TYPE_DICTIONARY and String(reason.get("code", "")) == code: return true
	return false


func _messages(result: Dictionary) -> String:
	var messages: PackedStringArray = []
	for reason in result.get("failure_reasons", []):
		if typeof(reason) == TYPE_DICTIONARY: messages.append(String(reason.get("message", "")))
	return " | ".join(messages)


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty(): print(detail)
