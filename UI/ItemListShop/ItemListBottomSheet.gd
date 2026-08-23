extends CanvasLayer
class_name ItemListBottomSheet


signal sheet_opened(character_id: int, slot_context: String)
signal sheet_closed(character_id: int, slot_context: String)
signal item_buy_requested(character_id: int, catalog_item_id: Variant, slot_context: String)
signal item_wear_requested(character_id: int, item_instance_id: Variant, slot_context: String)
signal item_unequip_requested(character_id: int, item_instance_id: Variant, slot_context: String)


class DashedEmptyState:
	extends Control

	var border_color := Color("#E4CDB3")
	var icon_color := Color("#DCC4AB")
	var corner_radius := 24.0
	var icon_path := ""
	var icon: TextureRect

	func setup(new_icon_path: String) -> void:
		icon_path = new_icon_path
		custom_minimum_size = Vector2(488.0, 655.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon = TextureRect.new()
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path) as Texture2D
		icon.custom_minimum_size = Vector2(42.0, 42.0)
		icon.size = Vector2(42.0, 42.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.material = _make_icon_tint_material(icon_color)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		resized.connect(_layout_icon)
		call_deferred("_layout_icon")

	func _layout_icon() -> void:
		if icon != null:
			icon.position = (size - icon.size) * 0.5

	func _draw() -> void:
		var inset := 2.0
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
		_draw_dashed_path(_rounded_rect_points(rect, corner_radius), 14.0, 10.0)

	func _rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var left := rect.position.x
		var top := rect.position.y
		var right := rect.end.x
		var bottom := rect.end.y
		points.append(Vector2(left + radius, top))
		points.append(Vector2(right - radius, top))
		_append_arc(points, Vector2(right - radius, top + radius), -PI * 0.5, 0.0)
		points.append(Vector2(right, bottom - radius))
		_append_arc(points, Vector2(right - radius, bottom - radius), 0.0, PI * 0.5)
		points.append(Vector2(left + radius, bottom))
		_append_arc(points, Vector2(left + radius, bottom - radius), PI * 0.5, PI)
		points.append(Vector2(left, top + radius))
		_append_arc(points, Vector2(left + radius, top + radius), PI, PI * 1.5)
		return points

	func _append_arc(points: PackedVector2Array, center: Vector2, start_angle: float, end_angle: float) -> void:
		for step in range(1, 9):
			var angle := lerpf(start_angle, end_angle, float(step) / 8.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)

	func _draw_dashed_path(points: PackedVector2Array, dash_length: float, gap_length: float) -> void:
		var drawing := true
		var pattern_position := 0.0
		for index in range(points.size() - 1):
			var segment_start := points[index]
			var segment_end := points[index + 1]
			var segment_vector := segment_end - segment_start
			var segment_length := segment_vector.length()
			if segment_length <= 0.0:
				continue
			var direction := segment_vector / segment_length
			var consumed := 0.0
			while consumed < segment_length:
				var pattern_length := dash_length if drawing else gap_length
				var step_length := minf(pattern_length - pattern_position, segment_length - consumed)
				if drawing:
					draw_line(
						segment_start + direction * consumed,
						segment_start + direction * (consumed + step_length),
						border_color,
						4.0,
						true
					)
				consumed += step_length
				pattern_position += step_length
				if pattern_position >= pattern_length - 0.001:
					pattern_position = 0.0
					drawing = not drawing

	func _make_icon_tint_material(tint_color: Color) -> ShaderMaterial:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nuniform vec4 tint_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 source = texture(TEXTURE, UV);\n\tCOLOR = vec4(tint_color.rgb, source.a * tint_color.a);\n}\n"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint_color", tint_color)
		return material


const ITEM_CARD_SCENE := preload("res://UI/ItemListShop/Components/ItemCard.tscn")
const INFO_PANEL_SCENE := preload("res://UI/ItemListShop/Components/ItemInfoPanel.tscn")
const FILTER_BAR_SCENE := preload("res://UI/ItemListShop/Components/ItemFilterBar.tscn")

const CANVAS_SIZE := Vector2(1080.0, 1920.0)
const SHEET_TOP := 320.0
const SHEET_TOP_RATIO := SHEET_TOP / CANVAS_SIZE.y
const DIM_OPACITY := 0.76
const CONTENT_WIDTH := 1000.0
const CARD_WIDTH := 488.0
const GRID_GAP := 24
const INITIAL_OWNED_COUNT := 2
const INITIAL_SHOP_COUNT := 4

const ICON_FOLDER := "res://Resources/Icons/item-list-shop/"
const CURRENCY_FOLDER := "res://Resources/Icons/main-ui/"
const FONT_REGULAR := "res://Resources/Fonts/Roboto-Regular.ttf"
const FONT_BOLD := "res://Resources/Fonts/Roboto-Bold.ttf"
const FONT_EXTRA_BOLD := "res://Resources/Fonts/Roboto-ExtraBold.ttf"

const COLOR_SHEET := Color("#FFF2DE")
const COLOR_PANEL := Color("#FFF9F4")
const COLOR_BORDER := Color("#F0DED2")
const COLOR_HANDLE := Color("#DCC4AB")
const COLOR_TEXT := Color("#1E1E1E")
const COLOR_BROWN := Color("#6D4534")

@export var item_list_shop_theme: Theme

var target_character_id: int = 0
var slot_context := ""
var data_provider: Object
var source_equipped_by_slot: Dictionary = {}
var source_owned_items: Array = []
var source_shop_items: Array = []
var unavailable_owned_instance_ids: Dictionary = {}
var equipped_item: Dictionary = {}
var owned_items: Array = []
var shop_items: Array = []
var selected_filter := "all"
var owned_expanded := false
var shop_expanded := false
var preview_data_enabled := false

var modal_root: Control
var dim_background: ColorRect
var sheet_panel: PanelContainer
var scroll_container: ScrollContainer
var content: VBoxContainer
var diamond_balance_label: Label
var money_balance_label: Label
var equipped_body: HBoxContainer
var owned_filter_bar: ItemFilterBar
var shop_filter_bar: ItemFilterBar
var owned_grid: GridContainer
var shop_grid: GridContainer
var owned_expand_button: Button
var shop_expand_button: Button


func _ready() -> void:
	_build_interface()
	set_process_unhandled_input(true)


func open_for_character(character_id: int, requested_slot: String) -> bool:
	var normalized_slot := requested_slot.strip_edges().to_lower()
	if character_id <= 0:
		push_error("ItemListBottomSheet requires a valid character ID.")
		return false
	if normalized_slot not in ["accessory", "outfit", "vehicle"]:
		push_error("ItemListBottomSheet received an unknown slot: " + requested_slot)
		return false
	target_character_id = character_id
	slot_context = normalized_slot
	selected_filter = "all"
	owned_expanded = false
	shop_expanded = false
	if data_provider != null:
		_bind_from_provider()
	elif not preview_data_enabled:
		source_equipped_by_slot.clear()
		source_owned_items.clear()
		source_shop_items.clear()
		unavailable_owned_instance_ids.clear()
	_apply_slot_scope()
	_refresh_balance()
	_rebuild_sections()
	if scroll_container != null:
		scroll_container.scroll_vertical = 0
	visible = true
	sheet_opened.emit(target_character_id, slot_context)
	return true


func close_sheet() -> void:
	if not visible:
		return
	var closing_character_id := target_character_id
	var closing_slot := slot_context
	visible = false
	target_character_id = 0
	slot_context = ""
	selected_filter = "all"
	owned_expanded = false
	shop_expanded = false
	sheet_closed.emit(closing_character_id, closing_slot)


func set_data_provider(provider: Object) -> void:
	data_provider = provider
	preview_data_enabled = false
	refresh_data()


func refresh_data() -> void:
	if not visible or slot_context.is_empty():
		return
	if data_provider != null:
		_bind_from_provider()
	_apply_slot_scope()
	_refresh_balance()
	_rebuild_sections()


func set_bound_data(equipped_by_slot: Dictionary, new_owned_items: Array, new_shop_items: Array) -> void:
	data_provider = null
	source_equipped_by_slot = equipped_by_slot.duplicate(true)
	source_owned_items = new_owned_items.duplicate(true)
	source_shop_items = new_shop_items.duplicate(true)
	_rebuild_unavailable_owned_instance_ids()
	preview_data_enabled = false
	if not slot_context.is_empty():
		_apply_slot_scope()
		_rebuild_sections()


func set_preview_data(equipped_by_slot: Dictionary, new_owned_items: Array, new_shop_items: Array) -> void:
	# Tests and visual capture may use this explicit preview-only surface. Production
	# opening never manufactures item definitions, inventory, or shop stock.
	data_provider = null
	source_equipped_by_slot = equipped_by_slot.duplicate(true)
	source_owned_items = new_owned_items.duplicate(true)
	source_shop_items = new_shop_items.duplicate(true)
	_rebuild_unavailable_owned_instance_ids()
	preview_data_enabled = true
	if not slot_context.is_empty():
		_apply_slot_scope()
		_rebuild_sections()


func calculate_remaining_durability_percent(item: Dictionary, current_date: String = "") -> float:
	if bool(item.get("is_heirloom", false)):
		return -1.0
	var purchase_date := str(item.get("purchase_date", ""))
	var expiration_date := str(item.get("expiration_date", ""))
	if purchase_date.is_empty() or expiration_date.is_empty():
		return -1.0
	var resolved_current_date := current_date if not current_date.is_empty() else _current_iso_date()
	var purchase_day := _iso_date_to_ordinal(purchase_date)
	var expiration_day := _iso_date_to_ordinal(expiration_date)
	var current_day := _iso_date_to_ordinal(resolved_current_date)
	var lifetime := expiration_day - purchase_day
	if purchase_day < 0 or expiration_day < 0 or current_day < 0 or lifetime <= 0:
		return 0.0
	return clampf(float(expiration_day - current_day) / float(lifetime) * 100.0, 0.0, 100.0)


func expand_owned_items() -> void:
	owned_expanded = true
	_rebuild_owned_grid()


func expand_shop_items() -> void:
	shop_expanded = true
	_rebuild_shop_grid()


func get_visible_owned_items() -> Array:
	return _filtered_items(owned_items)


func get_visible_shop_items() -> Array:
	return _filtered_items(shop_items)


func get_display_snapshot() -> Dictionary:
	var filtered_owned := get_visible_owned_items()
	var filtered_shop := get_visible_shop_items()
	return {
		"visible": visible,
		"character_id": target_character_id,
		"slot_context": slot_context,
		"filter_visible": owned_filter_bar != null and owned_filter_bar.visible,
		"selected_filter": selected_filter,
		"equipped_empty": equipped_item.is_empty(),
		"owned_count": filtered_owned.size(),
		"shop_count": filtered_shop.size(),
		"owned_rendered": owned_grid.get_child_count() if owned_grid != null else 0,
		"shop_rendered": shop_grid.get_child_count() if shop_grid != null else 0,
		"owned_remaining": maxi(filtered_owned.size() - INITIAL_OWNED_COUNT, 0) if not owned_expanded else 0,
		"shop_remaining": maxi(filtered_shop.size() - INITIAL_SHOP_COUNT, 0) if not shop_expanded else 0,
		"dim_opacity": dim_background.color.a if dim_background != null else 0.0,
		"sheet_top": SHEET_TOP,
		"scroll_enabled": scroll_container != null,
	}


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_sheet()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	modal_root = get_node_or_null("ModalRoot") as Control
	if modal_root == null:
		modal_root = Control.new()
		modal_root.name = "ModalRoot"
		modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(modal_root)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.theme = item_list_shop_theme

	dim_background = ColorRect.new()
	dim_background.name = "DimBackground"
	dim_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_background.color = Color(0.02, 0.07, 0.06, DIM_OPACITY)
	dim_background.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_background.gui_input.connect(_on_dim_background_gui_input)
	modal_root.add_child(dim_background)

	sheet_panel = PanelContainer.new()
	sheet_panel.name = "Sheet"
	sheet_panel.anchor_top = SHEET_TOP_RATIO
	sheet_panel.anchor_right = 1.0
	sheet_panel.anchor_bottom = 1.0
	sheet_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet_panel.clip_contents = true
	sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_panel.add_theme_stylebox_override("panel", _make_sheet_style())
	modal_root.add_child(sheet_panel)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "ContentScroll"
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_panel.add_child(scroll_container)

	var page_margin := MarginContainer.new()
	page_margin.name = "PageMargin"
	page_margin.custom_minimum_size = Vector2(1080.0, 0.0)
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 40)
	page_margin.add_theme_constant_override("margin_top", 16)
	page_margin.add_theme_constant_override("margin_right", 40)
	page_margin.add_theme_constant_override("margin_bottom", 70)
	scroll_container.add_child(page_margin)

	content = VBoxContainer.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	page_margin.add_child(content)

	_build_handle()
	_build_balance_panel()
	content.add_child(_make_section_header("EQUIPPED", true))
	equipped_body = HBoxContainer.new()
	equipped_body.name = "EquippedBody"
	equipped_body.add_theme_constant_override("separation", GRID_GAP)
	content.add_child(equipped_body)
	content.add_child(_make_section_header("OWNED"))
	owned_filter_bar = FILTER_BAR_SCENE.instantiate() as ItemFilterBar
	owned_filter_bar.name = "OwnedFilterBar"
	owned_filter_bar.filter_changed.connect(_on_filter_changed)
	content.add_child(owned_filter_bar)
	owned_grid = _make_grid("OwnedGrid")
	content.add_child(owned_grid)
	owned_expand_button = _make_expand_button("OwnedExpandButton", expand_owned_items)
	content.add_child(owned_expand_button)
	content.add_child(_make_section_header("MORE ITEMS"))
	shop_filter_bar = FILTER_BAR_SCENE.instantiate() as ItemFilterBar
	shop_filter_bar.name = "ShopFilterBar"
	shop_filter_bar.filter_changed.connect(_on_filter_changed)
	content.add_child(shop_filter_bar)
	shop_grid = _make_grid("ShopGrid")
	content.add_child(shop_grid)
	shop_expand_button = _make_expand_button("ShopExpandButton", expand_shop_items)
	content.add_child(shop_expand_button)


func _build_handle() -> void:
	var center := CenterContainer.new()
	center.name = "HandleCenter"
	center.custom_minimum_size = Vector2(0.0, 32.0)
	content.add_child(center)
	var handle := PanelContainer.new()
	handle.name = "Handle"
	handle.custom_minimum_size = Vector2(200.0, 8.0)
	handle.add_theme_stylebox_override("panel", _make_style(COLOR_HANDLE, 4, Color.TRANSPARENT, 0))
	center.add_child(handle)


func _build_balance_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "CurrentBalance"
	panel.custom_minimum_size = Vector2(0.0, 80.0)
	panel.add_theme_stylebox_override("panel", _make_style(COLOR_PANEL, 22, COLOR_BORDER, 2))
	content.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	var title := _make_label("CURRENT BALANCE", 25, FONT_EXTRA_BOLD, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var diamond_entry := _make_balance_entry("diamond.png", "0")
	diamond_balance_label = diamond_entry.get("label") as Label
	row.add_child(diamond_entry.get("root") as Control)
	var money_entry := _make_balance_entry("coin.png", "0")
	money_balance_label = money_entry.get("label") as Label
	row.add_child(money_entry.get("root") as Control)


func _make_balance_entry(icon_file: String, initial_value: String) -> Dictionary:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_make_texture(CURRENCY_FOLDER + icon_file, Vector2(34.0, 34.0)))
	var label := _make_label(initial_value, 30, FONT_BOLD, COLOR_TEXT)
	root.add_child(label)
	return {"root": root, "label": label}


func _make_section_header(title_text: String, show_crown: bool = false) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.name = title_text.to_pascal_case() + "Header"
	header.custom_minimum_size = Vector2(0.0, 30.0)
	header.add_theme_constant_override("separation", 12)
	if show_crown:
		var crown := _make_texture(ICON_FOLDER + "heirloom_rarity_icon.svg", Vector2(22.0, 22.0))
		crown.modulate = COLOR_BROWN
		header.add_child(crown)
	header.add_child(_make_label(title_text, 25, FONT_BOLD, COLOR_BROWN))
	var line := HSeparator.new()
	line.name = "Divider"
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var divider_style := StyleBoxFlat.new()
	divider_style.bg_color = COLOR_BROWN
	divider_style.content_margin_top = 1.0
	line.add_theme_stylebox_override("separator", divider_style)
	header.add_child(line)
	return header


func _make_grid(grid_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	return grid


func _make_expand_button(button_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", load(FONT_BOLD) as Font)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", COLOR_BROWN)
	button.add_theme_color_override("font_hover_color", COLOR_BROWN)
	button.add_theme_color_override("font_pressed_color", COLOR_BROWN)
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.pressed.connect(callback)
	return button


func _bind_from_provider() -> void:
	source_equipped_by_slot.clear()
	source_owned_items.clear()
	source_shop_items.clear()
	unavailable_owned_instance_ids.clear()
	if data_provider.has_method("get_equipped_item"):
		var equipped_value = data_provider.call("get_equipped_item", target_character_id, slot_context)
		if typeof(equipped_value) == TYPE_DICTIONARY and not (equipped_value as Dictionary).is_empty():
			source_equipped_by_slot[slot_context] = (equipped_value as Dictionary).duplicate(true)
	if data_provider.has_method("get_owned_items"):
		var owned_value = data_provider.call("get_owned_items", slot_context)
		if typeof(owned_value) == TYPE_ARRAY:
			source_owned_items = (owned_value as Array).duplicate(true)
	if data_provider.has_method("get_equipped_instance_ids"):
		var equipped_ids_value = data_provider.call("get_equipped_instance_ids")
		if typeof(equipped_ids_value) == TYPE_ARRAY:
			for instance_id_value in equipped_ids_value as Array:
				var instance_id := str(instance_id_value)
				if not instance_id.is_empty():
					unavailable_owned_instance_ids[instance_id] = true
	if data_provider.has_method("get_monthly_shop_items"):
		var shop_value = data_provider.call("get_monthly_shop_items", slot_context)
		if typeof(shop_value) == TYPE_ARRAY:
			source_shop_items = (shop_value as Array).duplicate(true)
	_rebuild_unavailable_owned_instance_ids(false)


func _apply_slot_scope() -> void:
	equipped_item = {}
	var equipped_value = source_equipped_by_slot.get(slot_context, {})
	if typeof(equipped_value) == TYPE_DICTIONARY:
		var candidate := equipped_value as Dictionary
		if _item_matches_slot(candidate):
			equipped_item = _prepare_item(candidate, ItemListShopCard.Mode.EQUIPPED)
	owned_items = []
	for value in source_owned_items:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var owned_item := value as Dictionary
		var instance_id := str(owned_item.get("instance_id", ""))
		if not instance_id.is_empty() and unavailable_owned_instance_ids.has(instance_id):
			continue
		if _item_matches_slot(owned_item):
			owned_items.append(_prepare_item(owned_item, ItemListShopCard.Mode.OWNED))
	shop_items = []
	for value in source_shop_items:
		if typeof(value) == TYPE_DICTIONARY and _item_matches_slot(value as Dictionary):
			shop_items.append(_prepare_item(value as Dictionary, ItemListShopCard.Mode.SHOP))


func _prepare_item(item: Dictionary, card_mode: ItemListShopCard.Mode) -> Dictionary:
	var prepared := item.duplicate(true)
	if bool(prepared.get("is_heirloom", false)):
		prepared.erase("durability_percent")
	elif not prepared.has("durability_percent"):
		if card_mode == ItemListShopCard.Mode.SHOP:
			prepared["durability_percent"] = 100.0
		else:
			var percent := calculate_remaining_durability_percent(prepared)
			if percent >= 0.0:
				prepared["durability_percent"] = percent
	return prepared


func _item_matches_slot(item: Dictionary) -> bool:
	return str(item.get("slot", "")).strip_edges().to_lower() == slot_context


func _rebuild_unavailable_owned_instance_ids(clear_existing: bool = true) -> void:
	if clear_existing:
		unavailable_owned_instance_ids.clear()
	for value in source_equipped_by_slot.values():
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var instance_id := str((value as Dictionary).get("instance_id", ""))
		if not instance_id.is_empty():
			unavailable_owned_instance_ids[instance_id] = true


func _rebuild_sections() -> void:
	if content == null:
		return
	var show_filters := slot_context == "accessory"
	owned_filter_bar.visible = show_filters
	shop_filter_bar.visible = show_filters
	owned_filter_bar.set_selected_filter(selected_filter)
	shop_filter_bar.set_selected_filter(selected_filter)
	_rebuild_equipped()
	_rebuild_owned_grid()
	_rebuild_shop_grid()


func _rebuild_equipped() -> void:
	_clear_container(equipped_body)
	if equipped_item.is_empty():
		var empty := DashedEmptyState.new()
		empty.name = "EquippedEmptyState"
		empty.setup(_slot_icon_path(slot_context))
		equipped_body.add_child(empty)
	else:
		equipped_body.add_child(_create_item_card(equipped_item, ItemListShopCard.Mode.EQUIPPED))
	var info_panel := INFO_PANEL_SCENE.instantiate()
	info_panel.name = "ItemInfoPanel"
	equipped_body.add_child(info_panel)


func _rebuild_owned_grid() -> void:
	_clear_container(owned_grid)
	var filtered := get_visible_owned_items()
	var render_count := filtered.size() if owned_expanded else mini(filtered.size(), INITIAL_OWNED_COUNT)
	for index in range(render_count):
		owned_grid.add_child(_create_item_card(filtered[index], ItemListShopCard.Mode.OWNED))
	var remaining := maxi(filtered.size() - render_count, 0)
	owned_expand_button.visible = remaining > 0
	owned_expand_button.text = "Show %d More   ↓" % remaining


func _rebuild_shop_grid() -> void:
	_clear_container(shop_grid)
	var filtered := get_visible_shop_items()
	var render_count := filtered.size() if shop_expanded else mini(filtered.size(), INITIAL_SHOP_COUNT)
	for index in range(render_count):
		shop_grid.add_child(_create_item_card(filtered[index], ItemListShopCard.Mode.SHOP))
	var remaining := maxi(filtered.size() - render_count, 0)
	shop_expand_button.visible = remaining > 0
	shop_expand_button.text = "Show %d More   ↓" % remaining


func _create_item_card(item: Dictionary, card_mode: ItemListShopCard.Mode) -> ItemListShopCard:
	var card := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	card.custom_minimum_size.x = CARD_WIDTH
	card.configure(item, card_mode)
	card.action_requested.connect(_on_card_action.bind(card_mode))
	return card


func _on_card_action(item_reference: Variant, card_mode: ItemListShopCard.Mode) -> void:
	match card_mode:
		ItemListShopCard.Mode.SHOP:
			item_buy_requested.emit(target_character_id, item_reference, slot_context)
		ItemListShopCard.Mode.EQUIPPED:
			item_unequip_requested.emit(target_character_id, item_reference, slot_context)
		_:
			item_wear_requested.emit(target_character_id, item_reference, slot_context)


func _on_filter_changed(filter_key: String) -> void:
	if slot_context != "accessory":
		return
	selected_filter = filter_key
	owned_expanded = false
	shop_expanded = false
	owned_filter_bar.set_selected_filter(selected_filter)
	shop_filter_bar.set_selected_filter(selected_filter)
	_rebuild_owned_grid()
	_rebuild_shop_grid()


func _filtered_items(items: Array) -> Array:
	if slot_context != "accessory" or selected_filter == "all":
		return items.duplicate()
	var result: Array = []
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and AccessoryCategoryClassifier.matches(item as Dictionary, selected_filter):
			result.append(item)
	return result


func _refresh_balance() -> void:
	if diamond_balance_label != null:
		diamond_balance_label.text = _format_number(int(GameManager.diamonds))
	if money_balance_label != null:
		money_balance_label.text = _format_number(int(GameManager.family_money))


func _on_dim_background_gui_input(event: InputEvent) -> void:
	var should_close := (
		event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	) or (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and (event as InputEventMouseButton).pressed
	)
	if should_close:
		close_sheet()
	get_viewport().set_input_as_handled()


func _slot_icon_path(slot: String) -> String:
	match slot:
		"outfit":
			return ICON_FOLDER + "outfit-icon.svg"
		"vehicle":
			return ICON_FOLDER + "vehicle-icon.svg"
		_:
			return ICON_FOLDER + "watch-icon.svg"


func _current_iso_date() -> String:
	return "%04d-%02d-%02d" % [
		int(TimeManager.current_year),
		int(TimeManager.current_month),
		int(TimeManager.current_day),
	]


func _iso_date_to_ordinal(date_text: String) -> int:
	var parts := date_text.split("-")
	if parts.size() != 3:
		return -1
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1 or month < 1 or month > 12 or day < 1:
		return -1
	var month_lengths: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var leap_year := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	if leap_year:
		month_lengths[1] = 29
	if day > month_lengths[month - 1]:
		return -1
	var previous_year := year - 1
	var days_before_year := (
		365 * previous_year
		+ floori(float(previous_year) / 4.0)
		- floori(float(previous_year) / 100.0)
		+ floori(float(previous_year) / 400.0)
	)
	var ordinal := days_before_year + day
	for month_index in range(month - 1):
		ordinal += month_lengths[month_index]
	return ordinal


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _format_number(value: int) -> String:
	var raw := str(absi(value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return ("-" if value < 0 else "") + raw + result


func _make_texture(path: String, minimum_size: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	if ResourceLoader.exists(path):
		texture.texture = load(path) as Texture2D
	texture.custom_minimum_size = minimum_size
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


func _make_label(text_value: String, font_size: int, font_path: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", load(font_path) as Font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_sheet_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SHEET
	style.corner_radius_top_left = 44
	style.corner_radius_top_right = 44
	return style


func _make_style(background: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border
	return style
