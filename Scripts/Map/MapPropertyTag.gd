extends PanelContainer
class_name MapPropertyTag

@onready var title_label: Label = $Margin/Rows/Title
@onready var state_label: Label = $Margin/Rows/State


func configure(title: String, state_text: String, should_show: bool = true) -> void:
	title_label.text = title
	state_label.text = state_text
	visible = should_show


func set_tag_scale(value: float) -> void:
	scale = Vector2.ONE * maxf(value, 0.1)
