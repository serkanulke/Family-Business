extends RefCounted
class_name MapDataValidator

const APPROVED_BUSINESS_COUNTS := {
	"cafe": [4, 5],
	"gym": [4, 5],
	"restaurant": [4, 5],
	"warehouse": [4, 5],
	"factory": [4, 5],
	"hospital": [4, 5],
	"tech_company": [4, 5],
	"bank": [4, 5],
	"stadium": [1, 1],
	"auto_service": [4, 5],
	"cruise": [1, 1],
	"hotel": [4, 5]
}

const EXPECTED_FOOTPRINTS := {
	"house": Vector2i(2, 2),
	"cafe": Vector2i(2, 2),
	"bank": Vector2i(2, 2),
	"gym": Vector2i(2, 2),
	"restaurant": Vector2i(2, 2),
	"auto_service": Vector2i(2, 2),
	"hotel": Vector2i(3, 2),
	"tech_company": Vector2i(3, 2),
	"skyscraper": Vector2i(3, 2),
	"hospital": Vector2i(3, 3),
	"school": Vector2i(3, 3),
	"warehouse": Vector2i(4, 3),
	"factory": Vector2i(4, 4),
	"stadium": Vector2i(4, 4),
	"cruise": Vector2i(1, 3),
	"land_2x2": Vector2i(2, 2),
	"land_4x4": Vector2i(4, 4)
}


static func validate(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var counts := {
		"businesses": {},
		"houses_total": 0,
		"houses_purchasable": 0,
		"land_2x2": 0,
		"land_4x4": 0,
		"city_decor": 0
	}
	_validate_projection(data, errors)
	_validate_properties(data, errors, counts)
	_validate_bicycle_paths(data, errors)
	_validate_asset_references(data, errors)
	return {"valid": errors.is_empty(), "errors": errors, "counts": counts}


static func _validate_projection(data: Dictionary, errors: Array[String]) -> void:
	var projection_value = data.get("projection", {})
	var projection: Dictionary = projection_value if projection_value is Dictionary else {}
	var main_size := _array_to_vector2i(projection.get("main_tile_size", []))
	var detail_size := _array_to_vector2i(projection.get("detail_tile_size", []))
	if main_size != Vector2i(200, 100):
		errors.append("Main tile size must be exactly 200x100.")
	if detail_size != Vector2i(50, 25):
		errors.append("Detail tile size must be exactly 50x25.")
	if int(projection.get("detail_subdivision", 0)) != 4:
		errors.append("Detail grid must be a 4x4 subdivision.")
	for sample in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(7, 13), Vector2i(48, 48)]:
		if not MapCoordinateHelper.arrays_align_exactly(sample):
			errors.append("Main/detail grid origins or axes do not align.")
			break


static func _validate_properties(
	data: Dictionary,
	errors: Array[String],
	counts: Dictionary
) -> void:
	var properties_value = data.get("properties", [])
	var properties: Array = properties_value if properties_value is Array else []
	var property_ids: Dictionary = {}
	var business_instance_ids: Dictionary = {}
	var occupied_cells: Dictionary = {}
	for property_value in properties:
		if not property_value is Dictionary:
			errors.append("Every property entry must be a dictionary.")
			continue
		var property: Dictionary = property_value
		var property_id := str(property.get("id", ""))
		if property_id.is_empty() or property_ids.has(property_id):
			errors.append("Property IDs must be non-empty and unique: " + property_id)
		else:
			property_ids[property_id] = true
		var category := str(property.get("category", ""))
		var visual_type := str(property.get("visual_type", ""))
		if visual_type in ["city_hall", "bookshop"]:
			errors.append("Removed city content is present: " + visual_type)
		var position := _array_to_vector2i(property.get("grid_position", []))
		var footprint := _array_to_vector2i(property.get("footprint", []))
		if footprint.x <= 0 or footprint.y <= 0:
			errors.append("Property footprint must be positive: " + property_id)
			continue
		if EXPECTED_FOOTPRINTS.has(visual_type) and footprint != EXPECTED_FOOTPRINTS[visual_type]:
			errors.append("Invalid footprint for %s: %s" % [property_id, str(footprint)])
		_validate_property_semantics(property, property_id, category, visual_type, errors)
		var instance_id_value = property.get("business_instance_id", null)
		if instance_id_value != null and not str(instance_id_value).is_empty():
			var instance_id := str(instance_id_value)
			if business_instance_ids.has(instance_id):
				errors.append("Duplicate static business_instance_id: " + instance_id)
			else:
				business_instance_ids[instance_id] = true
		for x in range(position.x, position.x + footprint.x):
			for y in range(position.y, position.y + footprint.y):
				var cell := Vector2i(x, y)
				if occupied_cells.has(cell):
					errors.append(
						"Property footprints overlap: %s and %s at %s"
						% [str(occupied_cells[cell]), property_id, str(cell)]
					)
				else:
					occupied_cells[cell] = property_id
		_count_property(property, category, counts)

	var business_counts: Dictionary = counts["businesses"]
	for business_type_id in APPROVED_BUSINESS_COUNTS:
		var limits: Array = APPROVED_BUSINESS_COUNTS[business_type_id]
		var count := int(business_counts.get(business_type_id, 0))
		if count < int(limits[0]) or count > int(limits[1]):
			errors.append("Invalid %s count: %d" % [business_type_id, count])
	for found_type in business_counts:
		if not APPROVED_BUSINESS_COUNTS.has(found_type):
			errors.append("Unapproved family-business type: " + str(found_type))
	if int(counts["houses_total"]) < 20 or int(counts["houses_total"]) > 30:
		errors.append("House count must remain within 20-30.")
	if int(counts["houses_purchasable"]) != 10:
		errors.append("Exactly 10 houses must be purchasable.")
	if int(counts["land_2x2"]) != 3 or int(counts["land_4x4"]) != 3:
		errors.append("Map must contain exactly three plots of each land size.")


static func _validate_property_semantics(
	property: Dictionary,
	property_id: String,
	category: String,
	visual_type: String,
	errors: Array[String]
) -> void:
	var purchasable := bool(property.get("purchasable", false))
	var tag_visible := bool(property.get("tag_visibility", false))
	var ground_type := str(property.get("ground_type", ""))
	if category == "family_business":
		if not purchasable or not tag_visible:
			errors.append("Family-business property must be purchasable and tagged: " + property_id)
		var expected_ground := "sea" if visual_type == "cruise" else "asphalt"
		if ground_type != expected_ground:
			errors.append("Invalid family-business ground for " + property_id)
	elif category == "house":
		if ground_type != "grass":
			errors.append("House ground must be grass: " + property_id)
		if tag_visible != purchasable:
			errors.append("Only purchasable houses may show tags: " + property_id)
	elif category == "land":
		if not purchasable or not tag_visible or ground_type != "grass":
			errors.append("Buildable land must be purchasable, tagged, and grass: " + property_id)
	elif category == "city_decor":
		if purchasable or tag_visible:
			errors.append("City decor must be non-purchasable and untagged: " + property_id)
		if visual_type not in ["school", "skyscraper"]:
			errors.append("Unapproved city decor type: " + visual_type)
	else:
		errors.append("Unknown property category: " + category)


static func _count_property(property: Dictionary, category: String, counts: Dictionary) -> void:
	if category == "family_business":
		var type_id := str(property.get("business_type_id", ""))
		var business_counts: Dictionary = counts["businesses"]
		business_counts[type_id] = int(business_counts.get(type_id, 0)) + 1
	elif category == "house":
		counts["houses_total"] = int(counts["houses_total"]) + 1
		if bool(property.get("purchasable", false)):
			counts["houses_purchasable"] = int(counts["houses_purchasable"]) + 1
	elif category == "land":
		var plot_type := str(property.get("land_plot_type", ""))
		if plot_type == "2x2":
			counts["land_2x2"] = int(counts["land_2x2"]) + 1
		elif plot_type == "4x4":
			counts["land_4x4"] = int(counts["land_4x4"]) + 1
	elif category == "city_decor":
		counts["city_decor"] = int(counts["city_decor"]) + 1


static func _validate_bicycle_paths(data: Dictionary, errors: Array[String]) -> void:
	var road_cells: Dictionary = {}
	for segment_value in data.get("road_segments", []):
		if not segment_value is Dictionary:
			continue
		for cell in expand_segment(segment_value):
			road_cells[cell] = true
	for override_value in data.get("road_overrides", []):
		if override_value is Dictionary:
			road_cells[_array_to_vector2i(override_value.get("cell", []))] = true
	for segment_value in data.get("detail_segments", []):
		if not segment_value is Dictionary:
			continue
		var segment: Dictionary = segment_value
		if str(segment.get("kind", "")) != "bicycle":
			continue
		for detail_cell in expand_segment(segment):
			var main_cell := MapCoordinateHelper.detail_to_main(detail_cell)
			if road_cells.has(main_cell):
				errors.append("Bicycle path overlaps vehicle road at " + str(main_cell))


static func _validate_asset_references(data: Dictionary, errors: Array[String]) -> void:
	for collection_name in [
		"ground_regions", "coast_regions", "road_segments", "road_overrides", "detail_segments"
	]:
		for entry_value in data.get(collection_name, []):
			if entry_value is Dictionary:
				_validate_asset_path(str(entry_value.get("asset", "")), collection_name, errors)
	for property_value in data.get("properties", []):
		if property_value is Dictionary:
			_validate_asset_path(
				str(property_value.get("visual_path", "")),
				str(property_value.get("id", "property")),
				errors
			)
	for decoration_value in data.get("decorations", []):
		if decoration_value is Dictionary:
			_validate_asset_path(
				str(decoration_value.get("visual_path", "")),
				str(decoration_value.get("id", "decoration")),
				errors
			)


static func _validate_asset_path(path: String, context: String, errors: Array[String]) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		errors.append("Missing existing asset reference for %s: %s" % [context, path])


static func expand_segment(segment: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var axis := str(segment.get("axis", "x"))
	var fixed := int(segment.get("fixed", 0))
	var start := int(segment.get("from", 0))
	var finish := int(segment.get("to", start))
	var step := 1 if finish >= start else -1
	for value in range(start, finish + step, step):
		result.append(Vector2i(fixed, value) if axis == "x" else Vector2i(value, fixed))
	return result


static func land_accepts_footprint(plot_type: String, footprint: Vector2i, is_cruise: bool = false) -> bool:
	if is_cruise:
		return false
	var capacity := Vector2i(2, 2) if plot_type == "2x2" else Vector2i(4, 4)
	return footprint.x <= capacity.x and footprint.y <= capacity.y


static func _array_to_vector2i(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
