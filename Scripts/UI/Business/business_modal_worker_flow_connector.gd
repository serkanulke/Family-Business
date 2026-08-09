extends Node

const WORKER_ASSIGNMENT_FLOW_SCENE := preload(
	"res://UI/Business/WorkerSelection/WorkerAssignmentFlow.tscn"
)
const BUSINESS_MODAL_DATA_ADAPTER := preload(
	"res://Scripts/UI/Business/business_modal_data_adapter.gd"
)

var business_modal: Control = null
var active_flow: Control = null


func _ready() -> void:
	business_modal = get_parent()
	if business_modal == null:
		push_error("BusinessModalWorkerFlowConnector requires BusinessModal as its parent.")
		return

	if business_modal.has_signal("assign_requested"):
		business_modal.assign_requested.connect(_on_assign_requested)
	if business_modal.has_signal("replace_requested"):
		business_modal.replace_requested.connect(_on_replace_requested)
	if business_modal.has_signal("upgrade_requested"):
		business_modal.upgrade_requested.connect(_on_upgrade_requested)


func refresh_modal_from_manager(business_instance_id: String) -> bool:
	if business_modal == null or not business_modal.has_method("configure_from_data"):
		return false

	var presentation_data: Dictionary = BUSINESS_MODAL_DATA_ADAPTER.build(business_instance_id)
	if presentation_data.is_empty():
		return false

	business_modal.configure_from_data(presentation_data)
	return true


func _on_assign_requested(business_instance_id: String, slot_index: int) -> void:
	_open_assignment_flow(business_instance_id, slot_index, false)


func _on_replace_requested(business_instance_id: String, slot_index: int) -> void:
	_open_assignment_flow(business_instance_id, slot_index, true)


func _on_upgrade_requested(business_instance_id: String) -> void:
	if business_instance_id.is_empty():
		return
	if BusinessManager.upgrade_business(business_instance_id):
		refresh_modal_from_manager(business_instance_id)


func _open_assignment_flow(
	business_instance_id: String,
	slot_index: int,
	is_replace: bool
) -> void:
	if active_flow != null and is_instance_valid(active_flow):
		return
	active_flow = null

	var business: Dictionary = BusinessManager.get_business_by_instance_id(business_instance_id)
	if business.is_empty():
		push_warning("Business Modal worker flow could not find business: " + business_instance_id)
		return

	var slots_value = business.get("slots", [])
	if typeof(slots_value) != TYPE_ARRAY:
		return
	var slots: Array = slots_value
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot_value = slots[slot_index]
	if typeof(slot_value) != TYPE_DICTIONARY:
		return
	var slot: Dictionary = slot_value
	var slot_id := str(slot.get("slot_id", ""))
	var business_type_id := str(business.get("business_type_id", ""))
	if slot_id.is_empty() or business_type_id.is_empty():
		return

	var flow := WORKER_ASSIGNMENT_FLOW_SCENE.instantiate()
	active_flow = flow
	business_modal.add_child(flow)

	flow.assignment_completed.connect(_on_assignment_completed)
	flow.assignment_failed.connect(_on_assignment_failed)
	flow.cancelled.connect(_on_assignment_cancelled)
	flow.setup(business_instance_id, business_type_id, slot_id, is_replace)


func _on_assignment_completed(
	business_instance_id: String,
	_slot_id: String,
	_source_type: String,
	_candidate_id
) -> void:
	active_flow = null
	refresh_modal_from_manager(business_instance_id)


func _on_assignment_failed(source_type: String, candidate_id) -> void:
	push_warning(
		"Business Modal worker assignment failed | Source: %s | Candidate: %s"
		% [source_type, str(candidate_id)]
	)


func _on_assignment_cancelled() -> void:
	active_flow = null
