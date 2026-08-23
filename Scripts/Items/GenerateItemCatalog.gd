extends SceneTree


const OUTPUT_PATH := "res://Resources/Json/ItemCatalog.json"
const GENERATOR := preload("res://Scripts/Items/ItemCatalogGenerator.gd")


func _initialize() -> void:
	var catalog: Dictionary = GENERATOR.generate_catalog()
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Generated Item Catalog could not be written: " + OUTPUT_PATH)
		quit(1)
		return
	output.store_string(JSON.stringify(catalog, "\t") + "\n")
	output.close()
	print("Generated %d stable item definitions at %s" % [
		(catalog.get("items", []) as Array).size(),
		OUTPUT_PATH,
	])
	quit(0)
