extends Node


signal lifespan_setting_changed(value: String)


const VALID_LIFESPAN_SETTINGS: Array[String] = [
	"short",
	"normal",
	"long"
]


# Varsayılan değer henüz GDD'de kararlaştırılmadığı için boş bırakılıyor.
var lifespan_setting: String = ""


func set_lifespan_setting(value: String) -> void:
	var normalized_value := value.strip_edges().to_lower()

	if not VALID_LIFESPAN_SETTINGS.has(normalized_value):
		push_error(
			"Invalid lifespan setting: "
			+ value
		)
		return

	if lifespan_setting == normalized_value:
		return

	lifespan_setting = normalized_value
	lifespan_setting_changed.emit(lifespan_setting)

	print(
		"Lifespan setting changed: ",
		lifespan_setting
	)

func has_lifespan_setting() -> bool:
	return not lifespan_setting.is_empty()
