extends Control

@onready var date_label = $DateLabel


func _ready():
	date_label.text = TimeManager.get_date_string()
	TimeManager.date_changed.connect(_on_date_changed)


func _on_date_changed(date_text: String):
	date_label.text = date_text
