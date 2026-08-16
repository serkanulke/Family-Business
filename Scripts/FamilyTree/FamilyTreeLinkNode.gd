extends Control

signal linked_character_pressed(
	character_id: int
)

@onready var hit_button: TextureButton = $HitButton

var linked_character_id: int = 0


func _ready() -> void:
	hit_button.pressed.connect(
		_on_hit_button_pressed
	)


func setup_linked_character(
	character_id: int
) -> void:
	linked_character_id = character_id


func _on_hit_button_pressed() -> void:
	if linked_character_id <= 0:
		return

	linked_character_pressed.emit(
		linked_character_id
	)
