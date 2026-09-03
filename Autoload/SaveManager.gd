extends Node


signal save_completed(
	save_id: int
)

signal load_completed(
	save_id: int
)

signal save_deleted(
	save_id: int
)

signal current_save_changed(
	save_id: int
)

const SAVE_VERSION := 6
const MIN_SUPPORTED_SAVE_VERSION := 2
const DEFAULT_SAVE_DIRECTORY := "user://saves"
const SAVE_FILE_PREFIX := "save_"
const SAVE_FILE_SUFFIX := ".json"

var save_directory: String = DEFAULT_SAVE_DIRECTORY
var current_save_id: int = -1

var _autosave_queued: bool = false
var _is_starting_new_game: bool = false


func _ready() -> void:
	if not GameManager.new_game_starting.is_connected(
		_on_new_game_starting
	):
		GameManager.new_game_starting.connect(
			_on_new_game_starting
		)

	if not GameManager.new_game_started.is_connected(
		_on_new_game_started
	):
		GameManager.new_game_started.connect(
			_on_new_game_started
		)

	_connect_autosave_signals()


func create_new_save() -> int:
	if GameManager.family_name.strip_edges().is_empty():
		push_warning(
			"A new save was not created because family_name is empty."
		)
		return -1

	var new_save_id := _generate_unique_save_id()
	var previous_save_id := current_save_id

	current_save_id = new_save_id

	if not save_game(
		new_save_id
	):
		current_save_id = previous_save_id
		return -1

	current_save_changed.emit(
		current_save_id
	)

	return current_save_id


func save_current_game() -> bool:
	if current_save_id <= 0:
		return false

	return save_game(
		current_save_id
	)


func autosave_current_game() -> bool:
	if _is_starting_new_game:
		return false

	return save_current_game()


func request_autosave() -> void:
	if (
		_is_starting_new_game
		or current_save_id <= 0
		or _autosave_queued
	):
		return

	_autosave_queued = true
	call_deferred(
		"_perform_deferred_autosave"
	)


func save_game(
	save_id: int
) -> bool:
	if save_id <= 0:
		push_error(
			"Invalid save ID: "
			+ str(save_id)
		)
		return false

	if not _ensure_save_directory():
		return false

	var save_path := get_save_path(
		save_id
	)

	var now_msec := int(
		Time.get_unix_time_from_system()
		* 1000.0
	)

	var created_at_msec := now_msec

	if FileAccess.file_exists(
		save_path
	):
		var existing_data := _read_save_file(
			save_path,
			false
		)

		if not existing_data.is_empty():
			var existing_metadata := _get_dictionary(
				existing_data,
				"metadata"
			)

			created_at_msec = int(
				existing_metadata.get(
					"created_at_unix_msec",
					now_msec
				)
			)

	var save_data := create_save_snapshot()

	var metadata := _get_dictionary(
		save_data,
		"metadata"
	)

	metadata["save_id"] = save_id
	metadata["created_at_unix_msec"] = created_at_msec
	metadata["saved_at_unix_msec"] = now_msec
	save_data["metadata"] = metadata

	var file := FileAccess.open(
		save_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Save file could not be opened for writing: "
			+ save_path
		)
		return false

	file.store_string(
		JSON.stringify(
			save_data,
			"\t"
		)
	)

	file.close()

	save_completed.emit(
		save_id
	)

	print(
		"Game saved.",
		" | Save ID: ",
		save_id,
		" | Family: ",
		GameManager.family_name,
		" | Money: ",
		GameManager.family_money,
		" | Date: ",
		TimeManager.get_iso_date_string()
	)

	return true


func load_game(
	save_id: int
) -> bool:
	if save_id <= 0:
		push_error(
			"Invalid save ID: "
			+ str(save_id)
		)
		return false

	var save_path := get_save_path(
		save_id
	)

	if not FileAccess.file_exists(
		save_path
	):
		push_warning(
			"Save file does not exist: "
			+ str(save_id)
		)
		return false

	var save_data := _read_save_file(
		save_path
	)

	if save_data.is_empty():
		return false

	if not apply_save_snapshot(
		save_data
	):
		return false

	current_save_id = save_id
	current_save_changed.emit(
		current_save_id
	)

	load_completed.emit(
		save_id
	)

	print(
		"Game loaded.",
		" | Save ID: ",
		save_id,
		" | Family: ",
		GameManager.family_name,
		" | Money: ",
		GameManager.family_money,
		" | Date: ",
		TimeManager.get_iso_date_string()
	)

	return true


func create_save_snapshot() -> Dictionary:
	var metadata := {
		"family_name": GameManager.family_name,
		"wealth": GameManager.family_money,
		"population": _get_living_family_population(),
		"owned_businesses": BusinessManager.businesses.size(),
		"game_date": TimeManager.get_iso_date_string()
	}

	return {
		"save_version": SAVE_VERSION,
		"metadata": metadata,
		"game_manager": {
			"lifespan_setting": GameManager.lifespan_setting,
			"family_money": GameManager.family_money,
			"diamonds": GameManager.diamonds,
			"family_name": GameManager.family_name
		},
		"time_manager": {
			"current_day": TimeManager.current_day,
			"current_month": TimeManager.current_month,
			"current_year": TimeManager.current_year,
			"is_paused": TimeManager.is_paused,
			"speed_multiplier": TimeManager.speed_multiplier,
			"day_timer": TimeManager.day_timer
		},
		"character_manager": {
			"characters": CharacterManager.characters.duplicate(true),
			"next_character_id": CharacterManager.next_character_id
		},
		"house_manager": HouseManager.create_save_state(),
		"business_manager": {
			"businesses": BusinessManager.businesses.duplicate(true),
			"next_business_instance_number": BusinessManager.next_business_instance_number
		},
		"npc_manager": {
			"worker_npcs": NPCManager.worker_npcs.duplicate(true),
			"next_worker_npc_number": NPCManager.next_worker_npc_number,
			"months_until_next_generation": NPCManager.months_until_next_generation,
			"last_processed_month_key": NPCManager.last_processed_month_key
		},
		"relationship_manager": {
			"relationship_candidate_ids": RelationshipNpcManager.relationship_candidate_ids.duplicate(true)
		},
		"career_manager": {
			"active_job_offers": CareerManager.active_job_offers.duplicate(true)
		},
		"economy_manager": {
			"last_external_salary_payment_date": EconomyManager.last_external_salary_payment_date,
			"last_family_business_payment_date": EconomyManager.last_family_business_payment_date,
			"last_family_business_breakdown": EconomyManager.last_family_business_breakdown.duplicate(true),
			"last_house_payment_date": EconomyManager.last_house_payment_date,
			"last_house_expense": EconomyManager.last_house_expense
		},
		"education_manager": {
			"education_event_queue": EducationManager.education_event_queue.duplicate(true),
			"current_education_event": EducationManager.current_education_event.duplicate(true),
			"is_education_event_active": EducationManager.is_education_event_active,
			"is_education_pause_active": EducationManager.is_education_pause_active,
			"should_resume_time_after_education_events": EducationManager.should_resume_time_after_education_events
		},
		"item_manager": ItemManager.create_save_state(),
		"event_system": EventManager.export_runtime_state()
	}


func apply_save_snapshot(
	save_data: Dictionary
) -> bool:
	if not _validate_save_data(
		save_data
	):
		return false

	# Release any Event-owned pause from the currently running game before
	# restoring the saved TimeManager state. Event state is restored last,
	# after every authoritative domain referenced by participant/context IDs.
	EventManager.reset_runtime_state()
	var save_version := int(save_data.get("save_version", -1))

	var game_state := _get_dictionary(
		save_data,
		"game_manager"
	)
	var time_state := _get_dictionary(
		save_data,
		"time_manager"
	)
	var character_state := _get_dictionary(
		save_data,
		"character_manager"
	)
	var business_state := _get_dictionary(
		save_data,
		"business_manager"
	)
	var house_state := _get_dictionary(
		save_data,
		"house_manager"
	)
	var npc_state := _get_dictionary(
		save_data,
		"npc_manager"
	)
	var relationship_state := _get_dictionary(
		save_data,
		"relationship_manager"
	)
	var career_state := _get_dictionary(
		save_data,
		"career_manager"
	)
	var economy_state := _get_dictionary(
		save_data,
		"economy_manager"
	)
	var education_state := _get_dictionary(
		save_data,
		"education_manager"
	)
	var item_state := _get_dictionary(
		save_data,
		"item_manager"
	)

	# Do not emit ordinary gameplay signals while restoring. Autoloads are
	# already alive; emitting date/money/relationship signals mid-load could
	# create NPCs, settle salaries or rebuild UI from partially restored data.
	GameManager.lifespan_setting = String(
		game_state.get(
			"lifespan_setting",
			"normal"
		)
	)

	if not GameManager.VALID_LIFESPAN_SETTINGS.has(
		GameManager.lifespan_setting
	):
		GameManager.lifespan_setting = "normal"

	GameManager.family_money = maxi(
		int(
			game_state.get(
				"family_money",
				0
			)
		),
		0
	)
	GameManager.diamonds = maxi(
		int(
			game_state.get(
				"diamonds",
				0
			)
		),
		0
	)
	GameManager.family_name = String(
		game_state.get(
			"family_name",
			""
		)
	).strip_edges()

	TimeManager.current_day = clampi(
		int(
			time_state.get(
				"current_day",
				TimeManager.START_DAY
			)
		),
		1,
		31
	)
	TimeManager.current_month = clampi(
		int(
			time_state.get(
				"current_month",
				TimeManager.START_MONTH
			)
		),
		1,
		12
	)
	TimeManager.current_year = maxi(
		int(
			time_state.get(
				"current_year",
				TimeManager.START_YEAR
			)
		),
		1
	)
	TimeManager.is_paused = bool(
		time_state.get(
			"is_paused",
			true
		)
	)
	TimeManager.speed_multiplier = _normalize_speed(
		float(
			time_state.get(
				"speed_multiplier",
				1.0
			)
		)
	)
	TimeManager.day_timer = maxf(
		float(
			time_state.get(
				"day_timer",
				0.0
			)
		),
		0.0
	)

	CharacterManager.characters = _get_array(
		character_state,
		"characters"
	).duplicate(true)

	if CharacterManager.has_method(
		"normalize_character_ids"
	):
		CharacterManager.call(
			"normalize_character_ids"
		)

	if CharacterManager.has_method(
		"normalize_character_flag_ids"
	):
		CharacterManager.call(
			"normalize_character_flag_ids"
		)

	if CharacterManager.has_method(
		"normalize_character_parent_links"
	):
		CharacterManager.call(
			"normalize_character_parent_links"
		)

	if CharacterManager.has_method(
		"normalize_character_portraits"
	):
		CharacterManager.call(
			"normalize_character_portraits"
		)

	if CharacterManager.has_method(
		"initialize_next_character_id"
	):
		CharacterManager.call(
			"initialize_next_character_id"
		)

	CharacterManager.next_character_id = maxi(
		CharacterManager.next_character_id,
		int(
			character_state.get(
				"next_character_id",
				1
			)
		)
	)

	if CharacterManager.has_method(
		"update_all_life_stages"
	):
		CharacterManager.call(
			"update_all_life_stages"
		)

	HouseManager.restore_save_state(house_state)

	BusinessManager.businesses = _get_array(
		business_state,
		"businesses"
	).duplicate(true)
	BusinessManager.next_business_instance_number = maxi(
		int(
			business_state.get(
				"next_business_instance_number",
				1
			)
		),
		1
	)

	# Retirement owns Family Business slot cleanup, so normalize it only after
	# the saved Business roster has been restored.
	if CharacterManager.has_method(
		"update_all_retirements"
	):
		CharacterManager.call(
			"update_all_retirements"
		)

	NPCManager.worker_npcs = _get_array(
		npc_state,
		"worker_npcs"
	).duplicate(true)
	NPCManager.next_worker_npc_number = maxi(
		int(
			npc_state.get(
				"next_worker_npc_number",
				1
			)
		),
		1
	)
	NPCManager.months_until_next_generation = maxi(
		int(
			npc_state.get(
				"months_until_next_generation",
				1
			)
		),
		1
	)
	NPCManager.last_processed_month_key = int(
		npc_state.get(
			"last_processed_month_key",
			-1
		)
	)

	RelationshipNpcManager.relationship_candidate_ids = (
		_restore_int_array(
			_get_array(
				relationship_state,
				"relationship_candidate_ids"
			)
		)
	)

	CareerManager.active_job_offers = (
		_restore_int_key_dictionary(
			_get_dictionary(
				career_state,
				"active_job_offers"
			)
		)
	)

	EconomyManager.last_external_salary_payment_date = String(
		economy_state.get(
			"last_external_salary_payment_date",
			""
		)
	)
	EconomyManager.last_family_business_payment_date = String(
		economy_state.get(
			"last_family_business_payment_date",
			""
		)
	)
	EconomyManager.last_family_business_breakdown = _get_array(
		economy_state,
		"last_family_business_breakdown"
	).duplicate(true)
	EconomyManager.last_house_payment_date = String(
		economy_state.get("last_house_payment_date", "")
	)
	EconomyManager.last_house_expense = maxi(
		int(economy_state.get("last_house_expense", 0)),
		0
	)

	EducationManager.education_event_queue = _get_array(
		education_state,
		"education_event_queue"
	).duplicate(true)
	EducationManager.current_education_event = _get_dictionary(
		education_state,
		"current_education_event"
	).duplicate(true)
	EducationManager.is_education_event_active = bool(
		education_state.get(
			"is_education_event_active",
			false
		)
	)
	EducationManager.is_education_pause_active = bool(
		education_state.get(
			"is_education_pause_active",
			false
		)
	)
	EducationManager.should_resume_time_after_education_events = bool(
		education_state.get(
			"should_resume_time_after_education_events",
			false
		)
	)

	# Version 2 saves predate the item backend. Version 3 used one global shop
	# stock array. ItemManager migrates both shapes into the slot-specific model.
	ItemManager.restore_save_state(item_state)

	if save_version < 6:
		# Production v2-v5 saves predate Event persistence and therefore have no
		# truthful history, queue, cooldown, schedule, or temporary-flag state.
		EventManager.reset_runtime_state()
	elif typeof(save_data.get("event_system", null)) != TYPE_DICTIONARY:
		push_warning("Save data has no valid event_system section; Event runtime was reset safely.")
		EventManager.reset_runtime_state()
	elif not EventManager.import_runtime_state(save_data["event_system"]):
		push_warning("Event runtime state was rejected and reset safely: " + EventManager.last_import_error)
		EventManager.reset_runtime_state()

	return true


func has_save(
	save_id: int
) -> bool:
	if save_id <= 0:
		return false

	return FileAccess.file_exists(
		get_save_path(
			save_id
		)
	)


func has_any_save() -> bool:
	return get_save_count() > 0


func get_save_count() -> int:
	return _list_save_ids().size()


func delete_save(
	save_id: int
) -> bool:
	if save_id <= 0:
		return false

	var save_path := get_save_path(
		save_id
	)

	if not FileAccess.file_exists(
		save_path
	):
		return true

	var absolute_path := ProjectSettings.globalize_path(
		save_path
	)

	var error := DirAccess.remove_absolute(
		absolute_path
	)

	if error != OK:
		push_error(
			"Save file could not be deleted: "
			+ save_path
		)
		return false

	if current_save_id == save_id:
		current_save_id = -1
		current_save_changed.emit(
			current_save_id
		)

	save_deleted.emit(
		save_id
	)

	return true


func get_save_summary(
	save_id: int
) -> Dictionary:
	if not has_save(
		save_id
	):
		return {}

	var save_data := _read_save_file(
		get_save_path(
			save_id
		)
	)

	if save_data.is_empty():
		return {}

	var metadata := _get_dictionary(
		save_data,
		"metadata"
	).duplicate(true)

	metadata["save_id"] = save_id

	return metadata


func get_all_save_summaries() -> Array:
	var summaries: Array = []

	for save_id in _list_save_ids():
		var summary := get_save_summary(
			save_id
		)

		if summary.is_empty():
			continue

		summaries.append(
			summary
		)

	summaries.sort_custom(
		_sort_summaries_newest_first
	)

	return summaries


func get_most_recent_save_id() -> int:
	var summaries := get_all_save_summaries()

	if summaries.is_empty():
		return -1

	return int(
		summaries[0].get(
			"save_id",
			-1
		)
	)


func get_save_path(
	save_id: int
) -> String:
	return save_directory.path_join(
		SAVE_FILE_PREFIX
		+ str(save_id)
		+ SAVE_FILE_SUFFIX
	)


func _on_new_game_starting() -> void:
	# Save the current family before GameManager clears its runtime state.
	if current_save_id > 0:
		save_current_game()

	current_save_id = -1
	current_save_changed.emit(
		current_save_id
	)

	_is_starting_new_game = true
	_autosave_queued = false


func _on_new_game_started(
	_starting_character: Dictionary
) -> void:
	_is_starting_new_game = false

	if GameManager.family_name.strip_edges().is_empty():
		push_warning(
			"New game has no family name yet; automatic save creation was skipped."
		)
		return

	create_new_save()


func _connect_autosave_signals() -> void:
	_connect_signal_for_autosave(
		GameManager,
		"family_money_changed"
	)
	_connect_signal_for_autosave(
		GameManager,
		"diamonds_changed"
	)
	_connect_signal_for_autosave(
		GameManager,
		"family_name_changed"
	)
	_connect_signal_for_autosave(
		CharacterManager,
		"character_born"
	)
	_connect_signal_for_autosave(
		CharacterManager,
		"character_died"
	)
	_connect_signal_for_autosave(
		HouseManager,
		"house_created"
	)
	_connect_signal_for_autosave(
		HouseManager,
		"house_state_changed"
	)
	_connect_signal_for_autosave(
		HouseManager,
		"house_upgraded"
	)
	_connect_signal_for_autosave(
		HouseManager,
		"unhoused_penalties_applied"
	)
	_connect_signal_for_autosave(
		NPCManager,
		"worker_pool_changed"
	)
	_connect_signal_for_autosave(
		RelationshipNpcManager,
		"family_relationship_changed"
	)
	_connect_signal_for_autosave(
		BusinessManager,
		"family_business_created"
	)
	_connect_signal_for_autosave(
		BusinessManager,
		"family_business_upgraded"
	)
	_connect_signal_for_autosave(
		BusinessManager,
		"family_business_slot_changed"
	)
	_connect_signal_for_autosave(
		BusinessManager,
		"family_business_npc_slot_changed"
	)
	_connect_signal_for_autosave(
		CareerManager,
		"job_offer_requested"
	)
	_connect_signal_for_autosave(
		EducationManager,
		"education_event_requested"
	)
	_connect_signal_for_autosave(
		EducationManager,
		"major_selection_requested"
	)
	_connect_signal_for_autosave(
		ItemManager,
		"monthly_stock_changed"
	)
	_connect_signal_for_autosave(
		ItemManager,
		"inventory_changed"
	)
	_connect_signal_for_autosave(
		ItemManager,
		"equipment_changed"
	)
	_connect_signal_for_autosave(
		EventManager,
		"queue_changed"
	)
	_connect_signal_for_autosave(
		EventManager,
		"event_completed"
	)
	_connect_signal_for_autosave(
		EventManager,
		"event_cancelled"
	)
	_connect_signal_for_autosave(
		EventManager,
		"event_expired"
	)
	_connect_signal_for_autosave(
		EventManager,
		"scheduled_event_changed"
	)


func _connect_signal_for_autosave(
	source: Object,
	signal_name: String
) -> void:
	if not source.has_signal(
		signal_name
	):
		return

	var callable := Callable(
		self,
		"_on_autosave_relevant_signal"
	)

	if source.is_connected(
		signal_name,
		callable
	):
		return

	source.connect(
		signal_name,
		callable
	)


func _on_autosave_relevant_signal(
	_arg1 = null,
	_arg2 = null,
	_arg3 = null,
	_arg4 = null
) -> void:
	request_autosave()


func _perform_deferred_autosave() -> void:
	_autosave_queued = false
	autosave_current_game()


func _generate_unique_save_id() -> int:
	if not _ensure_save_directory():
		return -1

	var candidate := maxi(
		int(
			Time.get_unix_time_from_system()
			* 1000.0
		),
		1
	)

	while FileAccess.file_exists(
		get_save_path(
			candidate
		)
	):
		candidate += 1

	return candidate


func _list_save_ids() -> Array[int]:
	var result: Array[int] = []

	if not _ensure_save_directory():
		return result

	var directory := DirAccess.open(
		save_directory
	)

	if directory == null:
		return result

	directory.list_dir_begin()

	var file_name := directory.get_next()

	while not file_name.is_empty():
		if (
			not directory.current_is_dir()
			and file_name.begins_with(
				SAVE_FILE_PREFIX
			)
			and file_name.ends_with(
				SAVE_FILE_SUFFIX
			)
		):
			var id_text := file_name.trim_prefix(
				SAVE_FILE_PREFIX
			).trim_suffix(
				SAVE_FILE_SUFFIX
			)

			if id_text.is_valid_int():
				var save_id := int(
					id_text
				)

				if save_id > 0:
					result.append(
						save_id
					)

		file_name = directory.get_next()

	directory.list_dir_end()

	return result


func _sort_summaries_newest_first(
	first_value: Variant,
	second_value: Variant
) -> bool:
	if (
		typeof(first_value) != TYPE_DICTIONARY
		or typeof(second_value) != TYPE_DICTIONARY
	):
		return false

	var first: Dictionary = first_value
	var second: Dictionary = second_value

	var first_saved := int(
		first.get(
			"saved_at_unix_msec",
			0
		)
	)
	var second_saved := int(
		second.get(
			"saved_at_unix_msec",
			0
		)
	)

	if first_saved == second_saved:
		return int(
			first.get(
				"save_id",
				0
			)
		) > int(
			second.get(
				"save_id",
				0
			)
		)

	return first_saved > second_saved


func _validate_save_data(
	save_data: Dictionary
) -> bool:
	var version := int(
		save_data.get(
			"save_version",
			-1
		)
	)

	if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
		push_error(
			"Unsupported save version: "
			+ str(version)
		)
		return false

	var required_sections: Array[String] = [
		"game_manager",
		"time_manager",
		"character_manager",
		"business_manager",
		"npc_manager",
		"relationship_manager",
		"career_manager",
		"economy_manager",
		"education_manager"
	]
	if version >= 5:
		required_sections.append("house_manager")
	if version >= 3:
		required_sections.append("item_manager")

	for section_name in required_sections:
		if typeof(
			save_data.get(
				section_name,
				null
			)
		) != TYPE_DICTIONARY:
			push_error(
				"Save data is missing section: "
				+ section_name
			)
			return false

	return true


func _read_save_file(
	save_path: String,
	report_errors: bool = true
) -> Dictionary:
	var file := FileAccess.open(
		save_path,
		FileAccess.READ
	)

	if file == null:
		if report_errors:
			push_error(
				"Save file could not be opened: "
				+ save_path
			)
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(
		json_text
	)

	if parse_result != OK:
		if report_errors:
			push_error(
				"Save JSON error at line %d: %s"
				% [
					json.get_error_line(),
					json.get_error_message()
				]
			)
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		if report_errors:
			push_error(
				"Save JSON root must be a Dictionary."
			)
		return {}

	return json.data


func _ensure_save_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(
		save_directory
	)

	var error := DirAccess.make_dir_recursive_absolute(
		absolute_path
	)

	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error(
			"Save directory could not be created: "
			+ save_directory
		)
		return false

	return true


func _get_living_family_population() -> int:
	var population := 0

	for character_value in CharacterManager.characters:
		if typeof(
			character_value
		) != TYPE_DICTIONARY:
			continue

		var character: Dictionary = character_value

		if not bool(
			character.get(
				"is_player_family",
				false
			)
		):
			continue

		if not bool(
			character.get(
				"is_alive",
				true
			)
		):
			continue

		population += 1

	return population


func _normalize_speed(
	value: float
) -> float:
	if is_equal_approx(
		value,
		2.0
	):
		return 2.0

	if is_equal_approx(
		value,
		3.0
	):
		return 3.0

	return 1.0


func _restore_int_array(
	values: Array
) -> Array[int]:
	var result: Array[int] = []

	for value in values:
		result.append(
			int(value)
		)

	return result


func _restore_int_key_dictionary(
	source: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	for key_value in source.keys():
		var normalized_key := int(
			key_value
		)
		var value = source[
			key_value
		]

		if typeof(value) == TYPE_DICTIONARY:
			result[normalized_key] = (
				(value as Dictionary).duplicate(true)
			)
		else:
			result[normalized_key] = value

	return result


func _get_dictionary(
	source: Dictionary,
	key: String
) -> Dictionary:
	var value = source.get(
		key,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return value


func _get_array(
	source: Dictionary,
	key: String
) -> Array:
	var value = source.get(
		key,
		[]
	)

	if typeof(value) != TYPE_ARRAY:
		return []

	return value
