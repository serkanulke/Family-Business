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
var control_panel: PanelContainer
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
	_build_controls()
	await _show_single_three()


func _exit_tree() -> void:
	_restore_state()


func _process(_delta: float) -> void:
	if presentation != null and diagnostics_label != null:
		_update_diagnostics()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_F1:
			control_panel.visible = not control_panel.visible
		KEY_1:
			_show_single_three()
		KEY_2:
			_show_relationship()
		KEY_3:
			_show_group_empty()
		KEY_4:
			_show_group_five()
		KEY_5:
			_show_select_sheet()
		KEY_6:
			_show_result_one()
		KEY_7:
			_show_result_two()
		KEY_8:
			_show_result_many()
		KEY_9:
			_show_long_name()


func _build_controls() -> void:
	control_layer = CanvasLayer.new()
	control_layer.layer = 100
	add_child(control_layer)

	control_panel = PanelContainer.new()
	control_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	control_panel.offset_bottom = 230.0
	control_layer.add_child(control_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.94)
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	control_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	control_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "EVENT UI MANUAL TEST — F1 hides/shows this panel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(title)

	diagnostics_label = Label.new()
	diagnostics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostics_label.add_theme_font_size_override("font_size", 16)
	diagnostics_label.add_theme_color_override("font_color", Color("#F4D9B9"))
	root.add_child(diagnostics_label)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	root.add_child(row1)
	_add_button(row1, "1 Single 3", _show_single_three)
	_add_button(row1, "2 Relationship", _show_relationship)
	_add_button(row1, "3 Group Empty", _show_group_empty)
	_add_button(row1, "4 Group 5", _show_group_five)
	_add_button(row1, "5 Select Sheet", _show_select_sheet)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	root.add_child(row2)
	_add_button(row2, "6 Result 1", _show_result_one)
	_add_button(row2, "7 Result 2", _show_result_two)
	_add_button(row2, "8 Result 6", _show_result_many)
	_add_button(row2, "9 Long Name", _show_long_name)


func _add_button(parent: HBoxContainer, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	parent.add_child(button)


func _show_single_three() -> void:
	current_scenario = "Single / 3 Choices"
	_prepare_event()
	var event := _single_event("manual_single_three", 3)
	if not _configure([event]):
		return
	GameManager.set_family_money(100)
	EventManager.activate_chain(event["event_id"], {"primary": 2})
	await _wait_frames(3)


func _show_long_name() -> void:
	current_scenario = "Single / Long Name"
	_prepare_event()
	var event := _single_event("manual_long_name", 3)
	if not _configure([event]):
		return
	GameManager.set_family_money(1000)
	EventManager.activate_chain(event["event_id"], {"primary": 1})
	await _wait_frames(3)


func _show_relationship() -> void:
	current_scenario = "Relationship / 3 Choices"
	_prepare_event()
	var event := _relationship_event()
	if not _configure([event]):
		return
	GameManager.set_family_money(100)
	EventManager.activate_chain(
		event["event_id"],
		{"primary": 2, "candidate": 50}
	)
	await _wait_frames(3)


func _show_group_empty() -> void:
	current_scenario = "Group / Empty"
	_prepare_event()
	var event := _group_event("manual_group_empty")
	if not _configure([event]):
		return
	main.begin_manual_event(event["event_id"])
	await _wait_frames(3)


func _show_group_five() -> void:
	current_scenario = "Group / 5 Participants"
	_prepare_event()
	var event := _group_event("manual_group_five")
	if not _configure([event]):
		return
	EventManager.activate_manual_direct(
		event["event_id"],
		{"selected_participants": {"travel_group": [2, 3, 4, 5, 6]}}
	)
	await _wait_frames(3)


func _show_select_sheet() -> void:
	current_scenario = "Select Participants Sheet"
	_prepare_event()
	var event := _group_event("manual_group_sheet")
	if not _configure([event]):
		return
	main.begin_manual_event(event["event_id"])
	await _wait_frames(2)
	presentation.open_participant_selection()
	await _wait_frames(3)


# Result screens use the REAL production result renderer directly.
# This avoids EventManager resolution state so these visual tests remain stable.
func _show_result_one() -> void:
	current_scenario = "Result / 1 Character"
	_prepare_direct_result()
	presentation.call("_show_result", [_result_row(2, 3)])
	await _wait_frames(3)


func _show_result_two() -> void:
	current_scenario = "Result / 2 Characters"
	_prepare_direct_result()
	presentation.call(
		"_show_result",
		[_result_row(2, 3), _result_row(3, 3)]
	)
	await _wait_frames(3)


func _show_result_many() -> void:
	current_scenario = "Result / 6 Characters"
	_prepare_direct_result()
	var rows: Array = []
	for character_id in [2, 3, 4, 5, 6, 7]:
		rows.append(_result_row(character_id, 5))
	presentation.call("_show_result", rows)
	await _wait_frames(3)


func _result_row(character_id: int, stat_count: int) -> Dictionary:
	var stats := [
		{"stat": "health", "amount": 4},
		{"stat": "happiness", "amount": 20},
		{"stat": "creativity", "amount": -10},
		{"stat": "confidence", "amount": 5},
		{"stat": "social", "amount": -2}
	]
	return {
		"character_id": character_id,
		"stats": stats.slice(0, stat_count)
	}


func _prepare_event() -> void:
	_cancel_active()
	_reset_presentation()


func _prepare_direct_result() -> void:
	_cancel_active()
	_reset_presentation()


func _cancel_active() -> void:
	if EventManager.active_event != null:
		EventManager.cancel_active_event()


func _reset_presentation() -> void:
	if presentation == null:
		return

	if presentation.participant_overlay != null:
		presentation.participant_overlay.visible = false

	presentation.pending_event_id = ""
	presentation.pending_runtime_context.clear()
	presentation.current_availability.clear()
	presentation.current_instance.clear()
	presentation.current_definition.clear()
	presentation.current_group_name = ""
	presentation.current_candidate_group.clear()
	presentation.sheet_selected_ids.clear()
	presentation.resolved_event_content.clear()
	presentation.resolving_choice = false
	presentation.character_card_open = false
	presentation.result_is_visible = false

	if presentation.event_panel != null:
		presentation.event_panel.visible = false
	if presentation.result_panel != null:
		presentation.result_panel.visible = false
	if presentation.modal_root != null:
		presentation.modal_root.visible = false


func _update_diagnostics() -> void:
	var mode := "NONE"
	var panel_size := Vector2.ZERO
	var scroll_text := "n/a"

	if presentation.participant_overlay.visible:
		mode = "SHEET"
		panel_size = presentation.participant_sheet.size
		scroll_text = _scroll_text(presentation.participant_scroll)
	elif presentation.result_is_visible:
		mode = "RESULT"
		panel_size = presentation.result_panel.size
		scroll_text = _scroll_text(presentation.result_scroll)
	elif presentation.modal_root.visible:
		mode = "EVENT"
		panel_size = presentation.event_panel.size
		scroll_text = (
			"NONE"
			if presentation.event_scroll == null
			else _scroll_text(presentation.event_scroll)
		)

	diagnostics_label.text = "%s | %s | %.0f×%.0f | scroll: %s" % [
		current_scenario,
		mode,
		panel_size.x,
		panel_size.y,
		scroll_text
	]


func _scroll_text(scroll: ScrollContainer) -> String:
	if scroll == null:
		return "NONE"
	var bar := scroll.get_v_scroll_bar()
	var scrollable := bar.max_value > bar.page + 1.0
	return "%s (max %.0f / page %.0f)" % [
		"YES" if scrollable else "NO",
		bar.max_value,
		bar.page
	]



func _single_event(event_id: String, choice_count: int) -> Dictionary:
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
			+ "the production spacing and modal-height behavior."
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
				"effects": []
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
			"description": "A third option used to inspect the full modal geometry.",
			"icon_path": HEART_ICON,
			"requirements": {"all": []},
			"resolution": {
				"mode": "deterministic",
				"effects": []
			}
		})

	event["choices"] = choices
	return event


func _relationship_event() -> Dictionary:
	var event := _base_event("manual_relationship")
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
				"effects": []
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
		"description": "Choose which family members will participate in this event."
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


func _configure(events: Array) -> bool:
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
		return false

	EventManager.configure_runtime(registry, null, 77)
	return true



func _setup_characters() -> void:
	TimeManager.current_year = 2000
	TimeManager.current_month = 1
	TimeManager.current_day = 26
	GameManager.family_money = 1000
	GameManager.diamonds = 100

	var characters: Array = [
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
		_character(7, "Leroy", true, "1978-01-26", "male", 66)
	]

	var extra_names := [
		"Anna", "Mary", "James", "Robert", "Linda", "David",
		"Susan", "Michael", "Sarah", "Thomas", "Laura", "Daniel",
		"Julia", "Edward", "Emily", "Henry", "Olivia", "Peter",
		"Grace", "Samuel"
	]

	var next_id := 8
	for extra_name in extra_names:
		characters.append(
			_character(
				next_id,
				String(extra_name),
				true,
				"1975-05-12",
				"female" if next_id % 2 == 0 else "male",
				60 + (next_id % 25)
			)
		)
		next_id += 1

	characters.append(
		_character(
			50,
			"Alexandria",
			false,
			"1973-01-26",
			"female",
			76
		)
	)

	CharacterManager.characters = characters


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

	_cancel_active()

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
