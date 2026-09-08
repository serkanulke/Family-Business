extends CanvasLayer
class_name EventPresentation


signal manual_event_selection_cancelled(event_id: String)


const MODAL_WIDTH := 1000.0
const MODAL_SIDE_MARGIN := 40.0
const SHEET_TOP := 500.0
const DIM_OPACITY := 0.82

const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const FONT_EXTRA_BOLD := "res://Resources/Fonts/Roboto-ExtraBold.ttf"
const ARROW_ICON := "res://Resources/Icons/arrow-right.svg"
const LOCK_ICON := "res://Resources/Icons/event-modal/lock.svg"
const TITLE_SEPARATOR := "res://Resources/Icons/event-modal/event-modal-separator.svg"
const STAT_ICON_FOLDER := "res://Resources/Icons/stats/"

const COLOR_MODAL := Color("#FFF2DE")
const COLOR_CARD := Color("#FFF9F4")
const COLOR_BORDER := Color("#E7CEB5")
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")
const COLOR_PRIMARY := Color("#67AC84")
const COLOR_POSITIVE := Color("#009653")
const COLOR_NEGATIVE := Color("#E43D3D")
const COLOR_DISABLED := Color("#E7D3BC")
const COLOR_DISABLED_TEXT := Color("#D8C4AC")
const COLOR_HANDLE := Color("#DCC4AB")

const CHARACTER_TYPES: Array[String] = ["character", "relationship_npc"]

var modal_root: Control
var dim_background: ColorRect
var event_panel: PanelContainer
var event_scroll: ScrollContainer
var event_content: VBoxContainer
var result_panel: PanelContainer
var result_scroll: ScrollContainer
var result_content: VBoxContainer
var participant_overlay: Control
var participant_dim: ColorRect
var participant_sheet: PanelContainer
var participant_scroll: ScrollContainer
var participant_content: VBoxContainer

var current_instance: Dictionary = {}
var current_definition: Dictionary = {}
var current_layout := ""
var current_group_name := ""
var current_candidate_group: Dictionary = {}
var current_availability: Dictionary = {}
var pending_event_id := ""
var pending_runtime_context: Dictionary = {}
var sheet_selected_ids: Array = []
var result_is_visible := false
var character_card: Node
var character_card_open := false
var resolved_event_content: Dictionary = {}
var resolving_choice := false

var event_art: TextureRect
var group_button: Button
var choice_buttons: Array[Button] = []
var participant_chips: Array[Button] = []
var participant_cards: Array[Control] = []
var result_character_rows: Array[Control] = []


func _ready() -> void:
	_build_interface()
	_connect_runtime_signals()
	set_process_unhandled_input(true)
	if EventManager.active_event != null:
		_on_active_event_changed(EventManager.active_event.to_dictionary())
	else:
		modal_root.visible = false


func set_character_card(card: Node) -> void:
	character_card = card
	if (
		character_card != null
		and character_card.has_signal("card_closed")
		and not character_card.is_connected("card_closed", _on_character_card_closed)
	):
		character_card.connect("card_closed", _on_character_card_closed)


func begin_manual_event(
	event_id: String,
	runtime_context: Dictionary = {}
) -> bool:
	if EventManager.active_event != null or EventManager.runtime_service == null:
		return false
	var availability := EventManager.runtime_service.get_availability(
		event_id,
		runtime_context
	)
	var status := String(availability.get("status", ""))
	if status == EventRuntimeService.AVAILABLE:
		return bool(
			EventManager.activate_manual_direct(
				event_id,
				runtime_context
			).get("queued", false)
		)
	if (
		status != EventRuntimeService.REQUIRES_PARTICIPANTS
		or (availability.get("candidate_groups", {}) as Dictionary).is_empty()
	):
		return false
	pending_event_id = event_id
	pending_runtime_context = runtime_context.duplicate(true)
	current_availability = availability.duplicate(true)
	current_definition = availability.get("definition", {}).duplicate(true)
	current_instance = {
		"event_id": event_id,
		"participants": availability.get("participants", {}).duplicate(true),
		"context": availability.get("context", {}).duplicate(true)
	}
	_render_event()
	return true


func open_participant_selection() -> bool:
	if current_group_name.is_empty():
		return false
	_prepare_candidate_group()
	if current_candidate_group.is_empty():
		return false
	var participants := current_instance.get("participants", {}) as Dictionary
	var selected_value = participants.get(current_group_name, [])
	sheet_selected_ids = (
		selected_value.duplicate()
		if typeof(selected_value) == TYPE_ARRAY
		else []
	)
	_rebuild_participant_sheet()
	participant_overlay.visible = true
	_layout_sheet()
	return true


func close_participant_selection() -> void:
	participant_overlay.visible = false


func get_display_snapshot() -> Dictionary:
	var choices: Array = []
	for button in choice_buttons:
		choices.append({
			"choice_id": String(button.get_meta("choice_id", "")),
			"disabled": button.disabled,
			"icon_path": String(button.get_meta("icon_path", ""))
		})
	return {
		"visible": modal_root != null and modal_root.visible,
		"event_id": String(current_instance.get("event_id", "")),
		"layout": current_layout,
		"title": String(resolved_event_content.get("title", "")),
		"description": String(resolved_event_content.get("description", "")),
		"art_path": (
			String(event_art.get_meta("art_path", ""))
			if event_art != null
			else ""
		),
		"choice_states": choices,
		"participant_chip_count": participant_chips.size(),
		"group_count": _selected_group_count(),
		"participant_sheet_visible": (
			participant_overlay != null and participant_overlay.visible
		),
		"participant_card_count": participant_cards.size(),
		"sheet_selected_count": sheet_selected_ids.size(),
		"result_visible": result_is_visible,
		"result_character_count": result_character_rows.size()
	}


func _unhandled_input(event: InputEvent) -> void:
	if participant_overlay.visible and event.is_action_pressed("ui_cancel"):
		close_participant_selection()
		get_viewport().set_input_as_handled()
	elif modal_root.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	modal_root = Control.new()
	modal_root.name = "ModalRoot"
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_root)

	dim_background = ColorRect.new()
	dim_background.name = "DimBackground"
	dim_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_background.color = Color(0.02, 0.04, 0.04, DIM_OPACITY)
	dim_background.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_background.gui_input.connect(_consume_background_input)
	modal_root.add_child(dim_background)

	event_panel = _make_panel("EventPanel", COLOR_MODAL, 46, Color.TRANSPARENT, 0)
	event_panel.clip_contents = true
	event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(event_panel)
	event_scroll = _make_scroll("EventScroll")
	event_panel.add_child(event_scroll)
	var event_margin := _make_margin(48, 40, 48, 44)
	event_margin.custom_minimum_size = Vector2(MODAL_WIDTH, 0.0)
	event_scroll.add_child(event_margin)
	event_content = VBoxContainer.new()
	event_content.name = "EventContent"
	event_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_content.add_theme_constant_override("separation", 14)
	event_margin.add_child(event_content)

	result_panel = _make_panel("ResultPanel", COLOR_MODAL, 46, Color.TRANSPARENT, 0)
	result_panel.clip_contents = true
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.visible = false
	modal_root.add_child(result_panel)
	result_scroll = _make_scroll("ResultScroll")
	result_panel.add_child(result_scroll)
	var result_margin := _make_margin(48, 42, 48, 44)
	result_margin.custom_minimum_size = Vector2(MODAL_WIDTH, 0.0)
	result_scroll.add_child(result_margin)
	result_content = VBoxContainer.new()
	result_content.name = "ResultContent"
	result_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_content.add_theme_constant_override("separation", 24)
	result_margin.add_child(result_content)

	_build_participant_overlay()
	modal_root.resized.connect(_layout_all)


func _build_participant_overlay() -> void:
	participant_overlay = Control.new()
	participant_overlay.name = "ParticipantOverlay"
	participant_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	participant_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	participant_overlay.visible = false
	modal_root.add_child(participant_overlay)

	participant_dim = ColorRect.new()
	participant_dim.name = "ParticipantDim"
	participant_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	participant_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	participant_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	participant_dim.gui_input.connect(_on_participant_dim_input)
	participant_overlay.add_child(participant_dim)

	participant_sheet = _make_panel(
		"ParticipantSheet", COLOR_MODAL, 44, Color.TRANSPARENT, 0
	)
	participant_sheet.clip_contents = true
	participant_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	participant_overlay.add_child(participant_sheet)
	participant_scroll = _make_scroll("ParticipantScroll")
	participant_sheet.add_child(participant_scroll)
	var sheet_margin := _make_margin(40, 16, 40, 60)
	sheet_margin.custom_minimum_size = Vector2(MODAL_WIDTH, 0.0)
	participant_scroll.add_child(sheet_margin)
	participant_content = VBoxContainer.new()
	participant_content.name = "ParticipantContent"
	participant_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	participant_content.add_theme_constant_override("separation", 24)
	sheet_margin.add_child(participant_content)


func _connect_runtime_signals() -> void:
	if not EventManager.active_event_changed.is_connected(_on_active_event_changed):
		EventManager.active_event_changed.connect(_on_active_event_changed)
	if not EventManager.queue_changed.is_connected(_on_queue_changed):
		EventManager.queue_changed.connect(_on_queue_changed)
	if not GameManager.family_money_changed.is_connected(_on_runtime_value_changed):
		GameManager.family_money_changed.connect(_on_runtime_value_changed)
	if not GameManager.diamonds_changed.is_connected(_on_runtime_value_changed):
		GameManager.diamonds_changed.connect(_on_runtime_value_changed)


func _on_active_event_changed(instance: Dictionary) -> void:
	if result_is_visible:
		return
	pending_event_id = ""
	pending_runtime_context.clear()
	current_availability.clear()
	current_instance = instance.duplicate(true)
	current_definition = EventManager.registry.get_event(
		String(instance.get("event_id", ""))
	)
	_render_event()


func _on_queue_changed(active: Dictionary, _queued: Array) -> void:
	if result_is_visible or character_card_open or not pending_event_id.is_empty():
		return
	if active.is_empty():
		current_instance.clear()
		current_definition.clear()
		modal_root.visible = false
		return
	if String(active.get("instance_id", "")) != String(
		current_instance.get("instance_id", "")
	):
		_on_active_event_changed(active)


func _on_runtime_value_changed(_value = null) -> void:
	if (
		modal_root.visible
		and not result_is_visible
		and not character_card_open
		and not resolving_choice
		and pending_event_id.is_empty()
	):
		_render_event()


func _render_event() -> void:
	_clear_children(event_content)
	choice_buttons.clear()
	participant_chips.clear()
	event_art = null
	group_button = null
	current_group_name = _find_group_participant_name(current_definition)
	current_layout = _resolve_layout(current_definition, current_instance)
	_build_context_section()
	event_content.add_child(_make_horizontal_line())
	_build_event_body()
	event_panel.visible = true
	result_panel.visible = false
	result_is_visible = false
	modal_root.visible = true
	call_deferred("_layout_all")


func _build_context_section() -> void:
	if current_layout == "group":
		var group_box := VBoxContainer.new()
		group_box.custom_minimum_size = Vector2(0.0, 170.0)
		group_box.alignment = BoxContainer.ALIGNMENT_CENTER
		group_box.add_theme_constant_override("separation", 14)
		group_box.add_child(_make_centered_label("EVENT FOR", 23, COLOR_BROWN, FONT_REGULAR))
		var button_center := CenterContainer.new()
		group_button = _make_button("GroupParticipantButton", Vector2(360.0, 104.0))
		group_button.add_theme_stylebox_override(
			"normal", _make_style(COLOR_CARD, 24, COLOR_BORDER, 2)
		)
		group_button.add_theme_stylebox_override(
			"hover", _make_style(Color("#FFFDF9"), 24, COLOR_BORDER, 2)
		)
		group_button.add_theme_font_override("font", _font(FONT_EXTRA_BOLD))
		group_button.add_theme_font_size_override("font_size", 32)
		group_button.add_theme_color_override("font_color", COLOR_BROWN)
		group_button.text = _group_button_text()
		group_button.pressed.connect(open_participant_selection)
		button_center.add_child(group_button)
		group_box.add_child(button_center)
		event_content.add_child(group_box)
		return

	var character_entries := _character_entries()
	if current_layout == "relationship" and character_entries.size() >= 2:
		var pair := HBoxContainer.new()
		pair.custom_minimum_size = Vector2(0.0, 170.0)
		pair.add_theme_constant_override("separation", 28)
		pair.add_child(_make_labeled_character_chip("EVENT FOR", character_entries[0]))
		pair.add_child(_make_labeled_character_chip("WITH", character_entries[1]))
		event_content.add_child(pair)
		return

	var single := VBoxContainer.new()
	single.custom_minimum_size = Vector2(0.0, 170.0)
	single.alignment = BoxContainer.ALIGNMENT_CENTER
	single.add_theme_constant_override("separation", 14)
	single.add_child(_make_centered_label("EVENT FOR", 23, COLOR_BROWN, FONT_REGULAR))
	var center := CenterContainer.new()
	if not character_entries.is_empty():
		center.add_child(_make_character_chip(character_entries[0], Vector2(440.0, 108.0)))
	single.add_child(center)
	event_content.add_child(single)


func _build_event_body() -> void:
	var presentation := current_definition.get("presentation", {}) as Dictionary
	var art_path := String(presentation.get("art_path", ""))
	var art_frame := _make_panel(
		"EventArtFrame", Color("#F8E9D8"), 28, Color.TRANSPARENT, 0
	)
	art_frame.custom_minimum_size = Vector2(0.0, 290.0)
	art_frame.clip_contents = true
	event_art = TextureRect.new()
	event_art.name = "EventArt"
	event_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	event_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_art.texture = _load_texture(art_path)
	event_art.set_meta("art_path", art_path if event_art.texture != null else "")
	art_frame.add_child(event_art)
	event_content.add_child(art_frame)

	resolved_event_content = EventPresentationResolver.resolve_content(
		current_definition.get("content", {}),
		current_instance.get("participants", {}),
		current_instance.get("context", {})
	)
	var title := _make_centered_label(
		String(resolved_event_content.get("title", "")),
		46,
		COLOR_TEXT,
		FONT_EXTRA_BOLD
	)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0.0, 62.0)
	event_content.add_child(title)

	var separator_center := CenterContainer.new()
	separator_center.custom_minimum_size = Vector2(0.0, 24.0)
	var separator := _make_texture(TITLE_SEPARATOR, Vector2(660.0, 24.0))
	separator_center.add_child(separator)
	event_content.add_child(separator_center)

	var description := _make_centered_label(
		String(resolved_event_content.get("description", "")),
		29,
		COLOR_BROWN,
		FONT_REGULAR
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0.0, 100.0)
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_content.add_child(description)

	var choices_value = current_definition.get("choices", [])
	if typeof(choices_value) != TYPE_ARRAY:
		return
	var choice_states: Dictionary = {}
	if pending_event_id.is_empty():
		for state_value in EventManager.get_active_choice_states():
			if typeof(state_value) == TYPE_DICTIONARY:
				choice_states[String(state_value.get("choice_id", ""))] = state_value
	for index in choices_value.size():
		var choice_value = choices_value[index]
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var choice_id := String(choice.get("choice_id", ""))
		var state: Dictionary = choice_states.get(choice_id, {})
		if not pending_event_id.is_empty():
			state = {
				"available": false,
				"failure_reasons": [
					{"message": "Select participants to continue."}
				]
			}
		var button := _make_choice_button(choice, state, index)
		choice_buttons.append(button)
		event_content.add_child(button)


func _make_choice_button(
	choice: Dictionary,
	state: Dictionary,
	index: int
) -> Button:
	var enabled := bool(state.get("available", false))
	var is_primary := enabled and index == 0
	var background := COLOR_PRIMARY if is_primary else COLOR_CARD
	var border := Color.TRANSPARENT if is_primary else COLOR_BORDER
	var text_color := Color.WHITE if is_primary else COLOR_BROWN
	if not enabled:
		background = Color("#FFF8ED")
		border = COLOR_DISABLED
		text_color = COLOR_DISABLED_TEXT

	var button := _make_button(
		"Choice_%s" % String(choice.get("choice_id", "")),
		Vector2(0.0, 128.0)
	)
	button.disabled = not enabled
	button.set_meta("choice_id", String(choice.get("choice_id", "")))
	button.add_theme_stylebox_override(
		"normal", _make_style(background, 16, border, 2 if not is_primary else 0)
	)
	button.add_theme_stylebox_override(
		"hover", _make_style(background.lightened(0.03), 16, border, 2 if not is_primary else 0)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_style(background.darkened(0.04), 16, border, 2 if not is_primary else 0)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_style(background, 16, border, 2)
	)
	button.pressed.connect(_on_choice_pressed.bind(String(choice.get("choice_id", ""))))

	var margin := _make_margin(28, 16, 24, 16)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var icon_path := LOCK_ICON if not enabled else String(choice.get("icon_path", ""))
	button.set_meta("icon_path", icon_path if ResourceLoader.exists(icon_path) else "")
	if ResourceLoader.exists(icon_path):
		var icon := _make_texture(icon_path, Vector2(58.0, 58.0))
		icon.material = _tint_material(text_color)
		row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var title := _make_label(
		String(choice.get("title", "")), 31, text_color, FONT_EXTRA_BOLD
	)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var description_text := String(choice.get("description", ""))
	if not enabled:
		description_text = _first_failure_message(
			state.get("failure_reasons", []), description_text
		)
	description_text = _append_cost_text(description_text, choice.get("cost", null))
	var description := _make_label(
		description_text, 25, text_color, FONT_REGULAR
	)
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(description)

	var arrow := _make_texture(ARROW_ICON, Vector2(30.0, 42.0))
	arrow.material = _tint_material(text_color)
	row.add_child(arrow)
	return button


func _on_choice_pressed(choice_id: String) -> void:
	if not pending_event_id.is_empty():
		return
	var availability := EventManager.get_active_choice_availability(choice_id)
	if not bool(availability.get("available", false)):
		_render_event()
		return
	resolving_choice = true
	var result := EventManager.resolve_active_event(choice_id)
	resolving_choice = false
	if not bool(result.get("resolved", false)):
		if EventManager.active_event != null:
			current_instance = EventManager.active_event.to_dictionary()
			current_definition = EventManager.registry.get_event(
				EventManager.active_event.event_id
			)
			_render_event()
		return
	var character_results := _collect_character_stat_results(
		result.get("effect_results", [])
	)
	if character_results.is_empty():
		_show_next_active_or_close()
		return
	_show_result(character_results)


func _show_result(character_results: Array) -> void:
	_clear_children(result_content)
	result_character_rows.clear()
	result_content.add_child(
		_make_centered_label("EVENT RESULT", 46, COLOR_TEXT, FONT_EXTRA_BOLD)
	)
	var separator_center := CenterContainer.new()
	separator_center.add_child(_make_texture(TITLE_SEPARATOR, Vector2(660.0, 24.0)))
	result_content.add_child(separator_center)
	result_content.add_child(
		_make_centered_label("AFFECTED CHARACTERS", 28, COLOR_BROWN, FONT_REGULAR)
	)
	for record_value in character_results:
		var row := _make_result_character_row(record_value)
		result_character_rows.append(row)
		result_content.add_child(row)
	var continue_button := _make_button("ContinueButton", Vector2(0.0, 96.0))
	continue_button.text = "CONTINUE"
	continue_button.add_theme_font_override("font", _font(FONT_BOLD))
	continue_button.add_theme_font_size_override("font_size", 30)
	continue_button.add_theme_color_override("font_color", Color.WHITE)
	continue_button.add_theme_stylebox_override(
		"normal", _make_style(COLOR_PRIMARY, 20, Color.TRANSPARENT, 0)
	)
	continue_button.add_theme_stylebox_override(
		"hover", _make_style(COLOR_PRIMARY.lightened(0.03), 20, Color.TRANSPARENT, 0)
	)
	continue_button.add_theme_stylebox_override(
		"pressed", _make_style(COLOR_PRIMARY.darkened(0.04), 20, Color.TRANSPARENT, 0)
	)
	continue_button.pressed.connect(_on_result_continue)
	result_content.add_child(continue_button)
	result_is_visible = true
	event_panel.visible = false
	result_panel.visible = true
	modal_root.visible = true
	call_deferred("_layout_all")


func _make_result_character_row(record: Dictionary) -> PanelContainer:
	var panel := _make_panel("ResultCharacter", COLOR_CARD, 26, COLOR_BORDER, 2)
	panel.custom_minimum_size = Vector2(0.0, 210.0)
	var margin := _make_margin(24, 22, 24, 22)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	var character := CharacterManager.get_character_by_id(
		int(record.get("character_id", 0))
	)
	row.add_child(_make_portrait(character, Vector2(150.0, 150.0)))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 16)
	row.add_child(copy)
	var character_name := _make_label(
		_character_name_age(character), 34, COLOR_TEXT, FONT_BOLD
	)
	character_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(character_name)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 16)
	chips.add_theme_constant_override("v_separation", 12)
	copy.add_child(chips)
	for stat_value in record.get("stats", []):
		chips.add_child(_make_stat_delta_chip(stat_value))
	return panel


func _make_stat_delta_chip(stat_result: Dictionary) -> PanelContainer:
	var chip := _make_panel("StatDelta", COLOR_CARD, 12, COLOR_BORDER, 2)
	chip.custom_minimum_size = Vector2(132.0, 68.0)
	var margin := _make_margin(16, 10, 16, 10)
	chip.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var stat := String(stat_result.get("stat", ""))
	row.add_child(_make_texture(STAT_ICON_FOLDER + stat + ".svg", Vector2(34.0, 34.0)))
	var amount := int(stat_result.get("amount", 0))
	row.add_child(_make_label(
		"%+d" % amount,
		31,
		COLOR_POSITIVE if amount > 0 else COLOR_NEGATIVE,
		FONT_EXTRA_BOLD
	))
	return chip


func _collect_character_stat_results(effect_results_value) -> Array:
	if typeof(effect_results_value) != TYPE_ARRAY:
		return []
	var order: Array[int] = []
	var by_character: Dictionary = {}
	for result_value in effect_results_value:
		if typeof(result_value) != TYPE_DICTIONARY:
			continue
		var result: Dictionary = result_value
		if (
			not bool(result.get("success", false))
			or String(result.get("effect_type", "")) not in ["stat_change", "stat_set"]
		):
			continue
		var character_id := int(result.get("target_character_id", 0))
		var stat := String(result.get("stat", ""))
		var amount := int(result.get("applied_amount", 0))
		if character_id <= 0 or stat.is_empty() or amount == 0:
			continue
		if not by_character.has(character_id):
			order.append(character_id)
			by_character[character_id] = {}
		var stats: Dictionary = by_character[character_id]
		stats[stat] = int(stats.get(stat, 0)) + amount
		by_character[character_id] = stats
	var rows: Array = []
	for character_id in order:
		var stat_rows: Array = []
		var stats: Dictionary = by_character[character_id]
		for stat in stats:
			var amount := int(stats[stat])
			if amount != 0:
				stat_rows.append({"stat": String(stat), "amount": amount})
		if not stat_rows.is_empty():
			rows.append({"character_id": character_id, "stats": stat_rows})
	return rows


func _on_result_continue() -> void:
	result_is_visible = false
	result_panel.visible = false
	_show_next_active_or_close()


func _show_next_active_or_close() -> void:
	if EventManager.active_event != null:
		_on_active_event_changed(EventManager.active_event.to_dictionary())
	else:
		current_instance.clear()
		current_definition.clear()
		modal_root.visible = false


func _prepare_candidate_group() -> void:
	current_candidate_group.clear()
	if current_group_name.is_empty():
		return
	if not pending_event_id.is_empty():
		var groups := current_availability.get("candidate_groups", {}) as Dictionary
		current_candidate_group = groups.get(current_group_name, {}).duplicate(true)
		return
	if EventManager.runtime_service == null:
		return
	var definitions := current_definition.get("participants", {}) as Dictionary
	var definition := definitions.get(current_group_name, {}) as Dictionary
	current_candidate_group = (
		EventManager.runtime_service.participant_resolver.prepare_character_group(
			current_group_name,
			definition,
			current_instance.get("participants", {}),
			current_instance.get("context", {})
		)
	)


func _rebuild_participant_sheet() -> void:
	_clear_children(participant_content)
	participant_cards.clear()
	var handle_center := CenterContainer.new()
	handle_center.custom_minimum_size = Vector2(0.0, 24.0)
	var handle := _make_panel("Handle", COLOR_HANDLE, 5, Color.TRANSPARENT, 0)
	handle.custom_minimum_size = Vector2(200.0, 9.0)
	handle_center.add_child(handle)
	participant_content.add_child(handle_center)

	var selection_ui := current_candidate_group.get("selection_ui", {}) as Dictionary
	participant_content.add_child(_make_centered_label(
		String(selection_ui.get("title", "SELECT PARTICIPANTS")),
		40,
		COLOR_BROWN,
		FONT_EXTRA_BOLD
	))
	var subtitle := _make_centered_label(
		String(selection_ui.get("description", "")),
		25,
		COLOR_BROWN,
		FONT_REGULAR
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	participant_content.add_child(subtitle)

	var grid := GridContainer.new()
	grid.name = "ParticipantGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	participant_content.add_child(grid)
	var show_ineligible := bool(selection_ui.get("show_ineligible", false))
	for candidate_value in current_candidate_group.get("candidates", []):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		if not bool(candidate.get("eligible", false)) and not show_ineligible:
			continue
		var card := _make_participant_card(candidate, selection_ui)
		participant_cards.append(card)
		grid.add_child(card)

	var confirm := _make_button("ConfirmParticipants", Vector2(0.0, 96.0))
	confirm.text = "CONFIRM"
	confirm.disabled = not _selection_count_is_valid()
	confirm.add_theme_font_override("font", _font(FONT_BOLD))
	confirm.add_theme_font_size_override("font_size", 30)
	confirm.add_theme_color_override("font_color", Color.WHITE)
	confirm.add_theme_color_override("font_disabled_color", COLOR_DISABLED_TEXT)
	confirm.add_theme_stylebox_override(
		"normal", _make_style(COLOR_PRIMARY, 20, Color.TRANSPARENT, 0)
	)
	confirm.add_theme_stylebox_override(
		"hover", _make_style(COLOR_PRIMARY.lightened(0.03), 20, Color.TRANSPARENT, 0)
	)
	confirm.add_theme_stylebox_override(
		"pressed", _make_style(COLOR_PRIMARY.darkened(0.04), 20, Color.TRANSPARENT, 0)
	)
	confirm.add_theme_stylebox_override(
		"disabled", _make_style(Color("#E9DBC9"), 20, Color.TRANSPARENT, 0)
	)
	confirm.pressed.connect(_confirm_participant_selection)
	participant_content.add_child(confirm)


func _make_participant_card(
	candidate: Dictionary,
	selection_ui: Dictionary
) -> PanelContainer:
	var character_id := int(candidate.get("character_id", 0))
	var character := CharacterManager.get_character_by_id(character_id)
	var selected := sheet_selected_ids.has(character_id)
	var eligible := bool(candidate.get("eligible", false))
	var panel := _make_panel("Participant_%d" % character_id, COLOR_CARD, 24, COLOR_BORDER, 2)
	panel.custom_minimum_size = Vector2(448.0, 610.0)
	var margin := _make_margin(22, 24, 22, 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var portrait_center := CenterContainer.new()
	portrait_center.add_child(_make_portrait(character, Vector2(126.0, 126.0)))
	content.add_child(portrait_center)
	var character_name := _make_centered_label(
		String(character.get("first_name", "")), 36, COLOR_TEXT, FONT_EXTRA_BOLD
	)
	character_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(character_name)
	content.add_child(_make_centered_label(
		"%d · %s" % [
			CharacterManager.get_character_age(character),
			_humanize(String(character.get("life_stage", "")))
		],
		25,
		COLOR_TEXT,
		FONT_REGULAR
	))
	var stats: Array = selection_ui.get("show_relevant_stats", [])
	if typeof(stats) == TYPE_ARRAY and not stats.is_empty():
		content.add_child(_make_participant_stats(character, stats))
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0.0, 228.0)
		content.add_child(spacer)

	var button := _make_button("SelectionButton", Vector2(0.0, 72.0))
	var maximum := int(current_candidate_group.get("maximum", 1))
	var maximum_reached := sheet_selected_ids.size() >= maximum
	button.disabled = not eligible or (not selected and maximum_reached)
	button.text = "Remove" if selected else ("Select" if eligible else "Unavailable")
	button.tooltip_text = _first_failure_message(
		candidate.get("failure_reasons", []), ""
	)
	button.add_theme_font_override("font", _font(FONT_BOLD))
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color.WHITE if not selected else COLOR_BROWN)
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED_TEXT)
	var button_bg := COLOR_CARD if selected else COLOR_PRIMARY
	var button_border := COLOR_BORDER if selected else Color.TRANSPARENT
	button.add_theme_stylebox_override(
		"normal", _make_style(button_bg, 18, button_border, 2 if selected else 0)
	)
	button.add_theme_stylebox_override(
		"hover", _make_style(button_bg.lightened(0.03), 18, button_border, 2 if selected else 0)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_style(button_bg.darkened(0.04), 18, button_border, 2 if selected else 0)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_style(Color("#F3E6D7"), 18, COLOR_DISABLED, 2)
	)
	button.pressed.connect(_toggle_participant.bind(character_id))
	content.add_child(button)
	return panel


func _make_participant_stats(character: Dictionary, stats: Array) -> PanelContainer:
	var panel := _make_panel("RelevantStats", COLOR_CARD, 18, COLOR_BORDER, 1)
	panel.custom_minimum_size = Vector2(0.0, 228.0)
	var margin := _make_margin(26, 18, 26, 18)
	panel.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)
	for stat_value in stats:
		var stat := String(stat_value)
		grid.add_child(_make_texture(STAT_ICON_FOLDER + stat + ".svg", Vector2(32.0, 32.0)))
		var value := _make_label(str(int(character.get(stat, 0))), 24, COLOR_TEXT, FONT_REGULAR)
		value.custom_minimum_size = Vector2(58.0, 32.0)
		grid.add_child(value)
	return panel


func _toggle_participant(character_id: int) -> void:
	if sheet_selected_ids.has(character_id):
		sheet_selected_ids.erase(character_id)
	else:
		var maximum := int(current_candidate_group.get("maximum", 1))
		if sheet_selected_ids.size() >= maximum:
			return
		sheet_selected_ids.append(character_id)
	_rebuild_participant_sheet()


func _confirm_participant_selection() -> void:
	if not _selection_count_is_valid():
		return
	if not pending_event_id.is_empty():
		var runtime_context := pending_runtime_context.duplicate(true)
		var selections_value = runtime_context.get("selected_participants", {})
		var selections: Dictionary = (
			selections_value.duplicate(true)
			if typeof(selections_value) == TYPE_DICTIONARY
			else {}
		)
		selections[current_group_name] = sheet_selected_ids.duplicate()
		runtime_context["selected_participants"] = selections
		var activation := EventManager.activate_manual_direct(
			pending_event_id,
			runtime_context
		)
		if not bool(activation.get("queued", false)):
			return
		participant_overlay.visible = false
		return
	var updated := EventManager.set_active_character_group_selection(
		current_group_name,
		sheet_selected_ids
	)
	if bool(updated.get("updated", false)):
		participant_overlay.visible = false


func _selection_count_is_valid() -> bool:
	var minimum := int(current_candidate_group.get("minimum", 1))
	var maximum := int(current_candidate_group.get("maximum", 1))
	return sheet_selected_ids.size() >= minimum and sheet_selected_ids.size() <= maximum


func _make_labeled_character_chip(label_text: String, entry: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	column.add_child(_make_centered_label(label_text, 23, COLOR_BROWN, FONT_REGULAR))
	column.add_child(_make_character_chip(entry, Vector2(0.0, 108.0)))
	return column


func _make_character_chip(entry: Dictionary, minimum_size: Vector2) -> Button:
	var character := entry.get("character", {}) as Dictionary
	var character_id := int(character.get("character_id", 0))
	var button := _make_button("CharacterChip_%d" % character_id, minimum_size)
	button.set_meta("character_id", character_id)
	button.add_theme_stylebox_override(
		"normal", _make_style(COLOR_CARD, 24, COLOR_BORDER, 2)
	)
	button.add_theme_stylebox_override(
		"hover", _make_style(Color("#FFFDF9"), 24, COLOR_BORDER, 2)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_style(Color("#F7E9DA"), 24, COLOR_BORDER, 2)
	)
	button.pressed.connect(_open_character_card.bind(character_id))
	var margin := _make_margin(14, 12, 18, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	row.add_child(_make_portrait(character, Vector2(80.0, 80.0)))
	var label := _make_label(_character_name_age(character), 31, COLOR_BROWN, FONT_BOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	participant_chips.append(button)
	return button


func _make_portrait(character: Dictionary, minimum_size: Vector2) -> PanelContainer:
	var radius := int(minimum_size.x * 0.5)
	var frame := _make_panel("Portrait", Color("#D9EEFA"), radius, Color.WHITE, 4)
	frame.custom_minimum_size = minimum_size
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := TextureRect.new()
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.texture = CharacterManager.get_avatar_texture(character)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(texture)
	return frame


func _open_character_card(character_id: int) -> void:
	if character_card == null:
		var current_scene := get_tree().current_scene
		if current_scene != null:
			character_card = current_scene.get_node_or_null(
				"World/FamilyTreeScreen/CharacterCard"
			)
			set_character_card(character_card)
	if (
		character_card == null
		or not character_card.has_method("open_for_character")
	):
		return
	modal_root.visible = false
	character_card_open = bool(
		character_card.call("open_for_character", character_id)
	)
	if not character_card_open:
		modal_root.visible = true


func _on_character_card_closed() -> void:
	character_card_open = false
	if EventManager.active_event != null and not result_is_visible:
		current_instance = EventManager.active_event.to_dictionary()
		current_definition = EventManager.registry.get_event(
			EventManager.active_event.event_id
		)
		_render_event()
	elif result_is_visible or not pending_event_id.is_empty():
		modal_root.visible = true


func _character_entries() -> Array:
	var result: Array = []
	var definitions_value = current_definition.get("participants", {})
	if typeof(definitions_value) != TYPE_DICTIONARY:
		return result
	var definitions: Dictionary = definitions_value
	var names: Array = definitions.keys()
	if names.has("primary"):
		names.erase("primary")
		names.push_front("primary")
	var participants := current_instance.get("participants", {}) as Dictionary
	for name_value in names:
		var name := String(name_value)
		var definition_value = definitions[name]
		if (
			typeof(definition_value) != TYPE_DICTIONARY
			or String(definition_value.get("type", "")) not in CHARACTER_TYPES
		):
			continue
		var character_id := int(participants.get(name, 0))
		var character := CharacterManager.get_character_by_id(character_id)
		if character.is_empty():
			continue
		result.append({"participant": name, "character": character})
	return result


func _resolve_layout(definition: Dictionary, instance: Dictionary) -> String:
	if not _find_group_participant_name(definition).is_empty():
		return "group"
	var participants := instance.get("participants", {}) as Dictionary
	var character_count := 0
	var definitions := definition.get("participants", {}) as Dictionary
	for name in definitions:
		var participant_definition = definitions[name]
		if (
			typeof(participant_definition) == TYPE_DICTIONARY
			and String(participant_definition.get("type", "")) in CHARACTER_TYPES
			and int(participants.get(name, 0)) > 0
		):
			character_count += 1
	return "relationship" if character_count >= 2 else "single"


func _find_group_participant_name(definition: Dictionary) -> String:
	var definitions_value = definition.get("participants", {})
	if typeof(definitions_value) != TYPE_DICTIONARY:
		return ""
	for name_value in definitions_value:
		var participant_definition = definitions_value[name_value]
		if (
			typeof(participant_definition) == TYPE_DICTIONARY
			and String(participant_definition.get("type", "")) == "character_group"
		):
			return String(name_value)
	return ""


func _selected_group_count() -> int:
	if current_group_name.is_empty():
		return 0
	var participants := current_instance.get("participants", {}) as Dictionary
	var selected = participants.get(current_group_name, [])
	return selected.size() if typeof(selected) == TYPE_ARRAY else 0


func _group_button_text() -> String:
	var count := _selected_group_count()
	if count <= 0:
		return "SELECT PARTICIPANTS"
	return "%d PARTICIPANT%s" % [count, "" if count == 1 else "S"]


func _character_name_age(character: Dictionary) -> String:
	return "%s · %d" % [
		String(character.get("first_name", "")),
		CharacterManager.get_character_age(character)
	]


func _append_cost_text(description: String, cost_value) -> String:
	if typeof(cost_value) != TYPE_DICTIONARY:
		return description
	var amount := int(cost_value.get("amount", 0))
	if amount <= 0:
		return description
	var currency := String(cost_value.get("currency", "")).capitalize()
	var cost_text := "%s: %s" % [currency, _format_number(amount)]
	return cost_text if description.is_empty() else "%s · %s" % [description, cost_text]


func _first_failure_message(reasons_value, fallback: String) -> String:
	if typeof(reasons_value) != TYPE_ARRAY:
		return fallback
	for reason_value in reasons_value:
		if typeof(reason_value) != TYPE_DICTIONARY:
			continue
		var message := String(reason_value.get("message", "")).strip_edges()
		if not message.is_empty():
			return message
	return fallback


func _format_number(value: int) -> String:
	var text := str(absi(value))
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + result


func _humanize(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _consume_background_input(_event: InputEvent) -> void:
	pass


func _on_participant_dim_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		close_participant_selection()
		if not pending_event_id.is_empty():
			manual_event_selection_cancelled.emit(pending_event_id)


func _layout_all() -> void:
	_layout_event_panel()
	_layout_result_panel()
	_layout_sheet()


func _layout_event_panel() -> void:
	if event_panel == null or not event_panel.visible:
		return
	var viewport_size := modal_root.size
	var width := minf(MODAL_WIDTH, viewport_size.x - MODAL_SIDE_MARGIN * 2.0)
	var choice_count := choice_buttons.size()
	var target_height := 968.0 + maxf(0.0, float(choice_count - 1) * 142.0)
	var height := minf(target_height, viewport_size.y - 120.0)
	event_panel.position = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)
	event_panel.size = Vector2(width, height)


func _layout_result_panel() -> void:
	if result_panel == null or not result_panel.visible:
		return
	var viewport_size := modal_root.size
	var width := minf(MODAL_WIDTH, viewport_size.x - MODAL_SIDE_MARGIN * 2.0)
	var target_height := 410.0 + float(result_character_rows.size()) * 230.0
	var height := minf(maxf(760.0, target_height), viewport_size.y - 180.0)
	result_panel.position = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)
	result_panel.size = Vector2(width, height)


func _layout_sheet() -> void:
	if participant_sheet == null or not participant_overlay.visible:
		return
	var viewport_size := modal_root.size
	var left := MODAL_SIDE_MARGIN
	var top := minf(SHEET_TOP, viewport_size.y * 0.34)
	participant_sheet.position = Vector2(left, top)
	participant_sheet.size = Vector2(
		viewport_size.x - left * 2.0,
		viewport_size.y - top + 50.0
	)


func _make_scroll(node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	return scroll


func _make_panel(
	node_name: String,
	background: Color,
	radius: int,
	border: Color,
	border_width: int
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override(
		"panel", _make_style(background, radius, border, border_width)
	)
	return panel


func _make_style(
	background: Color,
	radius: int,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.anti_aliasing = true
	return style


func _make_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_button(node_name: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = minimum_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	return button


func _make_label(
	text_value: String,
	font_size: int,
	color: Color,
	font_path: String
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", _font(font_path))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_centered_label(
	text_value: String,
	font_size: int,
	color: Color,
	font_path: String
) -> Label:
	var label := _make_label(text_value, font_size, color, font_path)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_texture(path: String, minimum_size: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.custom_minimum_size = minimum_size
	texture.texture = _load_texture(path)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


func _make_horizontal_line() -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(0.0, 2.0)
	var style := StyleBoxLine.new()
	style.color = Color("#B99D84")
	style.thickness = 2
	separator.add_theme_stylebox_override("separator", style)
	return separator


func _tint_material(color: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform vec4 tint_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 source = texture(TEXTURE, UV);\n\tCOLOR = vec4(tint_color.rgb, source.a * tint_color.a);\n}\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint_color", color)
	return material


func _font(path: String) -> Font:
	return load(path) as Font


func _load_texture(path: String) -> Texture2D:
	return (
		load(path) as Texture2D
		if not path.is_empty() and ResourceLoader.exists(path)
		else null
	)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
