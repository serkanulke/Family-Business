extends Node


const ITEM_LIST_SHEET_SCENE := preload("res://UI/ItemListShop/ItemListBottomSheet.tscn")
const ITEM_CARD_SCENE := preload("res://UI/ItemListShop/Components/ItemCard.tscn")
const FAMILY_TREE_SCENE := preload("res://Scenes/FamilyTree/FamilyTreeScreen.tscn")

var passed := 0
var failed := 0
var action_character_id := 0
var action_item_reference: Variant
var action_slot := ""


func _ready() -> void:
	var original_day: int = TimeManager.current_day
	var original_month: int = TimeManager.current_month
	var original_year: int = TimeManager.current_year
	TimeManager.current_day = 1
	TimeManager.current_month = 7
	TimeManager.current_year = 2025
	var character := {
		"character_id": 909,
		"first_name": "Preview",
		"gender": "female",
		"birth_date": "1990-01-01",
		"is_player_family": true,
		"health": 50,
		"happiness": 50,
		"logic": 50,
		"attractiveness": 50,
		"social": 50,
		"confidence": 50,
		"discipline": 50,
		"creativity": 50,
		"event_log": [],
	}
	CharacterManager.characters.append(character)

	var preview := _preview_data()
	var sheet := ITEM_LIST_SHEET_SCENE.instantiate() as ItemListBottomSheet
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_preview_data(preview["equipped"], preview["owned"], preview["shop"])
	sheet.item_buy_requested.connect(_capture_action)
	sheet.item_wear_requested.connect(_capture_action)
	sheet.item_unequip_requested.connect(_capture_action)

	_assert_true(sheet.open_for_character(909, "accessory"), "Accessory slot opens the reusable bottom sheet")
	var snapshot := sheet.get_display_snapshot()
	_assert_equal(snapshot.get("slot_context"), "accessory", "Accessory context is retained")
	_assert_equal(snapshot.get("character_id"), 909, "Selected character context is retained")
	_assert_true(snapshot.get("filter_visible"), "Accessory filters are visible")
	_assert_equal(snapshot.get("owned_count"), 5, "Accessory Owned excludes the equipped instance plus other slots")
	_assert_equal(snapshot.get("shop_count"), 6, "Accessory scope excludes Outfit and Vehicle shop items")
	_assert_true(not snapshot.get("equipped_empty"), "Equipped item state renders")
	var visible_owned_instance_ids: Array[String] = []
	for owned_value in sheet.get_visible_owned_items():
		visible_owned_instance_ids.append(str((owned_value as Dictionary).get("instance_id", "")))
	_assert_true("owned_watch_2" not in visible_owned_instance_ids, "Equipped instance_id is never duplicated in Owned")
	_assert_equal(snapshot.get("owned_remaining"), 3, "Show X More uses the post-equipped-filter count")
	_assert_approx(float(snapshot.get("dim_opacity")), 0.76, 0.001, "Reference-compatible dim opacity is used")
	_assert_equal(snapshot.get("sheet_top"), 320.0, "Sheet starts at the reference Y position")
	_assert_true(snapshot.get("scroll_enabled"), "Bottom-sheet content owns a vertical ScrollContainer")
	_assert_equal(sheet.modal_root.mouse_filter, Control.MOUSE_FILTER_STOP, "Modal root blocks background input")
	_assert_equal(sheet.dim_background.mouse_filter, Control.MOUSE_FILTER_STOP, "Dim scrim blocks background input")
	_test_shared_visual_structure(sheet)

	var inside_click := InputEventMouseButton.new()
	inside_click.button_index = MOUSE_BUTTON_LEFT
	inside_click.pressed = true
	sheet.sheet_panel.gui_input.emit(inside_click)
	_assert_true(sheet.visible, "Input inside the sheet does not close it")
	var scrim_click := InputEventMouseButton.new()
	scrim_click.button_index = MOUSE_BUTTON_LEFT
	scrim_click.pressed = true
	sheet.dim_background.gui_input.emit(scrim_click)
	_assert_true(not sheet.visible, "Dark scrim tap closes only the Item List sheet")
	_assert_true(sheet.open_for_character(909, "accessory"), "Sheet reopens after scrim close")
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	sheet._unhandled_input(cancel_event)
	_assert_true(not sheet.visible, "ui_cancel/Escape closes the Item List sheet")
	_assert_true(sheet.open_for_character(909, "accessory"), "Sheet reopens with fresh context after ui_cancel")

	_test_filter(sheet, "ring", 2)
	_test_filter(sheet, "glasses", 1)
	_test_filter(sheet, "watch", 1)
	_test_filter(sheet, "necklace", 1)
	sheet.owned_filter_bar.set_selected_filter("all", true)
	sheet.expand_owned_items()
	snapshot = sheet.get_display_snapshot()
	_assert_equal(snapshot.get("owned_rendered"), 5, "Show X More expands all available unequipped cards")
	_assert_equal(snapshot.get("owned_remaining"), 0, "Expanded list has no stale remaining count")

	var first_owned_card := sheet.owned_grid.get_child(0) as ItemListShopCard
	first_owned_card.request_action()
	_assert_equal(action_character_id, 909, "Wear carries the selected character ID")
	_assert_equal(action_slot, "accessory", "Wear carries the selected slot")
	_assert_equal(action_item_reference, "owned_ring_1", "Wear carries the runtime item instance ID")

	var equipped_card := sheet.equipped_body.get_child(0) as ItemListShopCard
	equipped_card.request_action()
	_assert_equal(action_character_id, 909, "Unequip carries the selected character ID")
	_assert_equal(action_slot, "accessory", "Unequip carries the selected slot")
	_assert_equal(action_item_reference, "owned_watch_2", "Unequip carries the equipped item instance ID")

	var first_shop_card := sheet.shop_grid.get_child(0) as ItemListShopCard
	first_shop_card.request_action()
	_assert_equal(action_character_id, 909, "Buy carries the selected character ID")
	_assert_equal(action_slot, "accessory", "Buy carries the selected slot")
	_assert_equal(action_item_reference, "ring_catalog_1", "Buy carries the catalog/shop item ID")
	_assert_equal(snapshot.get("shop_remaining"), 2, "Shop Show X More uses the real remaining count")
	sheet.expand_shop_items()
	_assert_equal(sheet.get_display_snapshot().get("shop_rendered"), 6, "Shop Show X More expands all remaining cards")
	_assert_true(sheet.content.get_combined_minimum_size().y > sheet.sheet_panel.size.y, "Expanded long content exceeds the sheet and remains scrollable")

	sheet.close_sheet()
	_assert_true(sheet.open_for_character(909, "outfit"), "Outfit slot opens independently")
	snapshot = sheet.get_display_snapshot()
	_assert_true(not snapshot.get("filter_visible"), "Outfit does not show the Accessory filter bar")
	_assert_equal(snapshot.get("owned_count"), 0, "Outfit Owned is empty when its only instance is equipped")
	_assert_equal(snapshot.get("shop_count"), 1, "Outfit shop scope contains only Outfit stock")

	sheet.close_sheet()
	_assert_true(sheet.open_for_character(909, "vehicle"), "Vehicle slot opens independently")
	snapshot = sheet.get_display_snapshot()
	_assert_true(not snapshot.get("filter_visible"), "Vehicle does not show the Accessory filter bar")
	_assert_equal(snapshot.get("owned_count"), 1, "Vehicle scope contains only Vehicle items")
	_assert_equal(snapshot.get("shop_count"), 1, "Vehicle shop scope contains only Vehicle stock")
	_assert_true(snapshot.get("equipped_empty"), "Vehicle empty Equipped state renders")
	var empty_state := sheet.equipped_body.get_child(0)
	_assert_equal(float(empty_state.get("corner_radius")), 24.0, "Empty Equipped dashed frame uses a 24 px corner radius")
	_assert_true(str(empty_state.get("icon_path")).ends_with("vehicle-icon.svg"), "Vehicle empty state uses the Vehicle slot icon")
	var empty_icon := empty_state.get("icon") as TextureRect
	_assert_true(empty_icon != null and empty_icon.material is ShaderMaterial, "Empty Equipped icon uses the shared beige alpha-tint material")
	var empty_info_panel := sheet.equipped_body.get_child(1) as ItemInfoPanel
	_assert_true(empty_info_panel != null and empty_info_panel.visible, "Empty Equipped keeps the shared information panel")
	_assert_equal(empty_info_panel.custom_minimum_size, Vector2(488.0, 655.0), "Empty Equipped information panel keeps the reference column size")
	_assert_true(empty_info_panel.get_child_count() > 0, "Empty Equipped information panel builds its shared content")

	var instance_id_before := sheet.get_instance_id()
	sheet.close_sheet()
	sheet.open_for_character(909, "accessory")
	_assert_equal(sheet.get_instance_id(), instance_id_before, "Reopening reuses one sheet instance")
	_assert_equal(sheet.get_display_snapshot().get("selected_filter"), "all", "Reopening clears stale filter state")
	sheet.open_for_character(910, "vehicle")
	_assert_equal(sheet.target_character_id, 910, "Reopening replaces stale character context")
	_assert_equal(sheet.slot_context, "vehicle", "Reopening replaces stale slot context")
	sheet.open_for_character(909, "accessory")

	_test_durability(sheet)
	await _test_item_card_pricing_and_actions()
	await _test_family_tree_integration(character, preview)

	if "--capture" in OS.get_cmdline_user_args():
		await _capture_reference_preview(character, preview)

	print("")
	print("========================================")
	print("Item List / Shop tests: ", passed, " passed / ", failed, " failed")
	print("========================================")
	if failed == 0:
		print("ALL ITEM LIST / SHOP TESTS PASSED.")
	else:
		push_error("Item List / Shop has %d failing test(s)." % failed)

	CharacterManager.characters.erase(character)
	TimeManager.current_day = original_day
	TimeManager.current_month = original_month
	TimeManager.current_year = original_year
	get_tree().quit(failed)


func _test_filter(sheet: ItemListBottomSheet, filter_key: String, expected_count: int) -> void:
	sheet.owned_filter_bar.set_selected_filter(filter_key, true)
	_assert_equal(
		sheet.get_display_snapshot().get("owned_count"),
		expected_count,
		"%s filter classifies canonical paths without a subtype field" % filter_key.capitalize()
	)


func _test_durability(sheet: ItemListBottomSheet) -> void:
	var normal_item := {
		"purchase_date": "2025-01-01",
		"expiration_date": "2026-01-01",
		"is_heirloom": false,
	}
	var percent := sheet.calculate_remaining_durability_percent(normal_item, "2025-07-02")
	_assert_approx(percent, 50.0, 0.6, "Durability is derived from purchase and expiration dates")
	var heirloom := normal_item.duplicate(true)
	heirloom["is_heirloom"] = true
	_assert_equal(sheet.calculate_remaining_durability_percent(heirloom, "2025-07-02"), -1.0, "Heirloom bypasses expiration durability")


func _test_shared_visual_structure(sheet: ItemListBottomSheet) -> void:
	for header_name in ["EquippedHeader", "OwnedHeader", "MoreItemsHeader"]:
		var header := sheet.content.find_child(header_name, true, false) as HBoxContainer
		var divider := header.find_child("Divider", true, false) as HSeparator if header != null else null
		_assert_true(header != null and divider != null and divider.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "%s uses the shared responsive brown divider" % header_name)
	var info_panel := sheet.equipped_body.get_child(1) as ItemInfoPanel
	var durability_circle := info_panel.find_child("DurabilityIconCircle", true, false) as PanelContainer
	var circle_style := durability_circle.get_theme_stylebox("panel") as StyleBoxFlat
	_assert_equal(durability_circle.custom_minimum_size.x, durability_circle.custom_minimum_size.y, "Durability info icon background has equal width and height")
	_assert_equal(circle_style.corner_radius_top_left, 26, "Durability info icon background uses radius width/2")
	_assert_true(is_equal_approx(durability_circle.size.x, durability_circle.size.y), "Rendered Durability info icon background remains circular")
	for section_name in ["Durability", "FamilyHeirloom", "LifestyleScore"]:
		var row := info_panel.find_child(section_name + "Row", true, false) as HBoxContainer
		var icon_center := info_panel.find_child(section_name + "IconCenter", true, false) as CenterContainer
		var text_block := info_panel.find_child(section_name + "TextBlock", true, false) as VBoxContainer
		var title := info_panel.find_child(section_name + "Title", true, false) as Label
		var description := info_panel.find_child(section_name + "Description", true, false) as Label
		_assert_true(row != null and icon_center != null and text_block != null and icon_center.get_parent() == row and text_block.get_parent() == row, "%s uses one shared icon plus title/description row" % section_name)
		_assert_equal(title.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "%s title is left-aligned" % section_name)
		_assert_equal(description.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "%s description is left-aligned" % section_name)
		_assert_true(title.get_parent() == text_block and description.get_parent() == text_block, "%s title and description share one text column" % section_name)
		_assert_equal(icon_center.size_flags_vertical, Control.SIZE_SHRINK_CENTER, "%s icon centers against the complete text block" % section_name)
		_assert_equal(text_block.size_flags_vertical, Control.SIZE_SHRINK_CENTER, "%s text block centers as one unit" % section_name)
	var info_dividers := info_panel.find_children("InfoDivider*", "HSeparator", true, false)
	_assert_equal(info_dividers.size(), 2, "Info panel has separators only between its three sections")
	for divider_value in info_dividers:
		var divider := divider_value as HSeparator
		var divider_style := divider.get_theme_stylebox("separator") as StyleBoxLine
		_assert_true(divider.size_flags_horizontal == Control.SIZE_EXPAND_FILL and divider_style != null and divider_style.thickness == 1, "Info separator fills the usable panel width with a thin shared line")
	var normal_card := sheet.owned_grid.get_child(0) as ItemListShopCard
	_assert_true(normal_card.durability_label != null and normal_card.durability_label.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Durability value is vertically centered in the shared row")
	_assert_true(normal_card.durability_bar != null and normal_card.durability_bar.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Durability progress bar is vertically centered in the shared row")


func _test_item_card_pricing_and_actions() -> void:
	var money_item := _base_item("money_item", "accessory", "rare", false)
	money_item["money_price"] = 12000
	money_item["diamond_price"] = 0
	money_item["durability_percent"] = 70.0
	var money_card := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	money_card.configure(money_item, ItemListShopCard.Mode.SHOP)
	_assert_equal(money_card.get_display_snapshot().get("currencies"), ["money"], "Normal Money-only item hides Diamond price")

	var legendary_item := _base_item("legendary_item", "accessory", "legendary", false)
	legendary_item["money_price"] = 50000
	legendary_item["diamond_price"] = 4
	legendary_item["durability_percent"] = 80.0
	var legendary_card := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	legendary_card.configure(legendary_item, ItemListShopCard.Mode.SHOP)
	_assert_equal(legendary_card.get_display_snapshot().get("currencies"), ["diamond", "money"], "Normal Legendary item supports Money plus Diamonds")

	var heirloom_item := _base_item("heirloom_item", "accessory", "epic", true)
	heirloom_item["money_price"] = 999999
	heirloom_item["diamond_price"] = 110
	var heirloom_card := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	heirloom_card.configure(heirloom_item, ItemListShopCard.Mode.SHOP)
	var heirloom_snapshot := heirloom_card.get_display_snapshot()
	_assert_equal(heirloom_snapshot.get("rarity"), "epic", "Heirloom keeps its normal rarity")
	_assert_equal(heirloom_snapshot.get("currencies"), ["diamond"], "Heirloom pricing overrides rarity and hides Money")
	_assert_true(heirloom_snapshot.get("crown_inside_badge"), "Heirloom crown appears inside the rarity badge")
	_assert_true(not heirloom_snapshot.get("durability_visible"), "Heirloom does not show normal durability")
	_assert_true(heirloom_snapshot.get("durability_space_reserved"), "Heirloom keeps the empty durability slot in layout")

	var layout := VBoxContainer.new()
	add_child(layout)
	var shop_row := HBoxContainer.new()
	layout.add_child(shop_row)
	shop_row.add_child(money_card)
	shop_row.add_child(heirloom_card)
	layout.add_child(legendary_card)
	var normal_owned := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	normal_owned.configure(money_item, ItemListShopCard.Mode.OWNED)
	var heirloom_owned := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	heirloom_owned.configure(heirloom_item, ItemListShopCard.Mode.OWNED)
	var owned_row := HBoxContainer.new()
	layout.add_child(owned_row)
	owned_row.add_child(normal_owned)
	owned_row.add_child(heirloom_owned)
	var normal_equipped := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	normal_equipped.configure(money_item, ItemListShopCard.Mode.EQUIPPED)
	var heirloom_equipped := ITEM_CARD_SCENE.instantiate() as ItemListShopCard
	heirloom_equipped.configure(heirloom_item, ItemListShopCard.Mode.EQUIPPED)
	var equipped_row := HBoxContainer.new()
	layout.add_child(equipped_row)
	equipped_row.add_child(normal_equipped)
	equipped_row.add_child(heirloom_equipped)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_approx(money_card.action_button.position.y, heirloom_card.action_button.position.y, 0.1, "SHOP Heirloom Buy button keeps the normal baseline")
	_assert_approx(normal_owned.action_button.position.y, heirloom_owned.action_button.position.y, 0.1, "OWNED Heirloom Wear button keeps the normal baseline")
	_assert_approx(normal_equipped.action_button.position.y, heirloom_equipped.action_button.position.y, 0.1, "EQUIPPED Heirloom Unequip button keeps the normal baseline")
	_assert_approx(money_card.get_combined_minimum_size().y, heirloom_card.get_combined_minimum_size().y, 0.1, "SHOP Heirloom and normal cards keep equal height")
	_assert_approx(normal_owned.get_combined_minimum_size().y, heirloom_owned.get_combined_minimum_size().y, 0.1, "OWNED Heirloom and normal cards keep equal height")
	_assert_approx(normal_equipped.get_combined_minimum_size().y, heirloom_equipped.get_combined_minimum_size().y, 0.1, "EQUIPPED Heirloom and normal cards keep equal height")
	layout.queue_free()


func _test_family_tree_integration(character: Dictionary, preview: Dictionary) -> void:
	var screen := FAMILY_TREE_SCENE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var card = screen.get_node("CharacterCard")
	var integrated_sheet := screen.get_node("ItemListBottomSheet") as ItemListBottomSheet
	integrated_sheet.set_preview_data(preview["equipped"], preview["owned"], preview["shop"])
	_assert_true(card.open_for_character(int(character["character_id"])), "Character Card opens before item selection")
	card.request_item_slot("accessory")
	_assert_true(integrated_sheet.visible, "Accessory Character Card slot opens the Item List bottom sheet")
	_assert_true(not card.visible, "Character Card is hidden while the slot sheet is in front")
	_assert_equal(integrated_sheet.slot_context, "accessory", "Integrated Accessory route keeps slot context")
	var scrim_click := InputEventMouseButton.new()
	scrim_click.button_index = MOUSE_BUTTON_LEFT
	scrim_click.pressed = true
	integrated_sheet.dim_background.gui_input.emit(scrim_click)
	_assert_true(card.visible, "Closing the sheet restores the same Character Card context")
	_assert_equal(card.character_id, int(character["character_id"]), "Scrim close preserves the Character Card character context")
	card.request_item_slot("outfit")
	_assert_equal(integrated_sheet.slot_context, "outfit", "Integrated Outfit route keeps slot context")
	integrated_sheet.close_sheet()
	card.request_item_slot("vehicle")
	_assert_equal(integrated_sheet.slot_context, "vehicle", "Integrated Vehicle route keeps slot context")
	_assert_equal(screen.get_node("ItemListBottomSheet").get_instance_id(), integrated_sheet.get_instance_id(), "Integration does not stack duplicate sheets")
	integrated_sheet.close_sheet()
	screen.queue_free()


func _capture_reference_preview(character: Dictionary, preview: Dictionary) -> void:
	var preview_viewport := SubViewport.new()
	preview_viewport.size = Vector2i(1080, 1920)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.transparent_bg = false
	add_child(preview_viewport)
	var screen := FAMILY_TREE_SCENE.instantiate()
	preview_viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var sheet := screen.get_node("ItemListBottomSheet") as ItemListBottomSheet
	sheet.set_preview_data(preview["equipped"], preview["owned"], preview["shop"])
	sheet.open_for_character(int(character["character_id"]), "accessory")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_path := "res://Tests/Artifacts/item_list_shop_reference_recreation.png"
	var image := preview_viewport.get_texture().get_image()
	var error := image.save_png(capture_path)
	_assert_equal(error, OK, "1080x1920 visual capture saves")
	print("Item List / Shop capture: ", ProjectSettings.globalize_path(capture_path))
	sheet.open_for_character(int(character["character_id"]), "vehicle")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var empty_capture_path := "res://Tests/Artifacts/item_list_shop_empty_equipped.png"
	var empty_image := preview_viewport.get_texture().get_image()
	var empty_error := empty_image.save_png(empty_capture_path)
	_assert_equal(empty_error, OK, "1080x1920 rounded empty Equipped capture saves")
	print("Item List / Shop empty capture: ", ProjectSettings.globalize_path(empty_capture_path))
	preview_viewport.queue_free()


func _preview_data() -> Dictionary:
	var ring_1 := _base_item("ring_catalog_1", "accessory", "epic", false)
	ring_1["instance_id"] = "owned_ring_1"
	ring_1["display_name"] = "Gold Skeleton Watch"
	ring_1["image_path"] = "res://Resources/Items/accessory/ring/epic/accessory_epic_gold_blue_crystal_ring_043.png"
	ring_1["lifestyle_value"] = 26
	ring_1["purchase_date"] = "2025-01-01"
	ring_1["expiration_date"] = "2027-01-01"
	var ring_2 := ring_1.duplicate(true)
	ring_2["item_id"] = "ring_catalog_2"
	ring_2["instance_id"] = "owned_ring_2"
	ring_2["display_name"] = "Blue Crystal Ring"
	ring_2["image_path"] = "res://Resources/Items/accessory/ring/rare/accessory_rare_gold_blue_crystal_ring_037.png"
	ring_2["rarity"] = "rare"
	var watch_1 := _base_item("watch_catalog_1", "accessory", "rare", false)
	watch_1["instance_id"] = "owned_watch_1"
	watch_1["display_name"] = "Navy Chronograph"
	watch_1["image_path"] = "res://Resources/Items/accessory/watch/rare/accessory_rare_silver_black_chronograph_watch_024.png"
	watch_1["purchase_date"] = "2024-01-01"
	watch_1["expiration_date"] = "2028-01-01"
	var watch_2 := watch_1.duplicate(true)
	watch_2["item_id"] = "watch_catalog_2"
	watch_2["instance_id"] = "owned_watch_2"
	watch_2["image_path"] = "res://Resources/Items/accessory/watch/epic/accessory_epic_heirloom_silver_navy_moonphase_watch_033.png"
	watch_2["rarity"] = "epic"
	watch_2["is_heirloom"] = true
	watch_2["diamond_price"] = 110
	var glasses := _base_item("glasses_catalog_1", "accessory", "uncommon", false)
	glasses["instance_id"] = "owned_glasses_1"
	glasses["display_name"] = "Gold Aviator Glasses"
	glasses["image_path"] = "res://Resources/Items/accessory/glasses/uncommon/accessory_uncommon_gold_octagonal_sunglasses_011.png"
	var necklace := _base_item("necklace_catalog_1", "accessory", "epic", true)
	necklace["instance_id"] = "owned_necklace_1"
	necklace["display_name"] = "Royal Crystal Necklace"
	necklace["image_path"] = "res://Resources/Items/accessory/necklace/epic/accessory_epic_heirloom_gold_blue_laurel_necklace_035.png"
	necklace["diamond_price"] = 110
	var outfit := _base_item("outfit_catalog_1", "outfit", "rare", false)
	outfit["instance_id"] = "owned_outfit_1"
	outfit["display_name"] = "Navy Three Piece Suit"
	outfit["image_path"] = "res://Resources/Items/outfit/rare/outfit_rare_navy_three_piece_suit_030.png"
	var vehicle := _base_item("vehicle_catalog_1", "vehicle", "epic", false)
	vehicle["instance_id"] = "owned_vehicle_1"
	vehicle["display_name"] = "Electric Luxury Sedan"
	vehicle["image_path"] = "res://Resources/Items/vehicle/epic/vehicle_epic_silver_electric_luxury_sedan_036.png"

	var owned: Array = [ring_1, ring_2, watch_1, watch_2, glasses, necklace, outfit, vehicle]
	var shop: Array = []
	for item in owned:
		var stock_item := (item as Dictionary).duplicate(true)
		stock_item.erase("instance_id")
		stock_item["money_price"] = 12000
		if bool(stock_item.get("is_heirloom", false)):
			stock_item["money_price"] = 0
			stock_item["diamond_price"] = 110
		shop.append(stock_item)
	return {
		"equipped": {"accessory": watch_2, "outfit": outfit},
		"owned": owned,
		"shop": shop,
	}


func _base_item(item_id: String, slot: String, rarity: String, is_heirloom: bool) -> Dictionary:
	return {
		"item_id": item_id,
		"display_name": item_id.replace("_", " ").capitalize(),
		"slot": slot,
		"rarity": rarity,
		"lifestyle_value": 20,
		"money_price": 0,
		"diamond_price": 0,
		"is_heirloom": is_heirloom,
		"image_path": "",
	}


func _capture_action(character_id: int, item_reference: Variant, slot: String) -> void:
	action_character_id = character_id
	action_item_reference = item_reference
	action_slot = slot


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", test_name)
	else:
		failed += 1
		push_error("[FAIL] " + test_name)


func _assert_equal(actual: Variant, expected: Variant, test_name: String) -> void:
	_assert_true(actual == expected, "%s (expected %s, got %s)" % [test_name, str(expected), str(actual)])


func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (expected %s, got %s)" % [test_name, str(expected), str(actual)])
