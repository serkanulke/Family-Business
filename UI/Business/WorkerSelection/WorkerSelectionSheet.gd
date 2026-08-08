extends Control


signal candidate_selected(
	source_type: String,
	candidate_id
)

signal cancelled


const SOURCE_FAMILY := "family"
const SOURCE_NPC := "npc"

const FILTER_ALL := "all"
const FILTER_YOUNG_ADULT := "young_adult"
const FILTER_ADULT := "adult"
const FILTER_ELDER := "elder"


var business_instance_id: String = ""
var business_type_id: String = ""
var slot_id: String = ""
var source_type: String = SOURCE_NPC
var age_filter: String = FILTER_ALL


@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

@onready var all_button: Button = %AllButton
@onready var young_adult_button: Button = %YoungAdultButton
@onready var adult_button: Button = %AdultButton
@onready var elder_button: Button = %ElderButton

@onready var candidate_list: VBoxContainer = %CandidateList
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(
		_on_close_pressed
	)

	all_button.pressed.connect(
		func() -> void:
			_set_age_filter(
				FILTER_ALL
			)
	)

	young_adult_button.pressed.connect(
		func() -> void:
			_set_age_filter(
				FILTER_YOUNG_ADULT
			)
	)

	adult_button.pressed.connect(
		func() -> void:
			_set_age_filter(
				FILTER_ADULT
			)
	)

	elder_button.pressed.connect(
		func() -> void:
			_set_age_filter(
				FILTER_ELDER
			)
	)

	_refresh()


func setup(
	new_business_instance_id: String,
	new_business_type_id: String,
	new_slot_id: String,
	new_source_type: String
) -> void:
	business_instance_id = new_business_instance_id
	business_type_id = new_business_type_id
	slot_id = new_slot_id

	if new_source_type in [
		SOURCE_FAMILY,
		SOURCE_NPC
	]:
		source_type = new_source_type

	if is_node_ready():
		_refresh()


func _set_age_filter(
	new_filter: String
) -> void:
	if new_filter not in [
		FILTER_ALL,
		FILTER_YOUNG_ADULT,
		FILTER_ADULT,
		FILTER_ELDER
	]:
		return

	age_filter = new_filter
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return

	_clear_candidate_list()

	var slot_definition: Dictionary = (
		BusinessManager.get_slot_definition(
			business_type_id,
			slot_id
		)
	)

	var slot_name := str(
		slot_definition.get(
			"name",
			slot_id
		)
	)

	title_label.text = slot_name

	subtitle_label.text = (
		"Select a family member"
		if source_type == SOURCE_FAMILY
		else "Select the best candidate"
	)

	var candidates: Array = _get_candidates()

	empty_label.visible = candidates.is_empty()

	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue

		var candidate: Dictionary = candidate_value
		var card := _create_candidate_card(
			candidate
		)

		candidate_list.add_child(
			card
		)


func _get_candidates() -> Array:
	if business_type_id.is_empty():
		return []

	if slot_id.is_empty():
		return []

	if source_type == SOURCE_FAMILY:
		return BusinessManager.get_family_candidates_for_slot(
			business_type_id,
			slot_id,
			age_filter
		)

	var npc_manager := get_node_or_null(
		"/root/NPCManager"
	)

	if npc_manager == null:
		return []

	return npc_manager.get_candidates_for_slot(
		business_type_id,
		slot_id,
		age_filter
	)


func _clear_candidate_list() -> void:
	for child in candidate_list.get_children():
		child.queue_free()


func _create_candidate_card(
	candidate: Dictionary
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(
		0,
		176
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		18
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		18
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)

	panel.add_child(
		margin
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		16
	)

	margin.add_child(
		row
	)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	row.add_child(
		details
	)

	var name_label := Label.new()
	name_label.text = _get_candidate_name(
		candidate
	)
	name_label.add_theme_font_size_override(
		"font_size",
		22
	)
	details.add_child(
		name_label
	)

	var age_label := Label.new()
	age_label.text = "%d · %s" % [
		int(
			candidate.get(
				"age",
				0
			)
		),
		_format_life_stage(
			str(
				candidate.get(
					"life_stage",
					""
				)
			)
		)
	]
	details.add_child(
		age_label
	)

	var performance_label := Label.new()
	performance_label.text = "%s · %.1f" % [
		str(
			candidate.get(
				"performance_tier",
				""
			)
		),
		float(
			candidate.get(
				"performance_score",
				0.0
			)
		)
	]
	details.add_child(
		performance_label
	)

	var income_label := Label.new()
	income_label.text = "+%d /mo Business Income" % int(
		candidate.get(
			"business_income",
			0
		)
	)
	details.add_child(
		income_label
	)

	if source_type == SOURCE_FAMILY and bool(
		candidate.get(
			"has_external_job",
			false
		)
	):
		var external_job_label := Label.new()
		external_job_label.text = (
			"Currently employed externally"
		)
		details.add_child(
			external_job_label
		)

	var select_button := Button.new()
	select_button.custom_minimum_size = Vector2(
		110,
		64
	)
	select_button.text = "Select"

	var candidate_id = (
		candidate.get(
			"character_id",
			0
		)
		if source_type == SOURCE_FAMILY
		else candidate.get(
			"npc_id",
			""
		)
	)

	select_button.pressed.connect(
		func() -> void:
			candidate_selected.emit(
				source_type,
				candidate_id
			)
	)

	row.add_child(
		select_button
	)

	return panel


func _get_candidate_name(
	candidate: Dictionary
) -> String:
	return (
		str(
			candidate.get(
				"first_name",
				""
			)
		)
		+ " "
		+ str(
			candidate.get(
				"last_name",
				""
			)
		)
	).strip_edges()


func _format_life_stage(
	value: String
) -> String:
	match value:
		FILTER_YOUNG_ADULT:
			return "Young Adult"
		FILTER_ADULT:
			return "Adult"
		FILTER_ELDER:
			return "Elder"
		_:
			return value.capitalize()


func _on_close_pressed() -> void:
	cancelled.emit()
	queue_free()
