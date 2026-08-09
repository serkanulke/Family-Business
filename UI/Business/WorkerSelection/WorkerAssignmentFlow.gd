extends Control

signal assignment_completed(
	business_instance_id: String,
	slot_id: String,
	source_type: String,
	candidate_id
)
signal assignment_failed(source_type: String, candidate_id)
signal cancelled

const WORKER_TYPE_SCENE := preload(
	"res://UI/Business/WorkerSelection/WorkerTypeSheet.tscn"
)
const NPC_WORKER_SCENE := preload(
	"res://UI/Business/WorkerSelection/NPCWorkerSheet.tscn"
)
const FAMILY_MEMBER_SCENE := preload(
	"res://UI/Business/WorkerSelection/FamilyMemberSheet.tscn"
)

const SOURCE_FAMILY := "family"
const SOURCE_NPC := "npc"

var business_instance_id: String = ""
var business_type_id: String = ""
var slot_id: String = ""
var replace_mode: bool = false
var active_sheet: Control = null


func _ready() -> void:
	if not business_instance_id.is_empty():
		_open_worker_type_sheet()


func setup(
	new_business_instance_id: String,
	new_business_type_id: String,
	new_slot_id: String,
	is_replace: bool = false
) -> void:
	business_instance_id = new_business_instance_id
	business_type_id = new_business_type_id
	slot_id = new_slot_id
	replace_mode = is_replace
	if is_node_ready():
		_open_worker_type_sheet()


func _open_worker_type_sheet() -> void:
	_clear_active_sheet()
	var sheet := WORKER_TYPE_SCENE.instantiate()
	active_sheet = sheet
	add_child(sheet)

	var slot_definition: Dictionary = BusinessManager.get_slot_definition(
		business_type_id,
		slot_id
	)
	var role_name := str(slot_definition.get("role_name", slot_id))
	sheet.setup(role_name, replace_mode)
	sheet.source_selected.connect(_on_source_selected)
	sheet.cancelled.connect(_on_cancelled)


func _open_worker_selection_sheet(source_type: String) -> void:
	_clear_active_sheet()
	var packed_scene: PackedScene = (
		FAMILY_MEMBER_SCENE
		if source_type == SOURCE_FAMILY
		else NPC_WORKER_SCENE
	)
	var sheet := packed_scene.instantiate()
	active_sheet = sheet
	add_child(sheet)
	sheet.setup(business_instance_id, business_type_id, slot_id, source_type)
	sheet.candidate_selected.connect(_on_candidate_selected)
	sheet.cancelled.connect(_on_selection_cancelled)


func _on_source_selected(source_type: String) -> void:
	if source_type not in [SOURCE_FAMILY, SOURCE_NPC]:
		return
	_open_worker_selection_sheet(source_type)


func _on_candidate_selected(source_type: String, candidate_id) -> void:
	var success := false
	if source_type == SOURCE_FAMILY:
		var character_id := int(candidate_id)
		if replace_mode:
			success = BusinessManager.replace_slot_with_character(
				business_instance_id,
				slot_id,
				character_id
			)
		else:
			success = BusinessManager.assign_character_to_slot(
				business_instance_id,
				slot_id,
				character_id
			)
	elif source_type == SOURCE_NPC:
		var npc_id := str(candidate_id)
		if replace_mode:
			success = BusinessManager.replace_slot_with_npc(
				business_instance_id,
				slot_id,
				npc_id
			)
		else:
			success = BusinessManager.assign_npc_to_slot(
				business_instance_id,
				slot_id,
				npc_id
			)

	if not success:
		assignment_failed.emit(source_type, candidate_id)
		if active_sheet != null and is_instance_valid(active_sheet):
			if active_sheet.has_method("show_assignment_error"):
				active_sheet.show_assignment_error()
		return

	assignment_completed.emit(
		business_instance_id,
		slot_id,
		source_type,
		candidate_id
	)
	queue_free()


func _on_selection_cancelled() -> void:
	_open_worker_type_sheet()


func _on_cancelled() -> void:
	cancelled.emit()
	queue_free()


func _clear_active_sheet() -> void:
	if active_sheet == null:
		return
	if is_instance_valid(active_sheet):
		if active_sheet.get_parent() == self:
			remove_child(active_sheet)
		active_sheet.queue_free()
	active_sheet = null
