extends Control

signal linked_character_pressed(character_id: int)

const LINK_ICON_PATH := "res://Resources/Icons/character-portrait/link-icon.svg"
const ICON_SIZE := Vector2(44.0, 44.0)

class SoftTextureShadow:
	extends Control
	var shadow_texture: Texture2D
	var target_size: Vector2 = Vector2.ZERO
	var blur_radius: float = 10.0
	var shadow_offset: Vector2 = Vector2(-4.0, 4.0)
	var shadow_opacity: float = 0.25

	func configure(
		new_texture: Texture2D,
		new_size: Vector2,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		shadow_texture = new_texture
		target_size = new_size
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = target_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if shadow_texture == null:
			return

		var ring_count: int = maxi(2, int(ceil(blur_radius / 2.0)))
		var samples_per_ring: int = 12
		var sample_count: int = 1 + ring_count * samples_per_ring
		var sample_alpha: float = shadow_opacity / float(sample_count)
		var tint := Color(0.0, 0.0, 0.0, sample_alpha)

		draw_texture_rect(
			shadow_texture,
			Rect2(shadow_offset, target_size),
			false,
			tint
		)

		for ring_index in range(1, ring_count + 1):
			var radius: float = blur_radius * float(ring_index) / float(ring_count)
			for sample_index in range(samples_per_ring):
				var angle: float = TAU * float(sample_index) / float(samples_per_ring)
				var sample_offset := shadow_offset + Vector2(cos(angle), sin(angle)) * radius
				draw_texture_rect(
					shadow_texture,
					Rect2(sample_offset, target_size),
					false,
					tint
				)

@onready var hit_button: TextureButton = $HitButton

var linked_character_id: int = 0


func _ready() -> void:
	var link_texture := load(LINK_ICON_PATH) as Texture2D

	var shadow := SoftTextureShadow.new()
	shadow.position = Vector2.ZERO
	shadow.configure(
		link_texture,
		ICON_SIZE,
		Vector2(-4.0, 4.0),
		10.0,
		0.25
	)
	add_child(shadow)
	move_child(shadow, 0)

	hit_button.texture_normal = link_texture
	hit_button.texture_pressed = link_texture
	hit_button.texture_hover = link_texture
	hit_button.texture_disabled = link_texture

	if not hit_button.pressed.is_connected(_on_hit_button_pressed):
		hit_button.pressed.connect(_on_hit_button_pressed)


func setup_linked_character(character_id: int) -> void:
	linked_character_id = character_id


func _on_hit_button_pressed() -> void:
	if linked_character_id <= 0:
		return

	linked_character_pressed.emit(linked_character_id)
