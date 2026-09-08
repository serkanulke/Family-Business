extends CanvasLayer

# Temporary manual-debug panel for the Relationship NPC flow.
# Add this script to a temporary CanvasLayer node in the Family Tree scene.
# Remove the node/script after manual testing.
#
# It does NOT change production rules. It only:
# - forces an otherwise-valid Meet Someone event past its random activation roll,
# - exposes the active Event's real choices and resolves them through
#   EventManager.resolve_active_event(choice_id),
# - moves the next already-scheduled relationship event for the selected Character
#   to the current date so the existing scheduler can process it,
# - calls the production divorce flow for the selected married Character,
# - prints authoritative Relationship NPC runtime state.

var _character_picker: OptionButton
var _active_event_label: Label
var _choice_container: VBoxContainer
var _log: RichTextLabel
var _force_counter := 0


func _ready() -> void:
	layer = 100
	_build_ui()
	_connect_event_signals()
	_refresh_characters()
	_refresh_active_event_controls()
	_write_log(
		"Relationship NPC debug panel ready.\n"
		+ "Use a disposable test save: forcing a scheduled event changes that save's runtime state."
	)


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "RelationshipNPCDebugPanelUI"
	panel.offset_left = 24.0
	panel.offset_top = 24.0
	panel.offset_right = 650.0
	panel.offset_bottom = 940.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "RELATIONSHIP NPC DEBUG"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)

	var warning := Label.new()
	warning.text = "Temporary test tool — use a disposable save."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(warning)

	_character_picker = OptionButton.new()
	_character_picker.custom_minimum_size = Vector2(0, 44)
	layout.add_child(_character_picker)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh Family Characters"
	refresh_button.pressed.connect(_refresh_characters)
	layout.add_child(refresh_button)

	var force_meet_button := Button.new()
	force_meet_button.text = "Force Meet Someone"
	force_meet_button.pressed.connect(_force_meet_someone)
	layout.add_child(force_meet_button)

	var force_scheduled_button := Button.new()
	force_scheduled_button.text = "Run Next Scheduled Relationship Event Now"
	force_scheduled_button.pressed.connect(_run_next_scheduled_relationship_event)
	layout.add_child(force_scheduled_button)

	var force_divorce_button := Button.new()
	force_divorce_button.text = "Force Divorce Selected Spouse"
	force_divorce_button.pressed.connect(_force_divorce_selected_spouse)
	layout.add_child(force_divorce_button)

	var separator := HSeparator.new()
	layout.add_child(separator)

	_active_event_label = Label.new()
	_active_event_label.text = "Active Event: none"
	_active_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_active_event_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(_active_event_label)

	var choices_title := Label.new()
	choices_title.text = "ACTIVE EVENT CHOICES"
	choices_title.add_theme_font_size_override("font_size", 16)
	layout.add_child(choices_title)

	_choice_container = VBoxContainer.new()
	_choice_container.add_theme_constant_override("separation", 6)
	layout.add_child(_choice_container)

	var dump_button := Button.new()
	dump_button.text = "Dump Relationship NPC State"
	dump_button.pressed.connect(_dump_relationship_state)
	layout.add_child(dump_button)

	var clear_button := Button.new()
	clear_button.text = "Clear Log"
	clear_button.pressed.connect(_clear_log)
	layout.add_child(clear_button)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.fit_content = false
	_log.scroll_active = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 300)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_log)


func _connect_event_signals() -> void:
	if not EventManager.active_event_changed.is_connected(_on_active_event_changed):
		EventManager.active_event_changed.connect(_on_active_event_changed)

	if not EventManager.event_completed.is_connected(_on_event_finished):
		EventManager.event_completed.connect(_on_event_finished)

	if not EventManager.event_cancelled.is_connected(_on_event_finished):
		EventManager.event_cancelled.connect(_on_event_finished)

	if not EventManager.event_expired.is_connected(_on_event_expired):
		EventManager.event_expired.connect(_on_event_expired)


func _on_active_event_changed(_instance: Dictionary) -> void:
	call_deferred("_refresh_active_event_controls")


func _on_event_finished(_instance: Dictionary) -> void:
	call_deferred("_refresh_active_event_controls")


func _on_event_expired(_instance: Dictionary, _reasons: Array) -> void:
	call_deferred("_refresh_active_event_controls")


func _refresh_active_event_controls() -> void:
	if _active_event_label == null or _choice_container == null:
		return

	for child in _choice_container.get_children():
		_choice_container.remove_child(child)
		child.queue_free()

	if EventManager.active_event == null:
		_active_event_label.text = "Active Event: none"

		var empty_label := Label.new()
		empty_label.text = "No active Event. Use Force Meet Someone or run a scheduled Event."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_choice_container.add_child(empty_label)
		return

	var active = EventManager.active_event
	var event: Dictionary = EventManager.registry.get_event(active.event_id)

	if event.is_empty():
		_active_event_label.text = "Active Event: %s (definition missing)" % active.event_id
		return

	var content_value = event.get("content", {})
	var content: Dictionary = content_value if typeof(content_value) == TYPE_DICTIONARY else {}
	var event_title := String(content.get("title", active.event_id))
	var candidate_id := int(active.participants.get("candidate", 0))

	_active_event_label.text = (
		"Active Event: %s\nTitle: %s\nPrimary: %s | Candidate: %s"
		% [
			active.event_id,
			event_title,
			str(active.participants.get("primary", null)),
			str(candidate_id if candidate_id > 0 else null)
		]
	)

	var choices_value = event.get("choices", [])

	if typeof(choices_value) != TYPE_ARRAY or choices_value.is_empty():
		var default_button := Button.new()
		default_button.text = "Resolve Default Event"
		default_button.custom_minimum_size = Vector2(0, 42)
		default_button.pressed.connect(_resolve_active_choice.bind(""))
		_choice_container.add_child(default_button)
		return

	for choice_value in choices_value:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue

		var choice: Dictionary = choice_value
		var choice_id := String(choice.get("choice_id", "")).strip_edges()

		if choice_id.is_empty():
			continue

		var choice_title := String(choice.get("title", choice_id))
		var button := Button.new()
		button.text = choice_title
		button.tooltip_text = "choice_id: %s" % choice_id
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_resolve_active_choice.bind(choice_id))
		_choice_container.add_child(button)


func _resolve_active_choice(choice_id: String) -> void:
	if EventManager.active_event == null:
		_write_log("ERROR: There is no active Event to resolve.")
		_refresh_active_event_controls()
		return

	var event_id := EventManager.active_event.event_id
	var candidate_id := int(EventManager.active_event.participants.get("candidate", 0))

	_write_log(
		"RESOLVING CHOICE\nEvent: %s\nChoice: %s\nCandidate before resolution: %d"
		% [
			event_id,
			choice_id if not choice_id.is_empty() else "<default>",
			candidate_id
		]
	)

	var result: Dictionary = EventManager.resolve_active_event(choice_id)

	if bool(result.get("resolved", false)):
		_write_log(
			"RESOLVED: %s / %s\nOutcome: %s\nEffect results: %s"
			% [
				event_id,
				choice_id if not choice_id.is_empty() else "<default>",
				str(result.get("outcome_id", null)),
				JSON.stringify(result.get("effect_results", []))
			]
		)
	else:
		_write_log(
			"RESOLUTION FAILED: %s / %s\nReasons: %s"
			% [
				event_id,
				choice_id if not choice_id.is_empty() else "<default>",
				_format_failure_reasons(result.get("failure_reasons", []))
			]
		)

	_refresh_characters()
	_refresh_active_event_controls()
	_dump_relationship_state()


func _refresh_characters() -> void:
	if _character_picker == null:
		return

	var previous_id := _selected_character_id()
	_character_picker.clear()

	var family_characters: Array[Dictionary] = []

	for value in CharacterManager.characters:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = value

		if not bool(character.get("is_player_family", false)):
			continue
		if not bool(character.get("is_alive", true)):
			continue

		family_characters.append(character)

	family_characters.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("character_id", 0)) < int(right.get("character_id", 0))
	)

	var restored_index := -1

	for character in family_characters:
		var character_id := int(character.get("character_id", 0))
		var age := CharacterManager.get_character_age(character)
		var first_name := String(character.get("first_name", "Character"))
		var spouse_value = character.get("partner_id", null)
		var spouse_text := "single" if spouse_value == null else "spouse:%s" % str(spouse_value)

		var item_index := _character_picker.item_count
		_character_picker.add_item(
			"%s — ID %d — age %d — %s" % [
				first_name,
				character_id,
				age,
				spouse_text
			]
		)
		_character_picker.set_item_metadata(item_index, character_id)

		if character_id == previous_id:
			restored_index = item_index

	if restored_index >= 0:
		_character_picker.select(restored_index)
	elif _character_picker.item_count > 0:
		_character_picker.select(0)

	if _log != null:
		_write_log("Family Character list refreshed: %d display entries." % _character_picker.item_count)


func _force_meet_someone() -> void:
	var character_id := _selected_character_id()

	if character_id <= 0:
		_write_log("ERROR: Select a Family Character first.")
		return

	if EventManager.active_event != null:
		_write_log(
			"ERROR: An Event is already active (%s). Resolve/close it before forcing another Meet Someone."
			% EventManager.active_event.event_id
		)
		return

	var character := CharacterManager.get_character_by_id(character_id)

	if character.is_empty():
		_write_log("ERROR: Selected Character no longer exists.")
		return

	var age := CharacterManager.get_character_age(character)
	var event_id := _meet_event_id_for_age(age)

	if event_id.is_empty():
		_write_log(
			"ERROR: Selected Character age %d is outside the current Relationship eligibility test range (18–54)."
			% age
		)
		return

	var event: Dictionary = EventManager.registry.get_event(event_id)

	if event.is_empty():
		_write_log("ERROR: Event definition not found: %s" % event_id)
		return

	var runtime_context := {
		"trigger_participants": {
			"primary": character_id
		},
		"trigger_character_id": character_id
	}

	# This still runs the normal Event availability/requirement pipeline.
	# Only the random pool activation roll is bypassed for manual testing.
	var availability: Dictionary = EventManager.runtime_service.get_availability(
		event_id,
		runtime_context
	)

	if String(availability.get("status", "")) != EventRuntimeService.AVAILABLE:
		_write_log(
			"BLOCKED: %s is not currently available for Character %d.\nReasons: %s"
			% [
				event_id,
				character_id,
				_format_failure_reasons(availability.get("failure_reasons", []))
			]
		)
		return

	_force_counter += 1

	var occurrence := EventManager._make_occurrence(
		"calendar",
		"",
		runtime_context,
		"debug_relationship_meet:%d:%d" % [
			character_id,
			_force_counter
		],
		"RelationshipNPCDebugPanel"
	)

	var instance = EventManager._queue_available_event(
		event,
		availability,
		occurrence,
		null,
		true
	)

	if instance == null:
		_write_log("ERROR: Event was available but could not be queued.")
		return

	if EventManager.active_event == null:
		_write_log(
			"ERROR: Event queued but no active Event remained after activation. Check Godot Output for expiry/materialization errors."
		)
		return

	var candidate_id := int(
		EventManager.active_event.participants.get("candidate", 0)
	)

	_write_log(
		"FORCED: %s\nPrimary: %d\nCandidate: %d\nActive instance: %s"
		% [
			event_id,
			character_id,
			candidate_id,
			EventManager.active_event.instance_id
		]
	)

	_refresh_active_event_controls()
	_dump_relationship_state()


func _run_next_scheduled_relationship_event() -> void:
	var character_id := _selected_character_id()

	if character_id <= 0:
		_write_log("ERROR: Select a Family Character first.")
		return

	if EventManager.active_event != null:
		_write_log(
			"ERROR: Resolve/close the active Event (%s) before forcing the next scheduled relationship Event."
			% EventManager.active_event.event_id
		)
		return

	var best_index := -1
	var best_due_key := 2147483647

	for index in EventManager.scheduled_events.size():
		var value = EventManager.scheduled_events[index]

		if typeof(value) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = value

		if String(record.get("status", "")) != "scheduled":
			continue

		var event_id := String(record.get("event_id", ""))

		if not event_id.begins_with("relationship_"):
			continue

		var participants_value = record.get("participants", {})

		if typeof(participants_value) != TYPE_DICTIONARY:
			continue

		var participants: Dictionary = participants_value

		if int(participants.get("primary", 0)) != character_id:
			continue

		var due_date := String(record.get("due_date", ""))
		var due_key := GameCalendar.date_to_ordinal(due_date)

		if due_key < 0:
			continue

		if due_key < best_due_key:
			best_due_key = due_key
			best_index = index

	if best_index < 0:
		_write_log(
			"No scheduled relationship Event found for Character %d."
			% character_id
		)
		return

	var selected_record: Dictionary = EventManager.scheduled_events[best_index]
	var original_due_date := String(selected_record.get("due_date", ""))
	var current_date := TimeManager.get_iso_date_string()
	var selected_event_id := String(selected_record.get("event_id", ""))

	selected_record["due_date"] = current_date
	EventManager.scheduled_events[best_index] = selected_record

	_write_log(
		"FORCING SCHEDULED EVENT: %s\nOriginal due date: %s\nTemporary test due date: %s"
		% [
			selected_event_id,
			original_due_date,
			current_date
		]
	)

	var processed: Array = EventManager.process_scheduled_due(current_date)

	if processed.is_empty():
		_write_log("ERROR: Scheduler processed no records.")
		return

	if EventManager.active_event != null:
		_write_log(
			"ACTIVE: %s\nParticipants: %s"
			% [
				EventManager.active_event.event_id,
				JSON.stringify(EventManager.active_event.participants)
			]
		)
	else:
		_write_log(
			"Scheduler ran, but no relationship Event became active. Inspect the record/state dump and Godot Output."
		)

	_refresh_active_event_controls()
	_dump_relationship_state()


func _force_divorce_selected_spouse() -> void:
	var character_id := _selected_character_id()

	if character_id <= 0:
		_write_log("ERROR: Select a Family Character first.")
		return

	if EventManager.active_event != null:
		_write_log(
			"ERROR: Resolve/close the active Event (%s) before forcing divorce."
			% EventManager.active_event.event_id
		)
		return

	var character := CharacterManager.get_character_by_id(character_id)

	if character.is_empty():
		_write_log("ERROR: Selected Character no longer exists.")
		return

	var partner_value = character.get("partner_id", null)

	if partner_value == null or int(partner_value) <= 0:
		_write_log(
			"BLOCKED: Character %d has no spouse to divorce."
			% character_id
		)
		return

	var partner_id := int(partner_value)
	var partner := CharacterManager.get_character_by_id(partner_id)

	if partner.is_empty():
		_write_log(
			"ERROR: Character %d references missing spouse %d."
			% [character_id, partner_id]
		)
		return

	_write_log(
		"FORCING DIVORCE\nSelected Character: %d\nSpouse: %d"
		% [character_id, partner_id]
	)

	var success := RelationshipNpcManager.divorce_characters(
		character_id,
		partner_id
	)

	if not success:
		_write_log(
			"DIVORCE FAILED: production divorce_characters(%d, %d) returned false."
			% [character_id, partner_id]
		)
		return

	var former_spouse := CharacterManager.get_character_by_id(partner_id)
	var cooldown_value = former_spouse.get(
		"relationship_cooldown_until",
		null
	) if not former_spouse.is_empty() else null

	_write_log(
		"DIVORCE RESOLVED: %d / %d\nFormer spouse cooldown until: %s"
		% [
			character_id,
			partner_id,
			str(cooldown_value)
		]
	)

	_refresh_characters()
	_refresh_active_event_controls()
	_dump_relationship_state()


func _dump_relationship_state() -> void:
	var selected_id := _selected_character_id()
	var lines: Array[String] = []

	lines.append("")
	lines.append("=== RELATIONSHIP STATE ===")
	lines.append("Selected Family Character: %d" % selected_id)
	lines.append(
		"relationship_candidate_ids: %s"
		% JSON.stringify(RelationshipNpcManager.relationship_candidate_ids)
	)

	if EventManager.active_event != null:
		lines.append(
			"Active Event: %s | participants=%s"
			% [
				EventManager.active_event.event_id,
				JSON.stringify(EventManager.active_event.participants)
			]
		)
	else:
		lines.append("Active Event: none")

	var relationship_npc_count := 0

	for value in CharacterManager.characters:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var npc: Dictionary = value

		if String(npc.get("character_type", "")) != "relationship_npc":
			continue

		relationship_npc_count += 1

		var npc_id := int(npc.get("character_id", 0))
		var name := String(npc.get("first_name", ""))
		var status_value = npc.get("relationship_status", null)
		var link_value = npc.get("linked_character_id", null)
		var partner_value = npc.get("partner_id", null)
		var cooldown_value = npc.get("relationship_cooldown_until", null)
		var rejected_value = npc.get("rejected_by_character_ids", [])
		var relation_marker := ""

		if link_value != null and int(link_value) == selected_id:
			relation_marker = " [LINKED TO SELECTED]"
		elif typeof(rejected_value) == TYPE_ARRAY and rejected_value.has(selected_id):
			relation_marker = " [REJECTED BY SELECTED]"

		lines.append(
			"NPC %d %s%s | alive=%s | family=%s | status=%s | linked=%s | partner=%s | cooldown=%s | rejected_by=%s"
			% [
				npc_id,
				name,
				relation_marker,
				str(bool(npc.get("is_alive", true))),
				str(bool(npc.get("is_player_family", false))),
				str(status_value),
				str(link_value),
				str(partner_value),
				str(cooldown_value),
				JSON.stringify(rejected_value)
			]
		)

	lines.append("Relationship NPC total: %d" % relationship_npc_count)

	var scheduled_for_selected := 0

	for value in EventManager.scheduled_events:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = value
		var event_id := String(record.get("event_id", ""))

		if not event_id.begins_with("relationship_"):
			continue

		var participants_value = record.get("participants", {})

		if typeof(participants_value) != TYPE_DICTIONARY:
			continue

		if int(participants_value.get("primary", 0)) != selected_id:
			continue

		if String(record.get("status", "")) != "scheduled":
			continue

		scheduled_for_selected += 1
		lines.append(
			"Scheduled: %s | due=%s | participants=%s"
			% [
				event_id,
				String(record.get("due_date", "")),
				JSON.stringify(participants_value)
			]
		)

	lines.append("Scheduled relationship Events for selected: %d" % scheduled_for_selected)
	lines.append("==========================")

	_write_log("\n".join(lines))


func _meet_event_id_for_age(age: int) -> String:
	if age >= 18 and age <= 20:
		return "relationship_01_meet_18_20"
	if age >= 21 and age <= 23:
		return "relationship_01_meet_21_23"
	if age >= 24 and age <= 26:
		return "relationship_01_meet_24_26"
	if age >= 27 and age <= 29:
		return "relationship_01_meet_27_29"
	if age >= 30 and age <= 54:
		return "relationship_01_meet_guaranteed_30"
	return ""


func _selected_character_id() -> int:
	if _character_picker == null:
		return 0
	if _character_picker.item_count <= 0:
		return 0
	if _character_picker.selected < 0:
		return 0

	var metadata = _character_picker.get_item_metadata(
		_character_picker.selected
	)

	return int(metadata) if metadata != null else 0


func _format_failure_reasons(value) -> String:
	if typeof(value) != TYPE_ARRAY:
		return str(value)

	var messages: Array[String] = []

	for reason_value in value:
		if typeof(reason_value) == TYPE_DICTIONARY:
			var reason: Dictionary = reason_value
			messages.append(
				"%s: %s"
				% [
					String(reason.get("code", "unknown")),
					String(reason.get("message", ""))
				]
			)
		else:
			messages.append(str(reason_value))

	return " | ".join(messages)


func _write_log(text: String) -> void:
	if _log == null:
		return

	if not _log.text.is_empty():
		_log.append_text("\n\n")

	_log.append_text(text)
	print("[RelationshipNPCDebug] ", text)


func _clear_log() -> void:
	if _log != null:
		_log.clear()
