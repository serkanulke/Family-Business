extends RefCounted
class_name ItemCatalogGenerator


const SOURCE_ROOT := "res://Resources/Items"
const CATALOG_VERSION := 2
const LIFESTYLE_CENTER_SAMPLES := 3

const VALID_SLOTS: Array[String] = ["accessory", "outfit", "vehicle"]
const RARITY_ALIASES := {
	"common": "common",
	"uncommon": "uncommon",
	"rare": "rare",
	"epic": "epic",
	"legend": "legendary",
	"legendary": "legendary",
}
const LIFESTYLE_BANDS := {
	"common": Vector2i(1, 8),
	"uncommon": Vector2i(7, 14),
	"rare": Vector2i(13, 21),
	"epic": Vector2i(20, 28),
	"legendary": Vector2i(27, 34),
}
const DURABILITY_BANDS := {
	"common": {
		"accessory": Vector2i(18, 36),
		"outfit": Vector2i(12, 30),
		"vehicle": Vector2i(72, 120),
	},
	"uncommon": {
		"accessory": Vector2i(24, 48),
		"outfit": Vector2i(18, 36),
		"vehicle": Vector2i(96, 144),
	},
	"rare": {
		"accessory": Vector2i(36, 60),
		"outfit": Vector2i(24, 48),
		"vehicle": Vector2i(120, 180),
	},
	"epic": {
		"accessory": Vector2i(48, 84),
		"outfit": Vector2i(36, 60),
		"vehicle": Vector2i(156, 216),
	},
	"legendary": {
		"accessory": Vector2i(72, 120),
		"outfit": Vector2i(48, 84),
		"vehicle": Vector2i(192, 300),
	},
}
const SLOT_BASE_PRICES := {
	"accessory": 4000,
	"outfit": 8000,
	"vehicle": 40000,
}
const RARITY_MULTIPLIERS := {
	"common": 1.0,
	"uncommon": 1.5,
	"rare": 2.25,
	"epic": 3.5,
	"legendary": 5.5,
}
const MONEY_ROUNDING_STEPS := {
	"accessory": 50,
	"outfit": 50,
	"vehicle": 500,
}
const LEGENDARY_DIAMOND_RANGES := {
	"accessory": Vector2i(2, 4),
	"outfit": Vector2i(3, 5),
	"vehicle": Vector2i(5, 8),
}
const HEIRLOOM_DIAMOND_RANGES := {
	"accessory": Vector2i(12, 18),
	"outfit": Vector2i(18, 26),
	"vehicle": Vector2i(30, 45),
}


static func generate_catalog() -> Dictionary:
	var image_paths: Array[String] = []
	_collect_png_paths(SOURCE_ROOT, image_paths)
	image_paths.sort()
	var definitions: Array = []
	var used_ids: Dictionary = {}
	for image_path in image_paths:
		var source := _parse_source_path(image_path)
		if source.is_empty():
			push_warning("Item catalog skipped an unrecognized source path: " + image_path)
			continue
		var item_id := image_path.get_file().get_basename().to_lower()
		if used_ids.has(item_id):
			push_error("Item catalog contains a duplicate stable ID: " + item_id)
			continue
		used_ids[item_id] = true
		var slot := str(source["slot"])
		var rarity := str(source["rarity"])
		var is_heirloom := _filename_has_marker(item_id, "heirloom")
		var durability_months := 0
		if not is_heirloom:
			var band: Vector2i = DURABILITY_BANDS[rarity][slot]
			durability_months = _stable_uniform_int(item_id + ":durability", band.x, band.y)
		var lifestyle_band: Vector2i = LIFESTYLE_BANDS[rarity]
		var lifestyle_value := _stable_centered_int(
			item_id + ":lifestyle",
			lifestyle_band.x,
			lifestyle_band.y,
			LIFESTYLE_CENTER_SAMPLES
		)
		var prices := calculate_price_components(
			slot,
			rarity,
			lifestyle_value,
			durability_months,
			is_heirloom
		)
		definitions.append({
			"id": item_id,
			"display_name": _display_name_from_id(item_id),
			"slot": slot,
			"rarity": rarity,
			"image_path": image_path,
			"is_heirloom": is_heirloom,
			"lifestyle_value": lifestyle_value,
			"durability_months": durability_months,
			"money_price": int(prices["money_price"]),
			"diamond_price": int(prices["diamond_price"]),
		})
	return {
		"catalog_version": CATALOG_VERSION,
		"source_root": SOURCE_ROOT,
		"pricing_status": "configured_gdd_v3_4",
		"items": definitions,
	}


static func calculate_price_components(
	slot: String,
	rarity: String,
	lifestyle_value: int,
	durability_months: int,
	is_heirloom: bool
) -> Dictionary:
	var normalized_slot := slot.strip_edges().to_lower()
	var normalized_rarity := rarity.strip_edges().to_lower()
	if normalized_slot not in VALID_SLOTS or not LIFESTYLE_BANDS.has(normalized_rarity):
		return {}
	var lifestyle_band: Vector2i = LIFESTYLE_BANDS[normalized_rarity]
	var lifestyle_normalized := _normalize_range(
		float(lifestyle_value),
		float(lifestyle_band.x),
		float(lifestyle_band.y)
	)
	var lifestyle_multiplier := lerpf(1.0, 1.2, lifestyle_normalized)
	var rarity_multiplier := float(RARITY_MULTIPLIERS[normalized_rarity])
	var base_price := int(SLOT_BASE_PRICES[normalized_slot])
	var lifespan_multiplier := 1.0
	if not is_heirloom:
		var lifespan_band: Vector2i = DURABILITY_BANDS[normalized_rarity][normalized_slot]
		var lifespan_normalized := _normalize_range(
			float(durability_months),
			float(lifespan_band.x),
			float(lifespan_band.y)
		)
		lifespan_multiplier = lerpf(1.0, 1.15, lifespan_normalized)
	var raw_money := 0.0
	var rounded_money := 0
	var diamond_price := 0
	if is_heirloom:
		var heirloom_range: Vector2i = HEIRLOOM_DIAMOND_RANGES[normalized_slot]
		var heirloom_normalized := _normalize_range(float(lifestyle_value), 1.0, 34.0)
		diamond_price = clampi(
			roundi(lerpf(float(heirloom_range.x), float(heirloom_range.y), heirloom_normalized)),
			heirloom_range.x,
			heirloom_range.y
		)
	else:
		raw_money = (
			float(base_price)
			* rarity_multiplier
			* lifestyle_multiplier
			* lifespan_multiplier
		)
		rounded_money = _round_to_step(raw_money, int(MONEY_ROUNDING_STEPS[normalized_slot]))
		if normalized_rarity == "legendary":
			var legendary_range: Vector2i = LEGENDARY_DIAMOND_RANGES[normalized_slot]
			var legendary_normalized := _normalize_range(float(lifestyle_value), 27.0, 34.0)
			diamond_price = clampi(
				roundi(lerpf(float(legendary_range.x), float(legendary_range.y), legendary_normalized)),
				legendary_range.x,
				legendary_range.y
			)
	return {
		"base_price": base_price,
		"rarity_multiplier": rarity_multiplier,
		"lifestyle_multiplier": lifestyle_multiplier,
		"lifespan_multiplier": lifespan_multiplier,
		"raw_money": raw_money,
		"rounded_money": rounded_money,
		"money_price": 0 if is_heirloom else rounded_money,
		"diamond_price": diamond_price,
	}


static func _normalize_range(value: float, minimum: float, maximum: float) -> float:
	if maximum <= minimum:
		return 0.0
	return clampf((value - minimum) / (maximum - minimum), 0.0, 1.0)


static func _round_to_step(value: float, step: int) -> int:
	if step <= 0:
		return roundi(value)
	return roundi(value / float(step)) * step


static func _collect_png_paths(directory_path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("Item catalog source directory could not be opened: " + directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child_path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_png_paths(child_path, result)
			elif entry.get_extension().to_lower() == "png":
				result.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _parse_source_path(image_path: String) -> Dictionary:
	var normalized := image_path.replace("\\", "/")
	var prefix := SOURCE_ROOT + "/"
	if not normalized.begins_with(prefix):
		return {}
	var parts := normalized.trim_prefix(prefix).split("/")
	if parts.size() < 3:
		return {}
	var slot := str(parts[0]).to_lower()
	if slot not in VALID_SLOTS:
		return {}
	var rarity := ""
	for index in range(1, parts.size() - 1):
		var folder := str(parts[index]).to_lower()
		if RARITY_ALIASES.has(folder):
			rarity = str(RARITY_ALIASES[folder])
			break
	if rarity.is_empty():
		return {}
	return {"slot": slot, "rarity": rarity}


static func _display_name_from_id(item_id: String) -> String:
	var tokens := item_id.split("_")
	var display_tokens: Array[String] = []
	for index in range(tokens.size()):
		var token := str(tokens[index]).to_lower()
		if index == 0 and token in VALID_SLOTS:
			continue
		if RARITY_ALIASES.has(token) or token == "heirloom":
			continue
		if index == tokens.size() - 1 and token.is_valid_int():
			continue
		display_tokens.append(token.capitalize())
	return " ".join(display_tokens)


static func _filename_has_marker(item_id: String, marker: String) -> bool:
	return marker.to_lower() in item_id.to_lower().split("_")


static func _stable_centered_int(key: String, minimum: int, maximum: int, samples: int) -> int:
	var total := 0
	var safe_samples := maxi(samples, 1)
	for sample_index in range(safe_samples):
		total += _stable_uniform_int(
			"%s:%d" % [key, sample_index],
			minimum,
			maximum
		)
	return clampi(roundi(float(total) / float(safe_samples)), minimum, maximum)


static func _stable_uniform_int(key: String, minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	return minimum + (_stable_hash(key) % (maximum - minimum + 1))


static func _stable_hash(text: String) -> int:
	var value: int = 2166136261
	for index in range(text.length()):
		value = value ^ text.unicode_at(index)
		value = int((value * 16777619) & 0x7fffffff)
	return value
