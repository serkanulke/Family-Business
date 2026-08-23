extends RefCounted
class_name AccessoryCategoryClassifier


const CATEGORY_ALL := "all"
const CATEGORY_RING := "ring"
const CATEGORY_GLASSES := "glasses"
const CATEGORY_WATCH := "watch"
const CATEGORY_NECKLACE := "necklace"
const CATEGORIES: Array[String] = [
	CATEGORY_ALL,
	CATEGORY_RING,
	CATEGORY_GLASSES,
	CATEGORY_WATCH,
	CATEGORY_NECKLACE,
]


static func classify(item: Dictionary) -> String:
	var searchable_parts: Array[String] = [
		str(item.get("image_path", "")),
		str(item.get("item_id", "")),
		str(item.get("display_name", "")),
	]
	var searchable := " ".join(searchable_parts).to_lower()
	searchable = searchable.replace("-", "_").replace(" ", "_")
	for category in CATEGORIES:
		if category == CATEGORY_ALL:
			continue
		if ("_%s_" % category) in ("_" + searchable + "_"):
			return category
		if ("/%s/" % category) in searchable.replace("\\", "/"):
			return category
	return ""


static func matches(item: Dictionary, filter_key: String) -> bool:
	var normalized := filter_key.strip_edges().to_lower()
	return normalized == CATEGORY_ALL or classify(item) == normalized

