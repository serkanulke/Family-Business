extends Node


var passed := 0
var failed := 0

var original_snapshot: Dictionary = {}
var original_registry: EventDataRegistry
var original_save_id := -1

var role_transitions: Array[Dictionary] = []
var legacy_family_slot_signals: Array[Dictionary] = []
var legacy_npc_slot_signals: Array[Dictionary] = []
var semantic_occurrences: Array[Dictionary] = []


func _ready() -> void:
	original_snapshot = SaveManager.create_save_snapshot()
	original_registry = EventManager.registry
	original_save_id = SaveManager.current_save_id
	SaveManager.current_save_id = -1

	_connect_capture_signals()

	_test_business_purchase_bridge()
	_test_business_upgrade_bridge()
	_test_business_upgrade_effect_integration()
	_test_staffing_stays_domain_only()
	_test_live_business_requirements()
	_test_save_load_without_business_semantic_replay()

	_disconnect_capture_signals()
	EventManager.configure_runtime(original_registry)
	SaveManager.apply_save_snapshot(original_snapshot)
	SaveManager.current_save_id = original_save_id

	print("========================================")
	print(
		"Event Phase 5E Business adapter tests: ",
		passed,
		" passed / ",
		failed,
		" failed"
	)
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_business_purchase_bridge() -> void:
	_setup_world(
		[],
		[_system_event("phase5e_purchase", "business_purchased", false)],
		[]
	)

	var purchase_cost := BusinessManager.get_business_acquisition_cost(
		"cafe",
		false
	)
	var money_before := GameManager.family_money
	var created := BusinessManager.create_business_instance(
		"cafe",
		"phase5e_plot_purchase",
		false
	)

	_assert(
		not created.is_empty()
		and int(created.get("level", 0)) == 1
		and GameManager.family_money == money_before - purchase_cost,
		"Business purchase remains a single canonical BusinessManager mutation"
	)
	var occurrences := _semantic("business_purchased")
	_assert(
		occurrences.size() == 1
		and _context_matches(
			occurrences[0],
			{
				"business_instance_id": String(
					created.get(
						"business_instance_id",
						""
					)
				),
				"business_type_id": "cafe",
				"plot_id": "phase5e_plot_purchase",
				"purchase_cost": purchase_cost,
				"new_level": 1
			}
		),
		"Successful purchase dispatches one authoritative business_purchased context"
	)
	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "phase5e_purchase",
		"Controlled purchase Event queues exactly once"
	)

	_cancel_all_events()
	_clear_captures()

	var duplicate := BusinessManager.create_business_instance(
		"cafe",
		"phase5e_plot_purchase",
		false
	)
	_assert(
		duplicate.is_empty()
		and _semantic("business_purchased").is_empty(),
		"Failed duplicate purchase emits no business_purchased occurrence"
	)


func _test_business_upgrade_bridge() -> void:
	var business := _business_fixture(
		"business_upgrade_direct",
		"cafe",
		1,
		"phase5e_plot_upgrade"
	)
	_setup_world(
		[],
		[_system_event("phase5e_upgrade", "business_upgraded", false)],
		[business]
	)

	var upgrade_cost := BusinessManager.get_business_upgrade_cost(
		"business_upgrade_direct"
	)
	var money_before := GameManager.family_money
	_assert(
		BusinessManager.upgrade_business(
			"business_upgrade_direct"
		),
		"Canonical BusinessManager upgrade succeeds"
	)
	_assert(
		int(
			BusinessManager.get_business_by_instance_id(
				"business_upgrade_direct"
			).get(
				"level",
				0
			)
		) == 2
		and GameManager.family_money == money_before - upgrade_cost,
		"Upgrade changes level and spends the canonical cost exactly once"
	)
	var occurrences := _semantic("business_upgraded")
	_assert(
		occurrences.size() == 1
		and _context_matches(
			occurrences[0],
			{
				"business_instance_id": "business_upgrade_direct",
				"business_type_id": "cafe",
				"new_level": 2,
				"upgrade_cost": upgrade_cost
			}
		),
		"Successful upgrade dispatches one authoritative business_upgraded context"
	)
	_assert(
		_semantic("business_role_changed").is_empty(),
		"Adding upgrade slots does not fabricate a Business role-change occurrence"
	)
	_cancel_all_events()

	_clear_captures()
	var max_business := _business_fixture(
		"business_max",
		"cafe",
		5,
		"phase5e_plot_max"
	)
	BusinessManager.businesses = [max_business]
	_assert(
		not BusinessManager.upgrade_business(
			"business_max"
		)
		and _semantic("business_upgraded").is_empty(),
		"Failed max-level upgrade emits no business_upgraded occurrence"
	)


func _test_business_upgrade_effect_integration() -> void:
	var business := _business_fixture(
		"business_upgrade_effect",
		"cafe",
		1,
		"phase5e_plot_effect"
	)
	var source := _upgrade_source_event()
	var follow_up := _system_event(
		"phase5e_upgrade_followup",
		"business_upgraded",
		false
	)
	_setup_world(
		[],
		[source, follow_up],
		[business]
	)

	var upgrade_cost := BusinessManager.get_business_upgrade_cost(
		"business_upgrade_effect"
	)
	var money_before := GameManager.family_money

	EventManager.dispatch_system_trigger(
		"phase5e_upgrade_request",
		{
			"context": {
				"business_instance_id": "business_upgrade_effect"
			}
		},
		"phase5e_upgrade_request:business_upgrade_effect",
		"Phase5ETest"
	)

	_assert(
		EventManager.active_event != null
		and EventManager.active_event.event_id == "phase5e_upgrade_source",
		"Controlled source Event resolves the canonical Business participant from context"
	)

	var resolved := EventManager.resolve_active_event(
		"continue"
	)
	_assert(
		bool(resolved.get("resolved", false))
		and int(
			BusinessManager.get_business_by_instance_id(
				"business_upgrade_effect"
			).get(
				"level",
				0
			)
		) == 2
		and GameManager.family_money == money_before - upgrade_cost,
		"business_upgrade effect delegates once to BusinessManager and spends one domain cost"
	)
	_assert(
		_semantic("business_upgraded").size() == 1
		and EventManager.active_event != null
		and EventManager.active_event.event_id == "phase5e_upgrade_followup"
		and EventManager.queued_events.is_empty(),
		"Nested Business upgrade produces one ordinary follow-up semantic Event after source resolution"
	)
	_cancel_all_events()


func _test_staffing_stays_domain_only() -> void:
	var character := _character(1)
	var business := _business_fixture(
		"business_staffing_domain_only",
		"hospital",
		1,
		"phase5e_plot_staffing_domain_only"
	)
	var slot_id := _first_slot_id(
		"hospital",
		1
	)

	_setup_world(
		[character],
		[_system_event(
			"phase5e_role_should_not_fire",
			"business_role_changed",
			true
		)],
		[business]
	)

	_assert(
		BusinessManager.assign_character_to_slot(
			"business_staffing_domain_only",
			slot_id,
			1
		),
		"Family Business staffing remains a canonical BusinessManager mutation"
	)
	_assert(
		legacy_family_slot_signals.size() == 1
		and int(
			legacy_family_slot_signals[0].get(
				"character_id",
				0
			)
		) == 1,
		"Existing family_business_slot_changed signal remains intact"
	)
	_assert(
		_semantic("business_role_changed").is_empty()
		and EventManager.active_event == null,
		"Staffing does not create an Event-specific business_role_changed semantic"
	)

	_clear_captures()

	_assert(
		BusinessManager.remove_character_from_slot(
			"business_staffing_domain_only",
			slot_id
		),
		"Family Business removal remains a canonical BusinessManager mutation"
	)
	_assert(
		legacy_family_slot_signals.size() == 1
		and int(
			legacy_family_slot_signals[0].get(
				"character_id",
				-1
			)
		) == 0,
		"Existing family slot removal signal remains intact"
	)
	_assert(
		_semantic("business_role_changed").is_empty()
		and EventManager.active_event == null,
		"Staff removal also stays outside Event semantic dispatch"
	)


func _test_family_role_assignment_and_removal() -> void:
	var character := _character(1)
	var business := _business_fixture(
		"business_family_role",
		"hospital",
		1,
		"phase5e_plot_family"
	)
	var slot_id := _first_slot_id(
		"hospital",
		1
	)
	_setup_world(
		[character],
		[_system_event("phase5e_role", "business_role_changed", true)],
		[business]
	)

	CareerManager.active_job_offers[1] = {
		"character_id": 1,
		"job_id": 2001,
		"company_id": "phase5e_company",
		"salary": 1000
	}

	_assert(
		BusinessManager.assign_character_to_slot(
			"business_family_role",
			slot_id,
			1
		),
		"Playable family Character assignment remains BusinessManager-owned"
	)
	_assert(
		BusinessManager.get_character_assignment(1).get(
			"slot_id",
			""
		) == slot_id
		and character.get("job_id", null) == null
		and not CareerManager.active_job_offers.has(1),
		"Existing external-job cleanup on Family Business assignment is preserved"
	)
	_assert(
		role_transitions.size() == 1
		and role_transitions[0].previous_occupant.is_empty()
		and String(
			role_transitions[0].new_occupant.get(
				"source_type",
				""
			)
		) == "family"
		and int(
			role_transitions[0].new_occupant.get(
				"id",
				0
			)
		) == 1
		and String(role_transitions[0].reason) == "character_assigned",
		"Family assignment emits one precise post-success slot transition"
	)
	_assert(
		legacy_family_slot_signals.size() == 1
		and int(legacy_family_slot_signals[0].character_id) == 1,
		"Existing family_business_slot_changed signal remains intact for existing consumers"
	)

	var occurrences := _semantic("business_role_changed")
	_assert(
		occurrences.size() == 1
		and _context_matches(
			occurrences[0],
			{
				"business_instance_id": "business_family_role",
				"slot_id": slot_id,
				"source_type": "family",
				"character_id": 1,
				"previous_source_type": ""
			}
		)
		and _active_event_is(
			"phase5e_role",
			1
		),
		"Family assignment dispatches one character-bound business_role_changed occurrence"
	)

	_cancel_all_events()
	_clear_captures()

	_assert(
		BusinessManager.remove_character_from_slot(
			"business_family_role",
			slot_id
		),
		"Playable family Character removal remains BusinessManager-owned"
	)
	_assert(
		BusinessManager.get_character_assignment(1).is_empty()
		and String(
			character.get(
				"unemployment_start_date",
				""
			)
		) == TimeManager.get_iso_date_string(),
		"Existing removal state and external-offer eligibility timing are preserved"
	)
	_assert(
		role_transitions.size() == 1
		and String(
			role_transitions[0].previous_occupant.get(
				"source_type",
				""
			)
		) == "family"
		and role_transitions[0].new_occupant.is_empty()
		and String(role_transitions[0].reason) == "character_removed",
		"Family removal emits one precise previous-to-empty transition"
	)
	_assert(
		legacy_family_slot_signals.size() == 1
		and int(legacy_family_slot_signals[0].character_id) == 0,
		"Legacy family slot removal signal still emits zero occupant exactly as before"
	)
	occurrences = _semantic("business_role_changed")
	_assert(
		occurrences.size() == 1
		and _context_matches(
			occurrences[0],
			{
				"previous_source_type": "family",
				"previous_character_id": 1,
				"source_type": "",
				"character_id": 0
			}
		)
		and _active_event_is(
			"phase5e_role",
			1
		),
		"Family removal retains the removed Character as primary semantic participant"
	)
	_cancel_all_events()


func _test_family_role_replacement_is_one_semantic_transition() -> void:
	var previous := _character(1)
	previous["job_id"] = null
	previous["company_id"] = null
	previous["salary"] = 0
	var replacement := _character(2)
	var business := _business_fixture(
		"business_replace",
		"hospital",
		1,
		"phase5e_plot_replace"
	)
	var slot_id := _first_slot_id(
		"hospital",
		1
	)
	var slot := _slot_from_fixture(
		business,
		slot_id
	)
	slot["assigned_character_id"] = 1

	_setup_world(
		[previous, replacement],
		[_system_event("phase5e_role", "business_role_changed", true)],
		[business]
	)

	_assert(
		BusinessManager.replace_slot_with_character(
			"business_replace",
			slot_id,
			2
		),
		"Existing occupied-slot family replacement succeeds"
	)
	_assert(
		int(
			BusinessManager.get_slot(
				"business_replace",
				slot_id
			).get(
				"assigned_character_id",
				0
			)
		) == 2
		and BusinessManager.get_character_assignment(1).is_empty(),
		"Replacement preserves canonical final staffing state"
	)
	_assert(
		role_transitions.size() == 1
		and int(
			role_transitions[0].previous_occupant.get(
				"id",
				0
			)
		) == 1
		and int(
			role_transitions[0].new_occupant.get(
				"id",
				0
			)
		) == 2
		and String(role_transitions[0].reason) == "slot_replaced",
		"Replacement is exposed to Event integration as one logical slot transition"
	)
	_assert(
		legacy_family_slot_signals.size() == 2
		and int(legacy_family_slot_signals[0].character_id) == 0
		and int(legacy_family_slot_signals[1].character_id) == 2,
		"Existing two-step legacy replacement signals are preserved for current UI/autosave consumers"
	)
	_assert(
		_semantic("business_role_changed").size() == 1
		and _active_event_is(
			"phase5e_role",
			2
		),
		"One replacement creates exactly one business_role_changed semantic Event"
	)
	_cancel_all_events()


func _test_npc_role_assignment_and_removal() -> void:
	var business := _business_fixture(
		"business_npc_role",
		"hospital",
		1,
		"phase5e_plot_npc"
	)
	var slot_id := _first_slot_id(
		"hospital",
		1
	)
	var worker := _worker_npc(
		"npc_phase5e"
	)

	_setup_world(
		[],
		[_system_event("phase5e_npc_role", "business_role_changed", false)],
		[business],
		[worker]
	)

	_assert(
		BusinessManager.assign_npc_to_slot(
			"business_npc_role",
			slot_id,
			"npc_phase5e"
		),
		"Worker NPC assignment remains BusinessManager-owned"
	)
	_assert(
		role_transitions.size() == 1
		and String(
			role_transitions[0].new_occupant.get(
				"source_type",
				""
			)
		) == "npc"
		and String(
			role_transitions[0].new_occupant.get(
				"id",
				""
			)
		) == "npc_phase5e",
		"NPC assignment emits one precise post-success role transition"
	)
	_assert(
		legacy_npc_slot_signals.size() == 1
		and String(legacy_npc_slot_signals[0].npc_id) == "npc_phase5e",
		"Existing family_business_npc_slot_changed assignment signal remains intact"
	)
	_assert(
		_semantic("business_role_changed").size() == 1
		and _context_matches(
			_semantic("business_role_changed")[0],
			{
				"source_type": "npc",
				"npc_id": "npc_phase5e",
				"character_id": 0
			}
		)
		and EventManager.active_event != null
		and EventManager.active_event.event_id == "phase5e_npc_role",
		"NPC assignment queues one context-only business_role_changed Event"
	)

	_cancel_all_events()
	_clear_captures()

	_assert(
		BusinessManager.remove_npc_from_slot(
			"business_npc_role",
			slot_id
		),
		"Worker NPC removal remains BusinessManager-owned"
	)
	_assert(
		role_transitions.size() == 1
		and String(
			role_transitions[0].previous_occupant.get(
				"id",
				""
			)
		) == "npc_phase5e"
		and role_transitions[0].new_occupant.is_empty(),
		"NPC removal reports the previous worker without storing parallel role state"
	)
	_assert(
		legacy_npc_slot_signals.size() == 1
		and String(legacy_npc_slot_signals[0].npc_id).is_empty(),
		"Existing NPC removal signal still publishes an empty occupant ID"
	)
	_assert(
		_semantic("business_role_changed").size() == 1
		and _context_matches(
			_semantic("business_role_changed")[0],
			{
				"previous_source_type": "npc",
				"previous_npc_id": "npc_phase5e",
				"source_type": ""
			}
		),
		"NPC removal dispatches one authoritative business_role_changed context"
	)
	_cancel_all_events()


func _test_live_business_requirements() -> void:
	var character := _character(1)
	character["job_id"] = null
	character["company_id"] = null
	character["salary"] = 0
	var business := _business_fixture(
		"business_requirements",
		"hospital",
		1,
		"phase5e_plot_requirements"
	)
	var slot_id := _first_slot_id(
		"hospital",
		1
	)
	var slot := _slot_from_fixture(
		business,
		slot_id
	)
	slot["assigned_character_id"] = 1

	_setup_world(
		[character],
		[],
		[business]
	)

	var evaluator := RequirementEvaluator.new(
		EventRuntimeQueryProvider.new()
	)

	_assert(
		bool(
			evaluator.evaluate(
				{
					"all": [
						{
							"type": "business_owned",
							"operator": "==",
							"value": true
						}
					]
				}
			).get(
				"eligible",
				false
			)
		),
		"business_owned requirement reads live BusinessManager ownership"
	)

	_assert(
		bool(
			evaluator.evaluate(
				{
					"all": [
						{
							"type": "business_type",
							"target": "business",
							"operator": "==",
							"value": "hospital"
						},
						{
							"type": "business_level",
							"target": "business",
							"operator": "==",
							"value": 1
						}
					]
				},
				{"business": "business_requirements"},
				{}
			).get(
				"eligible",
				false
			)
		),
		"business_type and business_level requirements read the authoritative Business instance"
	)

	_assert(
		bool(
			evaluator.evaluate(
				{
					"all": [
						{
							"type": "business_role",
							"target": "primary",
							"operator": "==",
							"value": slot_id
						}
					]
				},
				{"primary": 1},
				{}
			).get(
				"eligible",
				false
			)
		),
		"business_role requirement reads the live Character slot assignment"
	)

	GameManager.family_money = 10000000
	BusinessManager.upgrade_business(
		"business_requirements"
	)
	var level_two_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "business_level",
					"target": "business",
					"operator": "==",
					"value": 2
				}
			]
		},
		{"business": "business_requirements"},
		{}
	)
	_assert(
		bool(level_two_result.get("eligible", false)),
		"business_level requirement updates immediately after canonical upgrade"
	)

	BusinessManager.remove_character_from_slot(
		"business_requirements",
		slot_id
	)
	var removed_role_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "business_role",
					"target": "primary",
					"operator": "==",
					"value": slot_id
				}
			]
		},
		{"primary": 1},
		{}
	)
	_assert(
		not bool(
			removed_role_result.get(
				"eligible",
				true
			)
		),
		"business_role requirement updates live after canonical removal"
	)

	BusinessManager.businesses = []
	var no_business_result := evaluator.evaluate(
		{
			"all": [
				{
					"type": "business_owned",
					"operator": "==",
					"value": false
				}
			]
		}
	)
	_assert(
		bool(
			no_business_result.get(
				"eligible",
				false
			)
		),
		"business_owned requirement updates live without duplicate Event-owned state"
	)
	_cancel_all_events()


func _test_save_load_without_business_semantic_replay() -> void:
	var character := _character(1)
	character["job_id"] = null
	character["company_id"] = null
	character["salary"] = 0

	var business := _business_fixture(
		"business_save",
		"hospital",
		2,
		"phase5e_plot_save"
	)
	var slot_id := _first_slot_id(
		"hospital",
		2
	)
	var slot := _slot_from_fixture(
		business,
		slot_id
	)
	slot["assigned_character_id"] = 1

	_setup_world(
		[character],
		[
			_system_event("phase5e_purchase", "business_purchased", false),
			_system_event("phase5e_upgrade", "business_upgraded", false),
			_system_event("phase5e_role", "business_role_changed", true)
		],
		[business]
	)

	var snapshot = JSON.parse_string(
		JSON.stringify(
			SaveManager.create_save_snapshot()
		)
	)

	_clear_captures()
	BusinessManager.businesses = []
	EventManager.reset_runtime_state()

	var loaded := SaveManager.apply_save_snapshot(
		snapshot
	)

	_assert(
		loaded
		and int(
			BusinessManager.get_business_by_instance_id(
				"business_save"
			).get(
				"level",
				0
			)
		) == 2
		and String(
			BusinessManager.get_character_assignment(
				1
			).get(
				"slot_id",
				""
			)
		) == slot_id,
		"Save/load restores Business level and staffing state"
	)
	_assert(
		role_transitions.is_empty()
		and _business_semantics().is_empty(),
		"Business restore emits no purchase, upgrade, or role semantic replay"
	)
	_assert(
		int(SaveManager.SAVE_VERSION) == 6,
		"Phase 5E leaves SAVE_VERSION 6 unchanged"
	)
	_cancel_all_events()


func _setup_world(
	characters: Array,
	events: Array,
	businesses: Array,
	workers: Array = []
) -> void:
	SaveManager.current_save_id = -1
	CharacterManager.characters = characters
	CharacterManager.next_character_id = 100
	CareerManager.active_job_offers.clear()
	BusinessManager.businesses = businesses
	BusinessManager.next_business_instance_number = 1
	NPCManager.worker_npcs = workers
	NPCManager.next_worker_npc_number = 100

	HouseManager.houses = []
	GameManager.family_money = 10000000
	GameManager.diamonds = 100
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
	var loaded := registry.load_from_json_sources(
		{
			"business.json": JSON.stringify(
				{
					"schema_version": 1,
					"category": "business",
					"pools": [],
					"events": events
				}
			)
		}
	)
	_assert(
		loaded,
		"Phase 5E fixture registry validates",
		registry.get_diagnostic_text()
	)
	EventManager.configure_runtime(
		registry,
		null,
		83
	)


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
		"category": "business",
		"domain": "business",
		"subtype": "phase5e_fixture",
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
			"description": "Phase 5E fixture"
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


func _upgrade_source_event() -> Dictionary:
	return {
		"event_id": "phase5e_upgrade_source",
		"category": "business",
		"domain": "business",
		"subtype": "phase5e_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 10,
		"exclusive_group": null,
		"trigger": {
			"type": "system",
			"event": "phase5e_upgrade_request"
		},
		"participants": {
			"business": {
				"type": "business",
				"source": "context"
			}
		},
		"requirements": {"all": []},
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {
			"blocking": false,
			"pause_game": false
		},
		"content": {
			"title": "Upgrade source",
			"description": "Phase 5E fixture"
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
					"effects": [
						{
							"type": "business_upgrade",
							"business": "business"
						}
					]
				}
			}
		]
	}


func _business_fixture(
	instance_id: String,
	business_type_id: String,
	level: int,
	plot_id: String
) -> Dictionary:
	var slots: Array = []
	for definition_value in BusinessManager.get_level_slot_definitions(
		business_type_id,
		level
	):
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		slots.append(
			{
				"slot_id": String(
					definition.get(
						"slot_id",
						""
					)
				),
				"assigned_character_id": null,
				"assigned_npc_id": null
			}
		)
	return {
		"business_instance_id": instance_id,
		"business_type_id": business_type_id,
		"plot_id": plot_id,
		"level": level,
		"slots": slots
	}


func _first_slot_id(
	business_type_id: String,
	level: int
) -> String:
	var definitions := BusinessManager.get_level_slot_definitions(
		business_type_id,
		level
	)
	if definitions.is_empty():
		return ""
	return String(
		(definitions[0] as Dictionary).get(
			"slot_id",
			""
		)
	)


func _slot_from_fixture(
	business: Dictionary,
	slot_id: String
) -> Dictionary:
	for value in business.get("slots", []):
		if (
			value is Dictionary
			and String(
				value.get(
					"slot_id",
					""
				)
			) == slot_id
		):
			return value
	return {}


func _character(character_id: int) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": "family",
		"linked_character_id": null,
		"relationship_status": "",
		"first_name": "Business",
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
		"flag_ids": [],
		"health": 100,
		"happiness": 100,
		"logic": 100,
		"attractiveness": 100,
		"social": 100,
		"confidence": 100,
		"discipline": 100,
		"creativity": 100,
		"job_id": 2001,
		"company_id": "phase5e_company",
		"salary": 5000,
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


func _worker_npc(
	npc_id: String
) -> Dictionary:
	return {
		"id": npc_id,
		"first_name": "Worker",
		"last_name": "Adapter",
		"gender": "female",
		"birth_date": "1955-01-01",
		"portrait_path": "",
		"stats": {
			"health": 100,
			"logic": 100,
			"discipline": 100,
			"creativity": 100,
			"social": 100,
			"confidence": 100,
			"attractiveness": 100,
			"happiness": 100
		},
		"is_retired": false
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


func _semantic(
	name: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(
			occurrence.get(
				"semantic_event",
				""
			)
		) == name:
			result.append(
				occurrence
			)
	return result


func _business_semantics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occurrence in semantic_occurrences:
		if String(
			occurrence.get(
				"semantic_event",
				""
			)
		) in [
			"business_purchased",
			"business_upgraded",
			"business_role_changed"
		]:
			result.append(
				occurrence
			)
	return result


func _context_matches(
	occurrence: Dictionary,
	expected: Dictionary
) -> bool:
	var context = occurrence.get(
		"context",
		{}
	)
	if typeof(context) != TYPE_DICTIONARY:
		return false
	for key in expected:
		if context.get(
			key,
			null
		) != expected[key]:
			return false
	return true


func _cancel_all_events() -> void:
	while EventManager.active_event != null:
		EventManager.cancel_active_event()


func _connect_capture_signals() -> void:
	BusinessManager.family_business_role_transitioned.connect(
		_on_role_transitioned
	)
	BusinessManager.family_business_slot_changed.connect(
		_on_legacy_family_slot_changed
	)
	BusinessManager.family_business_npc_slot_changed.connect(
		_on_legacy_npc_slot_changed
	)
	EventManager.semantic_trigger_dispatched.connect(
		_on_semantic_trigger_dispatched
	)


func _disconnect_capture_signals() -> void:
	BusinessManager.family_business_role_transitioned.disconnect(
		_on_role_transitioned
	)
	BusinessManager.family_business_slot_changed.disconnect(
		_on_legacy_family_slot_changed
	)
	BusinessManager.family_business_npc_slot_changed.disconnect(
		_on_legacy_npc_slot_changed
	)
	EventManager.semantic_trigger_dispatched.disconnect(
		_on_semantic_trigger_dispatched
	)


func _on_role_transitioned(
	business_instance_id: String,
	slot_id: String,
	previous_occupant: Dictionary,
	new_occupant: Dictionary,
	reason: String
) -> void:
	role_transitions.append(
		{
			"business_instance_id": business_instance_id,
			"slot_id": slot_id,
			"previous_occupant": previous_occupant.duplicate(true),
			"new_occupant": new_occupant.duplicate(true),
			"reason": reason
		}
	)


func _on_legacy_family_slot_changed(
	business_instance_id: String,
	slot_id: String,
	character_id: int
) -> void:
	legacy_family_slot_signals.append(
		{
			"business_instance_id": business_instance_id,
			"slot_id": slot_id,
			"character_id": character_id
		}
	)


func _on_legacy_npc_slot_changed(
	business_instance_id: String,
	slot_id: String,
	npc_id: String
) -> void:
	legacy_npc_slot_signals.append(
		{
			"business_instance_id": business_instance_id,
			"slot_id": slot_id,
			"npc_id": npc_id
		}
	)


func _on_semantic_trigger_dispatched(
	occurrence: Dictionary
) -> void:
	semantic_occurrences.append(
		occurrence.duplicate(true)
	)


func _clear_captures() -> void:
	role_transitions.clear()
	legacy_family_slot_signals.clear()
	legacy_npc_slot_signals.clear()
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
