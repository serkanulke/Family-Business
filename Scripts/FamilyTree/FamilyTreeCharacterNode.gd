extends Control

signal character_pressed(
	character_id: int
)

const PORTRAIT_CENTER := Vector2(
	90.0,
	72.0
)

const PORTRAIT_BACKGROUND_RADIUS := 66.0

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $NameLabel
@onready var info_label: Label = $InfoLabel
@onready var hit_button: Button = $HitButton

var character_id: int = 0
var is_alive: bool = true


func _ready() -> void:
	hit_button.pressed.connect(
		_on_hit_button_pressed
	)


func setup_character(
	character: Dictionary
) -> void:
	character_id = int(
		character.get(
			"character_id",
			0
		)
	)

	is_alive = bool(
		character.get(
			"is_alive",
			true
		)
	)

	name_label.text = String(
		character.get(
			"first_name",
			""
		)
	)

	var age: int = CharacterManager.get_character_age(
		character
	)

	var life_stage: String = String(
		character.get(
			"life_stage",
			""
		)
	)

	var readable_stage: String = (
		life_stage
		.replace(
			"_",
			" "
		)
		.capitalize()
	)

	if age >= 0:
		info_label.text = (
			str(
				age
			)
			+ " • "
			+ readable_stage
		)
	else:
		info_label.text = readable_stage

	var avatar_texture: Texture2D = (
		CharacterManager.get_avatar_texture(
			character
		)
	)

	portrait.texture = avatar_texture

	var alive_alpha: float = (
		1.0
		if is_alive
		else 0.42
	)

	portrait.modulate.a = alive_alpha
	name_label.modulate.a = alive_alpha
	info_label.modulate.a = alive_alpha

	queue_redraw()


func _draw() -> void:
	draw_circle(
		PORTRAIT_CENTER,
		PORTRAIT_BACKGROUND_RADIUS,
		Color(
			0.96,
			0.96,
			0.97,
			1.0
		)
	)

	draw_arc(
		PORTRAIT_CENTER,
		PORTRAIT_BACKGROUND_RADIUS,
		0.0,
		TAU,
		64,
		Color(
			0.78,
			0.79,
			0.82,
			1.0
		),
		2.0,
		true
	)


func _on_hit_button_pressed() -> void:
	character_pressed.emit(
		character_id
	)
