extends Control


signal source_selected(source_type: String)
signal cancelled


const SOURCE_FAMILY := "family"
const SOURCE_NPC := "npc"


@onready var family_button: Button = %FamilyButton
@onready var npc_button: Button = %NPCButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	family_button.pressed.connect(
		_on_family_pressed
	)

	npc_button.pressed.connect(
		_on_npc_pressed
	)

	close_button.pressed.connect(
		_on_close_pressed
	)


func _on_family_pressed() -> void:
	source_selected.emit(
		SOURCE_FAMILY
	)


func _on_npc_pressed() -> void:
	source_selected.emit(
		SOURCE_NPC
	)


func _on_close_pressed() -> void:
	cancelled.emit()
	queue_free()
