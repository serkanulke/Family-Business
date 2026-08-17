@tool
extends PanelContainer

signal load_requested(save_id: int)

# Legacy scene property. The three old design-preview cards are removed
# by LoadGameScreen at runtime, so this value is no longer save identity.
@export var slot_index: int = 0

@export var family_name: String = "Williams Family":
	set(value):
		family_name = value
		_sync_visuals()

@export var wealth_text: String = "240k":
	set(value):
		wealth_text = value
		_sync_visuals()

@export var population_text: String = "10":
	set(value):
		population_text = value
		_sync_visuals()

@export var owned_businesses_text: String = "1":
	set(value):
		owned_businesses_text = value
		_sync_visuals()

var save_id: int = -1


func _ready() -> void:
	_sync_visuals()


func apply_save_summary(
	summary: Dictionary
) -> void:
	save_id = int(
		summary.get(
			"save_id",
			-1
		)
	)

	family_name = _format_family_name(
		String(
			summary.get(
				"family_name",
				""
			)
		)
	)

	wealth_text = _format_compact_amount(
		int(
			summary.get(
				"wealth",
				0
			)
		)
	)

	population_text = str(
		maxi(
			int(
				summary.get(
					"population",
					0
				)
			),
			0
		)
	)

	owned_businesses_text = str(
		maxi(
			int(
				summary.get(
					"owned_businesses",
					0
				)
			),
			0
		)
	)


func _sync_visuals() -> void:
	if not is_inside_tree():
		return

	var family_label := get_node_or_null(
		"Padding/Content/Info/FamilyName"
	) as Label
	var wealth_value := get_node_or_null(
		"Padding/Content/Info/Metrics/WealthRow/Value"
	) as Label
	var population_value := get_node_or_null(
		"Padding/Content/Info/Metrics/PopulationRow/Value"
	) as Label
	var businesses_value := get_node_or_null(
		"Padding/Content/Info/Metrics/BusinessesRow/Value"
	) as Label

	if family_label != null:
		family_label.text = family_name

	if wealth_value != null:
		wealth_value.text = wealth_text

	if population_value != null:
		population_value.text = population_text

	if businesses_value != null:
		businesses_value.text = owned_businesses_text


func _format_family_name(
	value: String
) -> String:
	var cleaned_name := value.strip_edges()

	if cleaned_name.is_empty():
		return "Family"

	if cleaned_name.to_lower().ends_with(
		" family"
	):
		return cleaned_name

	return cleaned_name + " Family"


func _format_compact_amount(
	amount: int
) -> String:
	var safe_amount := maxi(
		amount,
		0
	)

	if safe_amount >= 1000000:
		var millions := (
			float(safe_amount)
			/ 1000000.0
		)
		return (
			_format_short_decimal(millions)
			+ "M"
		)

	if safe_amount >= 1000:
		var thousands := (
			float(safe_amount)
			/ 1000.0
		)
		return (
			_format_short_decimal(thousands)
			+ "k"
		)

	return str(
		safe_amount
	)


func _format_short_decimal(
	value: float
) -> String:
	if is_equal_approx(
		value,
		round(value)
	):
		return str(
			int(
				round(value)
			)
		)

	return "%.1f" % value


func _on_load_button_pressed() -> void:
	if save_id <= 0:
		return

	load_requested.emit(
		save_id
	)
