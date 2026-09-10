extends Node


const MAIN_SCENE := preload("res://Scenes/Main/Main.tscn")
const HEART_ICON := "res://Resources/Icons/event-modal/heart.svg"
const BROKEN_HEART_ICON := "res://Resources/Icons/event-modal/broken_heart.svg"
const EVENT_ART := "res://Resources/Events/job_offer/job_offer_01.png"
const RELATIONSHIP_ART := "res://Resources/Events/relationship/relationship_01.png"

var original_state: Dictionary = {}
var original_registry: EventDataRegistry

var main: MainScreenController
var presentation: EventPresentation

var control_layer: CanvasLayer
var diagnostics_label: Label
var current_scenario := "Ready"


func _ready() -> void:
	_store_state()
	_setup_characters()

	main = MAIN_SCENE.instantiate() as MainScreenController
	add_child(main)

	await _wait_frames(5)

	var relationship_debug := main.family_tree_screen.get_node_or_null(
		"RelationshipNPCDebugPanel"
	) as CanvasLayer
	if relationship_debug != null:
		relationship_debug.visible = false

	presentation = main.event_presentation
	_build_manual_controls()

	# Open a representative state immediately so F6 shows something useful.
	await _show_single_three_choices()


func _exit_tree() -> void:
	_restore_state()


func _process(_delta: float) -> void:
	if presentation == null or diagnostics_label == null:
		return
	_update_diagnostics()


func _build_manual_controls() -> void:
	control_layer = CanvasLayer.new()
	control_layer.name = "ManualEventUIControls"
	control_layer.layer = 100
	add_child(control_layer)

	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 300.0
	control_layer.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.94)
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "EVENT UI MANUAL TEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(title)

	diagnostics_label = Label.new()
	diagnostics_label.text = "Ready"
	diagnostics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostics_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	diagnostics_label.add_theme_font_size_override("font_size", 18)
	diagnostics_label.add_theme_color_override("font_color", Color("#F4D9B9"))
	root.add_child(diagnostics_label)

	var row_one := HBoxContainer.new()
	row_one.add_theme_constant_override("separation", 8)
	root.add_child(row_one)
	_add_control_button(row_one, "Single Locked", _show_single_locked)
	_add_control_button(row_one, "Single Open", _show_single_open)
	_add_control_button(row_one, "Single 3 Choices", _show_single_three_choices)
	_add_control_button(row_one, "Long Name", _show_long_name)

	var row_two := HBoxContainer.new()
	row_two.add_theme_constant_override("separation", 8)
	root.add_child(row_two)
	_add_control_button(row_two, "Relationship", _show_relationship)
	_add_control_button(row_two, "Group Empty", _show_group_empty)
	_add_control_button(row_two, "Group 5", _show_group_five)
	_add_control_button(row_two, "Select Sheet", _show_group_sheet)

	var row_three := HBoxContainer.new()
	row_three.add_theme_constant_override("separation", 8)
	root.add_child(row_three)
	_add_control_button(row_three, "Result 1", _show_result_single)
	_add_control_button(row_three, "Result 2", _show_result_relationship)
	_add_control_button(row_three, "Cancel Active", _cancel_active)
	_add_control_button(row_three, "Reload Current", _reload_current)


func _add_control_button(
	parent: HBoxContainer,
	label_text: String,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)


func _show_single_locked() -> void:
	current_scenario = "Single / 2 Choices / Locked"
	var event := _single_event("manual_single_locked", false, 2)
	_configure([event])
	GameManager.set_family_money(100)
	EventManager.activate_chain(event["event_id"], {"primary": 1})
	await _wait_frames(3)


func _show_single_open() -> void:
	current_scenario = "Single / 2 Choices / Open"
	var event := _single_event("manual_single_open", false, 2)
	_configure([event])
	GameManager.set_family_money(1000)
	EventManager.activate_chain(event["event_id"], {"primary": 2})
	await _wait_frames(3)


func _show_single_three_choices() -> void:
	current_scenario = "Single / 3 Choices"
	var event := _single_event("manual_single_three", false, 3)
	_configure([event])
	GameManager.set_family_money(100)
	EventManager.activate_chain(event["event_id"], {"primary": 2})
	await _wait_frames(3)


func _show_long_name() -> void:
	current_scenario = "Single / Long Character Name"
	var event := _single_event("manual_long_name", true, 3)
	_configure([event])
	GameManager.set_family_money(1000)
	EventManager.activate_chain(event["event_id"], {"primary": 1})
	await _wait_frames(3)


func _show_relationship() -> void:
	current_scenario = "Relationship / 3 Choices"
	var event := _relationship_event("manual_relationship")
	_configure([event])
	GameManager.set_family_money(100)
	EventManager.activate_chain(
		event["event_id"],
		{"primary": 2, "candidate": 7}
	)
	await _wait_frames(3)


func _show_group_empty() -> void:
	current_scenario = "Group / No Participants"
	var event := _group_event("manual_group_empty")
	_configure([event])
	main.begin_manual_event(event["event_id"])
	await _wait_frames(3)


func _show_group_five() -> void:
	current_scenario = "Group / 5 Participants"
	var event := _group_event("manual_group_five")
	_configure([event])
	EventManager.activate_manual_direct(
		event["event_id"],
		{
			"selected_participants": {
				"travel_group": [1, 2, 3, 4, 5]
			}
		}
	)
	await _wait_frames(3)


func _show_group_sheet() -> void:
	current_scenario = "Group / Select Participants Sheet"
	var event := _group_event("manual_group_sheet")
	_configure([event])
	main.begin_manual_event(event["event_id"])
	await _wait_frames(2)
	presentation.open_participant_selection()
	await _wait_frames(3)


func _show_result_single() -> void:
	current_scenario = "Event Result / 1 Character"
	var event := _single_event("manual_result_single", false, 2)
	_configure([event])
	GameManager.set_family_money(1000)
	EventManager.activate_chain(event["event_id"], {"primary": 2})
	await _wait_frames(3)
	if not presentation.choice_buttons.is_empty():
		presentation.choice_buttons[0].pressed.emit()
	await _wait_frames(3)


func _show_result_relationship() -> void:
	current_scenario = "Event Result / 2 Characters"
	var event := _relationship_event("manual_result_relationship")
	_configure([event])
	GameManager.set_family_money(1000)
	EventManager.activate_chain(
		event["event_id"],
		{"primary": 2, "candidate": 7}
	)
	await _wait_frames(3)
	if not presentation.choice_buttons.is_empty():
		presentation.choice_buttons[0].pressed.emit()
	await _wait_frames(3)


func _cancel_active() -> void:
	current_scenario = "Cancelled"
	if presentation != null and presentation.participant_overlay.visible:
		presentation.close_participant_selection()
	if EventManager.active_event != null:
		EventManager.cancel_active_event()
	elif presentation != null:
		presentation.pending_event_id = ""
		presentation.pending_runtime_context.clear()
		presentation.current_instance.clear()
		presentation.current_definition.clear()
		presentation.modal_root.visible = false
	await _wait_frames(2)


func _reload_current() -> void:
	match current_scenario:
		"Single / 2 Choices / Locked":
			await _show_single_locked()
		"Single / 2 Choices / Open":
			await _show_single_open()
		"Single / 3 Choices":
			await _show_single_three_choices()
		"Single / Long Character Name":
			await _show_long_name()
		"Relationship / 3 Choices":
			await _show_relationship()
		"Group / No Participants":
			await _show_group_empty()
		"Group / 5 Participants":
			await _show_group_five()
		"Group / Select Participants Sheet":
			await _show_group_sheet()
		"Event Result / 1 Character":
			await _show_result_single()
		"Event Result / 2 Characters":
			await _show_result_relationship()
		_:
			await _show_single_three_choices()


func _update_diagnostics() -> void:
	var mode := "NONE"
	var panel_size := Vector2.ZERO
	var scroll: ScrollContainer = null

	if presentation.participant_overlay.visible:
		mode = "PARTICIPANT SHEET (scroll expected)"
		panel_size = presentation.participant_sheet.size
		scroll = presentation.participant_scroll
	elif presentation.result_is_visible:
		mode = "RESULT"
		panel_size = presentation.result_panel.size
		scroll = presentation.result_scroll
	elif presentation.modal_root.visible:
		mode = "EVENT"
		panel_size = presentation.event_panel.size
		scroll = presentation.event_scroll

	var scroll_text := "n/a"
	if scroll != null:
		var bar := scroll.get_v_scroll_bar()
		var scrollable := bar.max_value > bar.page + 1.0
		scroll_text = "%s  max=%.0f page=%.0f value=%.0f" % [
			"YES" if scrollable else "NO",
			bar.max_value,
			bar.page,
			bar.value
		]

	diagnostics_label.text = (
		"%s | %s | panel %.0f×%.0f | vertical scroll: %s"
		% [
			current_scenario,
			mode,
			panel_size.x,
			panel_size.y,
			scroll_text
		]
	)


func _single_event(
	event_id: String,
	long_name_fixture: bool,
	choice_count: int
) -> Dictionary:
	var event := _base_event(event_id)
	event["participants"] = {
		"primary": {
			"type": "character",
			"source": "trigger"
		}
	}
	event["presentation"]["art_path"] = EVENT_ART
	event["content"] = {
		"title": "A CAREER MOMENT",
		"subtitle": null,
		"description": (
			"{character_name} has an important decision to make. "
			+ "This description is intentionally long enough to expose "
			+ "the real production spacing and modal-height behavior."
		)
	}

	var choices: Array = [
		{
			"choice_id": "accept",
			"title": "MOVE FORWARD",
			"description": "Take the opportunity and see what happens next.",
			"icon_path": HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": [
					{
						"type": "stat_change",
						"target": "primary",
						"stat": "health",
						"amount": 4
					},
					{
						"type": "stat_change",
						"target": "primary",
						"stat": "happiness",
						"amount": 20
					},
					{
						"type": "stat_change",
						"target": "primary",
						"stat": "creativity",
						"amount": -10
					}
				]
			}
		},
		{
			"choice_id": "costly",
			"title": "A COSTLY OPTION",
			"description": "Requires enough family money to unlock.",
			"icon_path": BROKEN_HEART_ICON,
			"requirements": {
				"all": [
					{
						"type": "money",
						"operator": ">=",
						"value": 500
					}
				]
			},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		}
	]

	if choice_count >= 3:
		choices.append({
			"choice_id": "third_option",
			"title": "A THIRD OPTION",
			"description": "A third production choice used to inspect modal height.",
			"icon_path": HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		})

	event["choices"] = choices

	if long_name_fixture:
		event["content"]["description"] = (
			"{character_name} is intentionally using the long-name fixture. "
			+ "The Character chip must remain on one line and use ellipsis."
		)

	return event


func _relationship_event(event_id: String) -> Dictionary:
	var event := _base_event(event_id)
	event["participants"] = {
		"primary": {
			"type": "character",
			"source": "trigger"
		},
		"candidate": {
			"type": "relationship_npc",
			"source": "trigger"
		}
	}
	event["presentation"]["art_path"] = RELATIONSHIP_ART
	event["content"] = {
		"title": "A NEW CONNECTION!",
		"subtitle": null,
		"description": (
			"{character_name} and {candidate_name} cross paths at a social event. "
			+ "Their conversation feels natural and enjoyable."
		)
	}
	event["choices"] = [
		{
			"choice_id": "show_interest",
			"title": "SHOW INTEREST",
			"description": "Take a chance and build a connection.",
			"icon_path": HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": [
					{
						"type": "stat_change",
						"target": "primary",
						"stat": "health",
						"amount": 4
					},
					{
						"type": "stat_change",
						"target": "primary",
						"stat": "happiness",
						"amount": 20
					},
					{
						"type": "stat_change",
						"target": "candidate",
						"stat": "health",
						"amount": 4
					},
					{
						"type": "stat_change",
						"target": "candidate",
						"stat": "happiness",
						"amount": 20
					},
					{
						"type": "stat_change",
						"target": "candidate",
						"stat": "creativity",
						"amount": -10
					}
				]
			}
		},
		{
			"choice_id": "not_interested",
			"title": "NOT INTERESTED",
			"description": "It is better to stay just acquaintances.",
			"icon_path": BROKEN_HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		},
		{
			"choice_id": "invite_to_dinner",
			"title": "INVITE TO DINNER",
			"description": "Requires Confidence (90)",
			"icon_path": HEART_ICON,
			"requirements": {
				"all": [
					{
						"type": "stat",
						"target": "primary",
						"stat": "confidence",
						"operator": ">=",
						"value": 90
					}
				]
			},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		}
	]
	return event


func _group_event(event_id: String) -> Dictionary:
	var event := _base_event(event_id)
	event["trigger"] = {
		"type": "manual",
		"source": "lifestyle",
		"mode": "direct"
	}
	event["participants"] = {
		"travel_group": {
			"type": "character_group",
			"source": "player_selected",
			"min": 2,
			"max": 5,
			"requirements": {
				"all": [
					{
						"type": "is_alive",
						"target": "travel_group",
						"operator": "==",
						"value": true
					}
				]
			},
			"selection_ui": {
				"title": "SELECT PARTICIPANTS",
				"description": "Select family members for this event",
				"show_ineligible": true,
				"show_relevant_stats": [
					"happiness",
					"health",
					"logic",
					"confidence",
					"social",
					"attractiveness",
					"discipline",
					"creativity"
				]
			}
		}
	}
	event["presentation"]["art_path"] = EVENT_ART
	event["content"] = {
		"title": "GROUP EVENT",
		"subtitle": null,
		"description": (
			"Choose which family members will participate in this event. "
			+ "This fixture uses the real production group-selection contract."
		)
	}
	event["choices"] = [
		{
			"choice_id": "continue",
			"title": "SHOW INTEREST",
			"description": "Take a chance and build a connection.",
			"icon_path": HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		},
		{
			"choice_id": "cancel",
			"title": "NOT INTERESTED",
			"description": "It is better to stay just acquaintances.",
			"icon_path": BROKEN_HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		}
	]
	return event


func _base_event(event_id: String) -> Dictionary:
	return {
		"event_id": event_id,
		"category": "lifestyle",
		"domain": "lifestyle",
		"subtype": "manual_event_ui_fixture",
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
		"behavior": {
			"blocking": true,
			"pause_game": true
		},
		"content": {
			"title": "Event UI",
			"subtitle": null,
			"description": "Manual UI fixture"
		},
		"presentation": {
			"template": "standard_event"
		},
		"choices": []
	}


func _configure(events: Array) -> void:
	if presentation != null and presentation.participant_overlay.visible:
		presentation.close_participant_selection()
	if EventManager.active_event != null:
		EventManager.cancel_active_event()

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
	if not loaded:
		push_error(
			"Manual Event UI fixture registry failed validation:\n"
			+ registry.get_diagnostic_text()
		)
		return

	EventManager.configure_runtime(registry, null, 77)


func _setup_characters() -> void:
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	GameManager.family_money = 1000
	GameManager.diamonds = 100

	CharacterManager.characters = [
		_character(
			1,
			"Alexandria-Long-Character-Name",
			true,
			"1973-01-26",
			"female",
			80
		),
		_character(2, "William", true, "1973-01-26", "male", 80),
		_character(3, "Emma", true, "1978-03-02", "female", 72),
		_character(4, "George", true, "1986-01-26", "male", 64),
		_character(5, "Joshua", true, "1965-01-26", "male", 76),
		_character(6, "Eric", true, "1988-01-26", "male", 68),
		_character(7, "Alexandria", false, "1973-01-26", "female", 76)
	]


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
		"linked_character_id": 2 if not family else null,
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
	if original_state.is_empty():
		return
	if original_registry != null:
		EventManager.configure_runtime(original_registry)
	CharacterManager.characters = original_state.get("characters", [])
	GameManager.family_money = int(original_state.get("money", 0))
	GameManager.diamonds = int(original_state.get("diamonds", 0))
	TimeManager.current_year = int(original_state.get("year", 1985))
	TimeManager.current_month = int(original_state.get("month", 1))
	TimeManager.current_day = int(original_state.get("day", 26))
	TimeManager.is_paused = bool(original_state.get("paused", false))
	TimeManager.speed_multiplier = float(original_state.get("speed", 1.0))


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
