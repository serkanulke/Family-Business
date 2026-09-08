extends Node


const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const HEART_ICON := "res://Resources/Icons/event-modal/heart.svg"
const BROKEN_HEART_ICON := "res://Resources/Icons/event-modal/broken_heart.svg"
const LOCK_ICON := "res://Resources/Icons/event-modal/lock.svg"
const EVENT_ART := "res://Resources/Events/job_offer/job_offer_01.png"

var passed := 0
var failed := 0
var original_state: Dictionary = {}
var original_registry: EventDataRegistry
var render_viewport: SubViewport
var main: MainScreenController
var presentation: EventPresentation


func _ready() -> void:
	_store_state()
	_setup_characters()
	render_viewport = SubViewport.new()
	render_viewport.size = Vector2i(1080, 1920)
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_viewport.canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	)
	add_child(render_viewport)
	main = MAIN_SCENE.instantiate() as MainScreenController
	render_viewport.add_child(main)
	await _wait_frames(5)
	var relationship_debug := main.family_tree_screen.get_node_or_null(
		"RelationshipNPCDebugPanel"
	) as CanvasLayer
	if relationship_debug != null:
		relationship_debug.visible = false
	presentation = main.event_presentation

	await _test_single_event()
	await _test_relationship_and_multiple_results()
	await _test_group_participant_selection()
	await _test_choice_count_variants()
	await _test_missing_optional_resources()

	_restore_state()
	print("")
	print("========================================")
	print("Event Presentation UI tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	get_tree().quit(0 if failed == 0 else 1)


func _test_single_event() -> void:
	var event := _single_event()
	_configure([event])
	GameManager.set_family_money(100)
	_assert(
		bool(EventManager.activate_chain(event.event_id, {"primary": 1}).get("queued", false)),
		"Single Character Event activates through EventManager"
	)
	await _wait_frames(3)
	var snapshot := presentation.get_display_snapshot()
	_assert(snapshot.layout == "single", "One Character uses the single-character layout")
	_assert(snapshot.participant_chip_count == 1, "Single Event shows one Character chip")
	_assert(snapshot.art_path == EVENT_ART, "Event art binds from presentation.art_path")
	_assert(snapshot.choice_states.size() == 2, "Event choices are generated from Event JSON")
	_assert(
		snapshot.choice_states[0].icon_path == HEART_ICON
		and not snapshot.choice_states[0].disabled,
		"Enabled choice uses its authored icon_path"
	)
	_assert(
		snapshot.choice_states[1].icon_path == LOCK_ICON
		and snapshot.choice_states[1].disabled,
		"Locked choice replaces its normal icon with the shared lock asset"
	)
	var name_label := _find_label_with_text(
		presentation.participant_chips[0], "Alexandria-Long-Character-Name"
	)
	_assert(
		name_label != null
		and name_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"Long Character name and age stay on one ellipsized line"
	)
	if _capture_enabled():
		await _capture("event_ui_single_locked.png")

	GameManager.set_family_money(1000)
	await _wait_frames(2)
	snapshot = presentation.get_display_snapshot()
	_assert(
		not snapshot.choice_states[1].disabled
		and snapshot.choice_states[1].icon_path == BROKEN_HEART_ICON,
		"Runtime requirement change refreshes enabled state and restores authored icon"
	)
	GameManager.set_family_money(100)
	await _wait_frames(2)

	var card := main.family_tree_screen.get_node("CharacterCard")
	presentation.participant_chips[0].pressed.emit()
	await _wait_frames(2)
	_assert(card.visible and not presentation.modal_root.visible, "Character chip opens the existing Character Card above the Event")
	card.close_card()
	await _wait_frames(2)
	_assert(presentation.modal_root.visible, "Closing Character Card restores the active Event modal")

	presentation.choice_buttons[0].pressed.emit()
	await _wait_frames(2)
	snapshot = presentation.get_display_snapshot()
	_assert(snapshot.result_visible, "Character stat changes open Event Result")
	_assert(snapshot.result_character_count == 1, "One affected Character renders one result row")
	if _capture_enabled():
		await _capture("event_ui_result_single.png")
	presentation.call("_on_result_continue")
	await _wait_frames(2)
	_assert(not presentation.modal_root.visible, "Continue closes the final Event Result")


func _test_relationship_and_multiple_results() -> void:
	var event := _relationship_event()
	_configure([event])
	GameManager.set_family_money(1000)
	_assert(
		bool(EventManager.activate_chain(
			event.event_id,
			{"primary": 1, "candidate": 4}
		).get("queued", false)),
		"Relationship Event activates with resolved participant roles"
	)
	await _wait_frames(3)
	var snapshot := presentation.get_display_snapshot()
	_assert(snapshot.layout == "relationship", "Two Characters use the relationship layout")
	_assert(snapshot.participant_chip_count == 2, "Relationship layout shows two equal Character chips")
	_assert(
		String(snapshot.description).contains("Jordan")
		and not String(snapshot.description).contains("{candidate_name}"),
		"Relationship participant token resolves from the bound Character"
	)
	if _capture_enabled():
		await _capture("event_ui_relationship.png")

	presentation.choice_buttons[0].pressed.emit()
	await _wait_frames(2)
	snapshot = presentation.get_display_snapshot()
	_assert(snapshot.result_visible, "Relationship stat effects open Event Result")
	_assert(snapshot.result_character_count == 2, "Multiple affected Characters render separate result rows")
	if _capture_enabled():
		await _capture("event_ui_result_multiple.png")
	presentation.call("_on_result_continue")
	await _wait_frames(2)


func _test_group_participant_selection() -> void:
	var event := _group_event()
	_configure([event])
	_assert(main.begin_manual_event(event.event_id), "Manual group Event opens from Event runtime availability")
	await _wait_frames(2)
	var snapshot := presentation.get_display_snapshot()
	_assert(snapshot.layout == "group", "Character-group definition uses the Group Event layout")
	_assert(snapshot.group_count == 0, "Group Event starts with no invented participant count")
	_assert(presentation.group_button.text == "SELECT PARTICIPANTS", "Empty group uses the selection action label")
	if _capture_enabled():
		await _capture("event_ui_group_before_selection.png")

	_assert(presentation.open_participant_selection(), "Group action opens Select Participants bottom sheet")
	await _wait_frames(2)
	snapshot = presentation.get_display_snapshot()
	_assert(snapshot.participant_sheet_visible, "Participant bottom sheet blocks above the Event")
	_assert(snapshot.participant_card_count == 3, "Candidate cards come from family Character selection rules")
	if _capture_enabled():
		await _capture("event_ui_select_participants.png")

	presentation.call("_toggle_participant", 1)
	presentation.call("_toggle_participant", 2)
	await _wait_frames(2)
	_assert(presentation.sheet_selected_ids.size() == 2, "Select/Remove state tracks the pending backend selection")
	presentation.call("_confirm_participant_selection")
	await _wait_frames(3)
	_assert(
		EventManager.active_event != null
		and EventManager.active_event.participants.travel_group == [1, 2],
		"Confirmed selection activates through EventManager with exact participant IDs"
	)
	snapshot = presentation.get_display_snapshot()
	_assert(snapshot.group_count == 2, "Group count refreshes from active Event participants")
	_assert(presentation.group_button.text == "2 PARTICIPANTS", "Group count uses correct plural text")
	if _capture_enabled():
		await _capture("event_ui_group_after_selection.png")

	_assert(presentation.open_participant_selection(), "Active Group Event can reopen participant selection")
	presentation.call("_toggle_participant", 2)
	presentation.call("_toggle_participant", 3)
	presentation.call("_confirm_participant_selection")
	await _wait_frames(2)
	_assert(
		EventManager.active_event.participants.travel_group == [1, 3],
		"Active group rebind uses EventManager participant validation"
	)
	EventManager.cancel_active_event()
	await _wait_frames(2)


func _test_missing_optional_resources() -> void:
	var event := _single_event()
	event.event_id = "ui_missing_resources"
	event.presentation.erase("art_path")
	event.choices[0].erase("icon_path")
	event.choices[1].erase("icon_path")
	event.choices[1].requirements = {"all": []}
	_configure([event])
	GameManager.set_family_money(1000)
	EventManager.activate_chain(event.event_id, {"primary": 1})
	await _wait_frames(2)
	var snapshot := presentation.get_display_snapshot()
	_assert(snapshot.art_path.is_empty(), "Missing art_path leaves the Event art area safe and empty")
	_assert(
		snapshot.choice_states[0].icon_path.is_empty(),
		"Missing enabled choice icon_path remains empty without a fallback mapping"
	)
	EventManager.cancel_active_event()
	await _wait_frames(2)


func _test_choice_count_variants() -> void:
	var event := _single_event()
	event.event_id = "ui_many_choices"
	for index in range(2):
		var extra_choice: Dictionary = event.choices[0].duplicate(true)
		extra_choice.choice_id = "extra_%d" % index
		extra_choice.title = "EXTRA OPTION %d" % (index + 1)
		event.choices.append(extra_choice)
	_configure([event])
	GameManager.set_family_money(1000)
	EventManager.activate_chain(event.event_id, {"primary": 1})
	await _wait_frames(3)
	_assert(
		presentation.choice_buttons.size() == 4,
		"Three-plus Event choices are generated without fixed choice slots"
	)
	var last_choice := presentation.choice_buttons[-1]
	_assert(
		last_choice.global_position.y + last_choice.size.y
		<= presentation.event_panel.global_position.y + presentation.event_panel.size.y,
		"Three-plus Event choices stay inside the bounded production modal"
	)
	EventManager.cancel_active_event()
	await _wait_frames(2)


func _single_event() -> Dictionary:
	var event := _base_event("ui_single")
	event.participants = {"primary": {"type": "character", "source": "trigger"}}
	event.presentation.art_path = EVENT_ART
	event.content = {
		"title": "A CAREER MOMENT",
		"subtitle": null,
		"description": "{character_name} has an important decision to make."
	}
	event.choices = [
		{
			"choice_id": "accept",
			"title": "MOVE FORWARD",
			"description": "Take the opportunity.",
			"icon_path": HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": [
					{"type": "stat_change", "target": "primary", "stat": "health", "amount": 4},
					{"type": "stat_change", "target": "primary", "stat": "happiness", "amount": 20},
					{"type": "stat_change", "target": "primary", "stat": "creativity", "amount": -10}
				]
			}
		},
		{
			"choice_id": "costly",
			"title": "A COSTLY OPTION",
			"description": "Choose the expensive route.",
			"icon_path": BROKEN_HEART_ICON,
			"requirements": {"all": [{"type": "money", "operator": ">=", "value": 500}]},
			"resolution": {"mode": "deterministic", "effects": []}
		}
	]
	return event


func _relationship_event() -> Dictionary:
	var event := _base_event("ui_relationship")
	event.participants = {
		"primary": {"type": "character", "source": "trigger"},
		"candidate": {"type": "relationship_npc", "source": "trigger"}
	}
	event.presentation.art_path = "res://Resources/Events/relationship/relationship_01.png"
	event.content = {
		"title": "A NEW CONNECTION!",
		"subtitle": null,
		"description": "{character_name} and {candidate_name} enjoy spending time together."
	}
	event.choices = [{
		"choice_id": "continue",
		"title": "SHOW INTEREST",
		"description": "See where the connection leads.",
		"icon_path": HEART_ICON,
		"requirements": {"all": []},
		"resolution": {
			"mode": "deterministic",
			"effects": [
				{"type": "stat_change", "target": "primary", "stat": "health", "amount": 4},
				{"type": "stat_change", "target": "candidate", "stat": "happiness", "amount": 20},
				{"type": "stat_change", "target": "candidate", "stat": "creativity", "amount": -10}
			]
		}
	}]
	return event


func _group_event() -> Dictionary:
	var event := _base_event("ui_group")
	event.trigger = {"type": "manual", "source": "lifestyle", "mode": "direct"}
	event.participants = {"travel_group": {
		"type": "character_group",
		"source": "player_selected",
		"min": 2,
		"max": 3,
		"requirements": {"all": [
			{"type": "is_alive", "target": "travel_group", "operator": "==", "value": true}
		]},
		"selection_ui": {
			"title": "SELECT PARTICIPANTS",
			"description": "Select family members for this event",
			"show_ineligible": true,
			"show_relevant_stats": [
				"happiness", "health", "logic", "confidence",
				"social", "attractiveness", "discipline", "creativity"
			]
		}
	}}
	event.content = {
		"title": "A FAMILY OUTING",
		"subtitle": null,
		"description": "Choose who will take part in this family event."
	}
	event.choices = [{
		"choice_id": "continue",
		"title": "CONTINUE",
		"description": "Begin with the selected participants.",
		"requirements": {"all": []},
		"resolution": {"mode": "deterministic", "effects": []}
	}]
	return event


func _base_event(event_id: String) -> Dictionary:
	return {
		"event_id": event_id,
		"category": "lifestyle",
		"domain": "lifestyle",
		"subtype": "event_ui_fixture",
		"enabled": true,
		"rarity": "common",
		"weight": 1.0,
		"priority": 0,
		"exclusive_group": null,
		"pool_id": null,
		"trigger": {"type": "chain"},
		"participants": {},
		"requirements": {"all": []},
		"repeat": {"mode": "repeatable"},
		"cooldown": null,
		"behavior": {"blocking": true, "pause_game": true},
		"content": {"title": "Event UI", "subtitle": null, "description": "UI fixture"},
		"presentation": {"template": "standard_event"},
		"choices": []
	}


func _configure(events: Array) -> void:
	var registry := EventDataRegistry.new()
	var document := {
		"schema_version": 1,
		"category": "lifestyle",
		"pools": [],
		"events": events
	}
	var loaded := registry.load_from_json_sources({
		"lifestyle.json": JSON.stringify(document)
	})
	_assert(loaded, "Event UI fixture registry validates", registry.get_diagnostic_text())
	EventManager.configure_runtime(registry, null, 77)


func _setup_characters() -> void:
	CharacterManager.characters = [
		_character(1, "Alexandria-Long-Character-Name", true, "1973-01-26", "female", 80),
		_character(2, "Sam", true, "1968-06-12", "female", 72),
		_character(3, "Taylor", true, "1978-03-02", "female", 64),
		_character(4, "Jordan", false, "1972-07-18", "female", 76)
	]
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	GameManager.family_money = 1000
	GameManager.diamonds = 100


func _character(
	id: int,
	first_name: String,
	family: bool,
	birth_date: String,
	gender: String,
	stat: int
) -> Dictionary:
	return {
		"character_id": id,
		"character_type": "family" if family else "relationship_npc",
		"linked_character_id": 1 if not family else null,
		"first_name": first_name,
		"gender": gender,
		"skin_tone": "light",
		"genetics": {"skin_tone": "light"},
		"portrait_variant_id": "001",
		"birth_date": birth_date,
		"life_stage": "young_adult",
		"is_alive": true,
		"is_player_family": family,
		"parent_ids": [],
		"children_ids": [],
		"partner_id": null,
		"relationship_status": "candidate" if not family else null,
		"relationship_cooldown_until": null,
		"flag_ids": [],
		"health": stat,
		"happiness": stat,
		"logic": stat,
		"attractiveness": stat,
		"social": stat,
		"confidence": stat,
		"discipline": stat,
		"creativity": stat,
		"job_id": null,
		"company_id": null,
		"salary": 0,
		"school_id": null,
		"major_id": null,
		"event_log": []
	}


func _find_label_with_text(root: Node, fragment: String) -> Label:
	if root is Label and String(root.text).contains(fragment):
		return root as Label
	for child in root.get_children():
		var result := _find_label_with_text(child, fragment)
		if result != null:
			return result
	return null


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _capture_enabled() -> bool:
	return "--capture" in OS.get_cmdline_user_args()


func _capture(file_name: String) -> void:
	await _wait_frames(2)
	var image := render_viewport.get_texture().get_image()
	if image == null:
		_assert(false, "Visual capture reads rendered viewport: " + file_name)
		return
	var path := "res://Tests/Artifacts/" + file_name
	var error := image.save_png(ProjectSettings.globalize_path(path))
	_assert(error == OK, "Visual capture saves: " + file_name)


func _store_state() -> void:
	original_registry = EventManager.registry
	original_state = {
		"characters": CharacterManager.characters.duplicate(true),
		"money": GameManager.family_money,
		"diamonds": GameManager.diamonds,
		"year": TimeManager.current_year,
		"month": TimeManager.current_month,
		"day": TimeManager.current_day,
		"paused": TimeManager.is_paused,
		"speed": TimeManager.speed_multiplier
	}


func _restore_state() -> void:
	if original_registry != null:
		EventManager.configure_runtime(original_registry)
	CharacterManager.characters = original_state.characters
	GameManager.family_money = original_state.money
	GameManager.diamonds = original_state.diamonds
	TimeManager.current_year = original_state.year
	TimeManager.current_month = original_state.month
	TimeManager.current_day = original_state.day
	TimeManager.is_paused = original_state.paused
	TimeManager.speed_multiplier = original_state.speed


func _assert(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		push_error("[FAIL] " + name)
		if not detail.is_empty():
			print(detail)
