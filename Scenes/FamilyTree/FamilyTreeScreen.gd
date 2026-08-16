extends Control
class_name FamilyTreeScreen

class ConnectorLayer:
	extends Control
	var segments: Array[PackedVector2Array] = []
	var line_color: Color = Color(1, 1, 1, 1)
	var line_width: float = 4.0

	func clear_segments() -> void:
		segments.clear()
		queue_redraw()

	func add_segment(from_point: Vector2, to_point: Vector2) -> void:
		var segment: PackedVector2Array = PackedVector2Array([from_point, to_point])
		segments.append(segment)
		queue_redraw()

	func _draw() -> void:
		for segment in segments:
			if segment.size() >= 2:
				draw_line(segment[0], segment[1], line_color, line_width, true)

class SoftRoundedShadow:
	extends Control
	var target_size: Vector2 = Vector2.ZERO
	var corner_radius: float = 0.0
	var blur_radius: float = 4.0
	var shadow_offset: Vector2 = Vector2.ZERO
	var shadow_opacity: float = 0.10

	func configure(
		new_size: Vector2,
		new_corner_radius: float,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		target_size = new_size
		corner_radius = new_corner_radius
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = target_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if target_size.x <= 0.0 or target_size.y <= 0.0:
			return

		var layer_count: int = maxi(6, int(ceil(blur_radius * 2.0)))
		var layer_alpha: float = shadow_opacity / float(layer_count)

		for layer_index in range(layer_count, 0, -1):
			var factor: float = float(layer_index) / float(layer_count)
			var spread: float = blur_radius * factor
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(0.0, 0.0, 0.0, layer_alpha)
			var radius: int = int(round(corner_radius + spread))
			style.corner_radius_top_left = radius
			style.corner_radius_top_right = radius
			style.corner_radius_bottom_left = radius
			style.corner_radius_bottom_right = radius
			style.anti_aliasing = true
			var shadow_rect: Rect2 = Rect2(
				shadow_offset - Vector2(spread, spread),
				target_size + Vector2(spread * 2.0, spread * 2.0)
			)
			draw_style_box(style, shadow_rect)

class SoftCircleShadow:
	extends Control
	var diameter: float = 44.0
	var blur_radius: float = 10.0
	var shadow_offset: Vector2 = Vector2(4.0, 4.0)
	var shadow_opacity: float = 0.25

	func configure(
		new_diameter: float,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		diameter = maxf(new_diameter, 1.0)
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = Vector2(diameter, diameter)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var base_radius: float = diameter * 0.5
		var center: Vector2 = Vector2(base_radius, base_radius) + shadow_offset
		var layer_count: int = maxi(10, int(ceil(blur_radius * 2.0)))

		for layer_index in range(layer_count, 0, -1):
			var t: float = float(layer_index) / float(layer_count)
			var spread: float = blur_radius * t
			var falloff: float = 1.0 - t
			var alpha: float = shadow_opacity * (0.018 + 0.055 * falloff * falloff)
			draw_circle(
				center,
				base_radius + spread,
				Color(0.0, 0.0, 0.0, alpha),
				true,
				-1.0,
				true
			)

class SoftTextureShadow:
	extends Control
	var shadow_texture: Texture2D
	var target_size: Vector2 = Vector2.ZERO
	var blur_radius: float = 4.0
	var shadow_offset: Vector2 = Vector2.ZERO
	var shadow_opacity: float = 0.10

	func configure(
		new_texture: Texture2D,
		new_size: Vector2,
		new_offset: Vector2,
		new_blur_radius: float,
		new_opacity: float
	) -> void:
		shadow_texture = new_texture
		target_size = new_size
		shadow_offset = new_offset
		blur_radius = maxf(new_blur_radius, 0.0)
		shadow_opacity = clampf(new_opacity, 0.0, 1.0)
		size = target_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if shadow_texture == null or target_size.x <= 0.0 or target_size.y <= 0.0:
			return

		var ring_count: int = maxi(2, int(ceil(blur_radius / 2.0)))
		var samples_per_ring: int = 12
		var sample_count: int = 1 + ring_count * samples_per_ring
		var sample_alpha: float = shadow_opacity / float(sample_count)
		var tint: Color = Color(0.0, 0.0, 0.0, sample_alpha)

		draw_texture_rect(
			shadow_texture,
			Rect2(shadow_offset, target_size),
			false,
			tint
		)

		for ring_index in range(1, ring_count + 1):
			var radius: float = blur_radius * float(ring_index) / float(ring_count)
			for sample_index in range(samples_per_ring):
				var angle: float = TAU * float(sample_index) / float(samples_per_ring)
				var sample_offset: Vector2 = shadow_offset + Vector2(cos(angle), sin(angle)) * radius
				draw_texture_rect(
					shadow_texture,
					Rect2(sample_offset, target_size),
					false,
					tint
				)

const FONT_OUTFIT_BOLD_PATHS: Array[String] = [
	"res://Resources/Fonts/Outfit-Bold.ttf",
	"res://Resources/Fonts/Outfit/static/Outfit-Bold.ttf",
	"res://Resources/Fonts/Outfit/Outfit-Bold.ttf"
]
const FONT_OUTFIT_SEMIBOLD_PATHS: Array[String] = [
	"res://Resources/Fonts/Outfit-SemiBold.ttf",
	"res://Resources/Fonts/Outfit/static/Outfit-SemiBold.ttf",
	"res://Resources/Fonts/Outfit/Outfit-SemiBold.ttf"
]
const FONT_BUENARD_BOLD_PATHS: Array[String] = [
	"res://Resources/Fonts/Buenard-Bold.ttf",
	"res://Resources/Fonts/Buenard/Buenard-Bold.ttf"
]

const FAMILY_BG_PATH := "res://Resources/Icons/main-ui/family-tree-background.svg"
const CENTER_TREE_PATH := "res://Resources/Icons/main-ui/tree-img.png"
const CALENDAR_PATH := "res://Resources/Icons/main-ui/calendar.svg"
const SHOP_BTN_PATH := "res://Resources/Icons/main-ui/shop-btn.svg"
const SETTINGS_BTN_PATH := "res://Resources/Icons/main-ui/settings-btn.svg"
const COIN_PATH := "res://Resources/Icons/main-ui/coin.png"
const DIAMOND_PATH := "res://Resources/Icons/main-ui/diamond.png"
const FAMILY_TREEO_LOGO_PATH := "res://Resources/Icons/main-ui/family-logo-tree.png"
const FAMILY_BOTTOM_LOGO_PATH := "res://Resources/Icons/main-ui/family-logo-bottom.svg"

const MALE_ICON_PATH := "res://Resources/Icons/character-portrait/male-icon.svg"
const FEMALE_ICON_PATH := "res://Resources/Icons/character-portrait/female-icon.svg"
const LINK_ICON_PATH := "res://Resources/Icons/character-portrait/link-icon.svg"

const TIME_BG_PATH := "res://Resources/Icons/time-control/time-control-bg.png"
const PAUSE_ACTIVE_PATH := "res://Resources/Icons/time-control/pause-btn.svg"
const PAUSE_INACTIVE_PATH := "res://Resources/Icons/time-control/pause-btn-deactive.svg"
const PLAY_ACTIVE_PATH := "res://Resources/Icons/time-control/play-btn.svg"
const PLAY_INACTIVE_PATH := "res://Resources/Icons/time-control/play-btn-deactive.svg"
const X2_ACTIVE_PATH := "res://Resources/Icons/time-control/x2-btn.svg"
const X2_INACTIVE_PATH := "res://Resources/Icons/time-control/x2-btn-deactive.svg"
const X3_ACTIVE_PATH := "res://Resources/Icons/time-control/x3-btn.svg"
const X3_INACTIVE_PATH := "res://Resources/Icons/time-control/x3-btn-deactive.svg"

const NAV_LIFESTYLE_ACTIVE_PATH := "res://Resources/Icons/nav/lifestyle-btn.webp"
const NAV_LIFESTYLE_INACTIVE_PATH := "res://Resources/Icons/nav/lifestyle-btn-deact.webp"
const NAV_FAMILY_TREE_ACTIVE_PATH := "res://Resources/Icons/nav/fam-tree-btn.webp"
const NAV_FAMILY_TREE_INACTIVE_PATH := "res://Resources/Icons/nav/fam-tree-btn-deact.webp"
const NAV_MAP_ACTIVE_PATH := "res://Resources/Icons/nav/map-btn.webp"
const NAV_MAP_INACTIVE_PATH := "res://Resources/Icons/nav/map-btn-deact.webp"

const CANVAS_SIZE := Vector2(1080.0, 1920.0)
const DEFAULT_CONTENT_SIZE := Vector2(1600.0, 2400.0)
const TOP_MARGIN := 34.0
const SIDE_MARGIN := 36.0
const NAV_BOTTOM_MARGIN := 44.0
const TIME_CONTROL_BOTTOM_MARGIN := 300.0
const SHOP_SETTINGS_GAP := 32.0
const BUTTON_LABEL_GAP := 8.0
const NAME_CARD_SIZE := Vector2(170.0, 70.0)
const PORTRAIT_SIZE := Vector2(180.0, 180.0)
const GENDER_ICON_SIZE := Vector2(44.0, 44.0)
const AGE_BADGE_MIN_SIZE := Vector2(44.0, 44.0)
const NAME_SALARY_GAP := 0.0
const FAMILY_TREE_GAP_DEFAULT := 140.0
const DEFAULT_VIEW_Y := 60.0
const CONNECTOR_COLOR := Color(1, 1, 1, 0.95)
const DEMO_MALE_PORTRAIT_PATH := "res://Resources/Characters/man/mixed/01.png"
const DEMO_FEMALE_PORTRAIT_PATH := "res://Resources/Characters/woman/light/01.png"

@export var family_name: String = "JOHNSON"
@export var date_text: String = "26 Jan 1985"
@export var coin_text: String = "999M"
@export var diamond_text: String = "50"
@export_range(0.5, 2.0, 0.01) var min_zoom: float = 0.9
@export_range(0.5, 2.0, 0.01) var max_zoom: float = 1.2
@export_range(0.5, 2.0, 0.01) var default_zoom: float = 1.0
@export var family_logo_tree_gap: float = FAMILY_TREE_GAP_DEFAULT
@export_enum("normal", "divorce", "remarriage", "distant_relative") var demo_scenario: String = "normal"

@export var portrait_parent_left: Texture2D
@export var portrait_parent_right: Texture2D
@export var portrait_child_left: Texture2D
@export var portrait_child_right: Texture2D

var outfit_bold: FontFile
var outfit_semibold: FontFile
var buenard_bold: FontFile

var background_rect: TextureRect
var center_tree_rect: TextureRect
var interaction_layer: Control
var fixed_ui_layer: Control
var movable_content: Control
var family_logo_root: Control
var tree_graph: Control
var connector_layer: ConnectorLayer

var date_pill: PanelContainer
var shop_block: Control
var settings_block: Control
var coin_pill: PanelContainer
var diamond_pill: PanelContainer
var time_control_root: Control
var nav_root: Control

var pause_button: TextureButton
var play_button: TextureButton
var x2_button: TextureButton
var x3_button: TextureButton

var mouse_dragging: bool = false
var drag_last_position: Vector2 = Vector2.ZERO
var active_touches: Dictionary = {}
var last_pinch_distance: float = 0.0
var current_zoom: float = 1.0
var active_speed: String = "play"

var member_cards: Dictionary = {}
var demo_members: Array[Dictionary] = []
var demo_link_nodes: Array[Dictionary] = []
var link_node_controls: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = CANVAS_SIZE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_fonts()
	_prepare_demo_members()
	_build_scene()
	await get_tree().process_frame
	_update_root_layout()
	_set_zoom(default_zoom)
	_build_connectors()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_update_root_layout()

func _load_fonts() -> void:
	outfit_bold = _load_first_existing_font(FONT_OUTFIT_BOLD_PATHS)
	outfit_semibold = _load_first_existing_font(FONT_OUTFIT_SEMIBOLD_PATHS)
	buenard_bold = _load_first_existing_font(FONT_BUENARD_BOLD_PATHS)

func _prepare_demo_members() -> void:
	member_cards.clear()
	link_node_controls.clear()
	demo_members.clear()
	demo_link_nodes.clear()

	var male_portrait: Texture2D = portrait_parent_left
	if male_portrait == null:
		male_portrait = _load_texture(DEMO_MALE_PORTRAIT_PATH)
	var female_portrait: Texture2D = portrait_parent_right
	if female_portrait == null:
		female_portrait = _load_texture(DEMO_FEMALE_PORTRAIT_PATH)
	var male_child_portrait: Texture2D = portrait_child_left
	if male_child_portrait == null:
		male_child_portrait = male_portrait
	var female_child_portrait: Texture2D = portrait_child_right
	if female_child_portrait == null:
		female_child_portrait = female_portrait

	match demo_scenario:
		"divorce":
			demo_members = [
				_member_data("parent_main", "William", 27, "male", "+2,500/mo", Color("#047D48"), male_portrait, Vector2(505, 0), false),
				_member_data("child_left", "Sean", 2, "male", "-1500/mo", Color("#E8403E"), male_child_portrait, Vector2(250, 470), false),
				_member_data("child_right", "Lisa", 6, "female", "-2860/mo", Color("#E8403E"), female_child_portrait, Vector2(760, 470), false)
			]
			demo_link_nodes = [
				{"id": "ex_spouse_link", "character_id": 202, "position": Vector2(578, 310)}
			]
		"remarriage":
			demo_members = [
				_member_data("old_parent", "William", 31, "male", "+3,100/mo", Color("#047D48"), male_portrait, Vector2(180, 20), false),
				_member_data("old_child", "Sean", 6, "male", "-1500/mo", Color("#E8403E"), male_child_portrait, Vector2(180, 520), false),
				_member_data("new_partner", "Michael", 30, "male", "+4,200/mo", Color("#047D48"), male_portrait, Vector2(650, 20), false),
				_member_data("returning_ex", "Emma", 31, "female", "+25k/mo", Color("#047D48"), female_portrait, Vector2(840, 20), true),
				_member_data("new_child", "Mia", 2, "female", "-1900/mo", Color("#E8403E"), female_child_portrait, Vector2(745, 520), false)
			]
			demo_link_nodes = [
				{"id": "old_ex_link", "character_id": 202, "position": Vector2(253, 334)}
			]
		"distant_relative":
			demo_members = [
				_member_data("alice", "Alice", 28, "female", "+4,000/mo", Color("#047D48"), female_portrait, Vector2(350, 270), false),
				_member_data("bob_reference", "Bob", 29, "male", "+3,600/mo", Color("#047D48"), male_portrait, Vector2(540, 270), true),
				_member_data("bob_canonical", "Bob", 29, "male", "+3,600/mo", Color("#047D48"), male_portrait, Vector2(920, 0), false),
				_member_data("child_left", "Noah", 4, "male", "-1750/mo", Color("#E8403E"), male_child_portrait, Vector2(260, 650), false),
				_member_data("child_right", "Lily", 2, "female", "-1850/mo", Color("#E8403E"), female_child_portrait, Vector2(650, 650), false)
			]
		_:
			demo_members = [
				_member_data("parent_left", "William", 27, "male", "+2,500/mo", Color("#047D48"), male_portrait, Vector2(420, 0), false),
				_member_data("parent_right", "Emma", 27, "female", "+25k/mo", Color("#047D48"), female_portrait, Vector2(610, 0), false),
				_member_data("child_left", "Sean", 2, "male", "-1500/mo", Color("#E8403E"), male_child_portrait, Vector2(190, 390), false),
				_member_data("child_right", "Lisa", 6, "female", "-2860/mo", Color("#E8403E"), female_child_portrait, Vector2(840, 390), false)
			]

func _member_data(
	id_value: String,
	name_value: String,
	age_value: int,
	gender_value: String,
	money_text_value: String,
	money_color_value: Color,
	portrait_value: Texture2D,
	position_value: Vector2,
	show_link_icon_value: bool
) -> Dictionary:
	return {
		"id": id_value,
		"name": name_value,
		"age": age_value,
		"gender": gender_value,
		"money_text": money_text_value,
		"money_color": money_color_value,
		"portrait": portrait_value,
		"placeholder_color": Color("#DCDCEC"),
		"position": position_value,
		"show_link_icon": show_link_icon_value
	}

func _build_scene() -> void:
	background_rect = TextureRect.new()
	background_rect.name = "Background"
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	background_rect.texture = _load_texture(FAMILY_BG_PATH)
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_rect)

	center_tree_rect = TextureRect.new()
	center_tree_rect.name = "CenterTreeImage"
	center_tree_rect.texture = _load_texture(CENTER_TREE_PATH)
	center_tree_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	center_tree_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center_tree_rect.modulate = Color.WHITE
	center_tree_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_tree_rect)

	interaction_layer = Control.new()
	interaction_layer.name = "InteractionLayer"
	interaction_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	interaction_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(interaction_layer)

	movable_content = Control.new()
	movable_content.name = "MovableContent"
	movable_content.custom_minimum_size = DEFAULT_CONTENT_SIZE
	movable_content.size = DEFAULT_CONTENT_SIZE
	movable_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_layer.add_child(movable_content)

	_build_movable_content()

	fixed_ui_layer = Control.new()
	fixed_ui_layer.name = "FixedUILayer"
	fixed_ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fixed_ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fixed_ui_layer)

	_build_fixed_ui()

func _build_fixed_ui() -> void:
	date_pill = _create_info_pill(CALENDAR_PATH, date_text)
	date_pill.name = "DatePill"
	fixed_ui_layer.add_child(date_pill)

	shop_block = _create_vertical_icon_button(SHOP_BTN_PATH, "SHOP")
	shop_block.name = "ShopBlock"
	fixed_ui_layer.add_child(shop_block)

	settings_block = _create_vertical_icon_button(SETTINGS_BTN_PATH, "SETTINGS")
	settings_block.name = "SettingsBlock"
	fixed_ui_layer.add_child(settings_block)

	coin_pill = _create_info_pill(COIN_PATH, coin_text)
	coin_pill.name = "CoinPill"
	fixed_ui_layer.add_child(coin_pill)

	diamond_pill = _create_info_pill(DIAMOND_PATH, diamond_text)
	diamond_pill.name = "DiamondPill"
	fixed_ui_layer.add_child(diamond_pill)

	time_control_root = _create_time_controls()
	time_control_root.name = "TimeControls"
	fixed_ui_layer.add_child(time_control_root)

	nav_root = _create_nav_bar()
	nav_root.name = "BottomNav"
	fixed_ui_layer.add_child(nav_root)

func _build_movable_content() -> void:
	family_logo_root = _create_family_logo()
	family_logo_root.name = "FamilyLogo"
	family_logo_root.position = Vector2((DEFAULT_CONTENT_SIZE.x - family_logo_root.size.x) * 0.5, 120)
	family_logo_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movable_content.add_child(family_logo_root)

	_build_tree_graph()

func _build_tree_graph() -> void:
	if tree_graph != null and is_instance_valid(tree_graph):
		tree_graph.queue_free()
		await get_tree().process_frame

	member_cards.clear()
	link_node_controls.clear()
	tree_graph = Control.new()
	tree_graph.name = "TreeGraph"
	tree_graph.custom_minimum_size = Vector2(1200, 1000)
	tree_graph.size = tree_graph.custom_minimum_size
	tree_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_graph.position = Vector2(
		(DEFAULT_CONTENT_SIZE.x - tree_graph.size.x) * 0.5,
		family_logo_root.position.y + family_logo_root.size.y + family_logo_tree_gap
	)
	movable_content.add_child(tree_graph)

	connector_layer = ConnectorLayer.new()
	connector_layer.name = "ConnectorLayer"
	connector_layer.line_color = CONNECTOR_COLOR
	connector_layer.line_width = 4.0
	connector_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	connector_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_graph.add_child(connector_layer)

	for member_data in demo_members:
		var card: Control = _create_member_card(member_data)
		card.position = member_data["position"]
		card.name = str(member_data["id"])
		tree_graph.add_child(card)
		member_cards[member_data["id"]] = card

	for link_data in demo_link_nodes:
		var link_control: Control = _create_link_node(int(link_data.get("character_id", 0)))
		link_control.position = link_data["position"]
		link_control.name = str(link_data["id"])
		tree_graph.add_child(link_control)
		link_node_controls[link_data["id"]] = link_control

	await get_tree().process_frame
	_build_connectors()

func _build_connectors() -> void:
	if connector_layer == null:
		return
	connector_layer.clear_segments()

	match demo_scenario:
		"divorce":
			_build_divorce_connectors()
		"remarriage":
			_build_remarriage_connectors()
		"distant_relative":
			_build_distant_relative_connectors()
		_:
			_build_normal_connectors()

func _build_normal_connectors() -> void:
	var left: Control = member_cards.get("parent_left")
	var right: Control = member_cards.get("parent_right")
	var child_left: Control = member_cards.get("child_left")
	var child_right: Control = member_cards.get("child_right")
	if left == null or right == null or child_left == null or child_right == null:
		return
	var left_anchor: Vector2 = left.position + Vector2(185, 90)
	var right_anchor: Vector2 = right.position + Vector2(5, 90)
	var union: Vector2 = (left_anchor + right_anchor) * 0.5
	var branch_y: float = 315.0
	_draw_union_with_children(left_anchor, right_anchor, union, branch_y, [child_left, child_right])

func _build_divorce_connectors() -> void:
	var parent: Control = member_cards.get("parent_main")
	var child_left: Control = member_cards.get("child_left")
	var child_right: Control = member_cards.get("child_right")
	var link_node: Control = link_node_controls.get("ex_spouse_link")
	if parent == null or child_left == null or child_right == null or link_node == null:
		return
	var parent_anchor: Vector2 = parent.position + Vector2(95, 180)
	var link_center: Vector2 = link_node.position + GENDER_ICON_SIZE * 0.5
	var branch_y: float = 405.0
	connector_layer.add_segment(parent_anchor, link_center)
	connector_layer.add_segment(link_center, Vector2(link_center.x, branch_y))
	_draw_children_branch(Vector2(link_center.x, branch_y), branch_y, [child_left, child_right])

func _build_remarriage_connectors() -> void:
	var old_parent: Control = member_cards.get("old_parent")
	var old_child: Control = member_cards.get("old_child")
	var old_link: Control = link_node_controls.get("old_ex_link")
	if old_parent != null and old_child != null and old_link != null:
		var old_parent_anchor: Vector2 = old_parent.position + Vector2(95, 180)
		var old_link_center: Vector2 = old_link.position + GENDER_ICON_SIZE * 0.5
		connector_layer.add_segment(old_parent_anchor, old_link_center)
		connector_layer.add_segment(old_link_center, Vector2(old_link_center.x, 465))
		connector_layer.add_segment(Vector2(old_link_center.x, 465), old_child.position + Vector2(95, 0))

	var new_partner: Control = member_cards.get("new_partner")
	var returning_ex: Control = member_cards.get("returning_ex")
	var new_child: Control = member_cards.get("new_child")
	if new_partner == null or returning_ex == null or new_child == null:
		return
	var left_anchor: Vector2 = new_partner.position + Vector2(185, 90)
	var right_anchor: Vector2 = returning_ex.position + Vector2(5, 90)
	var union: Vector2 = (left_anchor + right_anchor) * 0.5
	connector_layer.add_segment(left_anchor, right_anchor)
	connector_layer.add_segment(union, Vector2(union.x, 465))
	connector_layer.add_segment(Vector2(union.x, 465), new_child.position + Vector2(95, 0))

func _build_distant_relative_connectors() -> void:
	var alice: Control = member_cards.get("alice")
	var bob_reference: Control = member_cards.get("bob_reference")
	var child_left: Control = member_cards.get("child_left")
	var child_right: Control = member_cards.get("child_right")
	if alice == null or bob_reference == null or child_left == null or child_right == null:
		return
	var left_anchor: Vector2 = alice.position + Vector2(185, 90)
	var right_anchor: Vector2 = bob_reference.position + Vector2(5, 90)
	var union: Vector2 = (left_anchor + right_anchor) * 0.5
	var branch_y: float = 585.0
	_draw_union_with_children(left_anchor, right_anchor, union, branch_y, [child_left, child_right])

func _draw_union_with_children(
	left_anchor: Vector2,
	right_anchor: Vector2,
	union: Vector2,
	branch_y: float,
	children: Array
) -> void:
	connector_layer.add_segment(left_anchor, right_anchor)
	connector_layer.add_segment(union, Vector2(union.x, branch_y))
	_draw_children_branch(Vector2(union.x, branch_y), branch_y, children)

func _draw_children_branch(union_point: Vector2, branch_y: float, children: Array) -> void:
	if children.is_empty():
		return
	var child_x_values: Array[float] = []
	for child_value in children:
		var child: Control = child_value
		child_x_values.append(child.position.x + 95.0)
	child_x_values.sort()
	var min_x: float = child_x_values[0]
	var max_x: float = child_x_values[child_x_values.size() - 1]
	connector_layer.add_segment(Vector2(min_x, branch_y), Vector2(max_x, branch_y))
	for child_value in children:
		var child: Control = child_value
		var child_top: Vector2 = child.position + Vector2(95, 0)
		connector_layer.add_segment(Vector2(child_top.x, branch_y), child_top)

func _create_link_node(linked_character_id: int) -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = GENDER_ICON_SIZE
	root.size = GENDER_ICON_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("linked_character_id", linked_character_id)
	var icon: TextureRect = _create_shadowed_icon(
		LINK_ICON_PATH,
		GENDER_ICON_SIZE,
		Vector2(-4, 4),
		10,
		Color(0, 0, 0, 0.25)
	)
	root.add_child(icon)
	return root

func _create_member_card(data: Dictionary) -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = Vector2(190, 270)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait_texture: Texture2D = data.get("portrait")
	if portrait_texture != null:
		_add_soft_texture_shadow(
			root,
			portrait_texture,
			Vector2(5, 0),
			PORTRAIT_SIZE,
			Vector2(0, 4),
			4.0,
			0.10
		)
	else:
		_add_soft_rounded_shadow(
			root,
			Vector2(5, 0),
			PORTRAIT_SIZE,
			90.0,
			Vector2(0, 4),
			4.0,
			0.10
		)

	var portrait_holder: Control = Control.new()
	portrait_holder.position = Vector2(5, 0)
	portrait_holder.size = PORTRAIT_SIZE
	root.add_child(portrait_holder)

	if portrait_texture != null:
		var portrait_rect: TextureRect = TextureRect.new()
		portrait_rect.texture = portrait_texture
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
		portrait_rect.size = PORTRAIT_SIZE
		portrait_holder.add_child(portrait_rect)
	else:
		var portrait_placeholder: Panel = Panel.new()
		portrait_placeholder.size = PORTRAIT_SIZE
		portrait_placeholder.add_theme_stylebox_override("panel", _make_stylebox(Color(data.get("placeholder_color", Color("#DCDCEC"))), 90.0, Color.TRANSPARENT, Vector2.ZERO, 0))
		portrait_holder.add_child(portrait_placeholder)

	_add_soft_circle_shadow(
		root,
		Vector2(0, -4),
		AGE_BADGE_MIN_SIZE.x,
		Vector2(4, 4),
		10.0,
		0.25
	)

	var age_badge: Panel = Panel.new()
	age_badge.position = Vector2(0, -4)
	age_badge.size = AGE_BADGE_MIN_SIZE
	age_badge.add_theme_stylebox_override("panel", _make_stylebox(Color.WHITE, 22.0, Color.TRANSPARENT, Vector2.ZERO, 0))
	root.add_child(age_badge)

	var age_label: Label = Label.new()
	age_label.text = str(data.get("age", 0))
	age_label.position = Vector2.ZERO
	age_label.size = AGE_BADGE_MIN_SIZE
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	age_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	age_label.add_theme_font_size_override("font_size", 24)
	if outfit_bold != null:
		age_label.add_theme_font_override("font", outfit_bold)
	age_label.add_theme_color_override("font_color", Color("#312F60"))
	age_badge.add_child(age_label)

	var gender_icon: TextureRect = _create_shadowed_icon(_get_gender_icon_path(str(data.get("gender", "male"))), GENDER_ICON_SIZE, Vector2(-4, -4), 10, Color(0, 0, 0, 0.25))
	gender_icon.position = Vector2(146, 136)
	root.add_child(gender_icon)

	if bool(data.get("show_link_icon", false)):
		var link_icon: TextureRect = _create_shadowed_icon(LINK_ICON_PATH, GENDER_ICON_SIZE, Vector2(-4, 4), 10, Color(0, 0, 0, 0.25))
		link_icon.position = Vector2(146, -4)
		root.add_child(link_icon)

	_add_soft_rounded_shadow(
		root,
		Vector2(10, 190),
		NAME_CARD_SIZE,
		35.0,
		Vector2(0, 4),
		8.0,
		0.10
	)

	var info_panel: Panel = Panel.new()
	info_panel.position = Vector2(10, 190)
	info_panel.size = NAME_CARD_SIZE
	info_panel.add_theme_stylebox_override("panel", _make_stylebox(Color.WHITE, 35.0, Color.TRANSPARENT, Vector2.ZERO, 0))
	root.add_child(info_panel)

	var name_label: Label = Label.new()
	name_label.text = str(data.get("name", ""))
	name_label.position = Vector2(0, 4)
	name_label.size = Vector2(NAME_CARD_SIZE.x, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	if outfit_semibold != null:
		name_label.add_theme_font_override("font", outfit_semibold)
	name_label.add_theme_color_override("font_color", Color("#312F60"))
	info_panel.add_child(name_label)

	var money_label: Label = Label.new()
	money_label.text = str(data.get("money_text", ""))
	money_label.position = Vector2(0, 28)
	money_label.size = Vector2(NAME_CARD_SIZE.x, 36)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 24)
	if outfit_semibold != null:
		money_label.add_theme_font_override("font", outfit_semibold)
	money_label.add_theme_color_override("font_color", data.get("money_color", Color("#047D48")))
	info_panel.add_child(money_label)

	_set_visual_subtree_mouse_ignore(root)
	return root

func _create_family_logo() -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = Vector2(560, 190)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tree_texture: Texture2D = _load_texture(FAMILY_TREEO_LOGO_PATH)
	var tree_size: Vector2 = Vector2(80, 80)
	if tree_texture != null:
		tree_size = tree_texture.get_size()
	var tree_logo: TextureRect = TextureRect.new()
	tree_logo.texture = tree_texture
	tree_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tree_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tree_logo.position = Vector2((root.size.x - tree_size.x) * 0.5, 0)
	tree_logo.size = tree_size
	tree_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tree_logo)

	var family_name_label: Label = Label.new()
	family_name_label.text = family_name
	family_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	family_name_label.position = Vector2(0, 74)
	family_name_label.size = Vector2(root.size.x, 62)
	family_name_label.add_theme_font_size_override("font_size", 55)
	if buenard_bold != null:
		family_name_label.add_theme_font_override("font", buenard_bold)
	family_name_label.add_theme_color_override("font_color", Color("#063166"))
	family_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(family_name_label)

	var bottom_texture: Texture2D = _load_texture(FAMILY_BOTTOM_LOGO_PATH)
	var bottom_size: Vector2 = Vector2(333, 33)
	if bottom_texture != null:
		bottom_size = bottom_texture.get_size()
	var bottom_logo: TextureRect = TextureRect.new()
	bottom_logo.texture = bottom_texture
	bottom_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bottom_logo.position = Vector2((root.size.x - bottom_size.x) * 0.5, 138)
	bottom_logo.size = bottom_size
	bottom_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_logo)

	return root

func _create_info_pill(icon_path: String, text_value: String) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _make_stylebox(Color("#EBF5EF"), 48.0, Color(0, 0, 0, 0.10), Vector2(0, 4), 4))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	pill.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	var icon: TextureRect = TextureRect.new()
	var icon_texture: Texture2D = _load_texture(icon_path)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var info_icon_size: Vector2 = Vector2(36, 40)
	if icon_texture != null:
		info_icon_size = icon_texture.get_size()
	icon.custom_minimum_size = info_icon_size
	icon.size = info_icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 36)
	if outfit_bold != null:
		label.add_theme_font_override("font", outfit_bold)
	label.add_theme_color_override("font_color", Color("#312F60"))
	hbox.add_child(label)

	return pill

func _create_vertical_icon_button(texture_path: String, caption: String) -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = Vector2(112, 116)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_resource: Texture2D = _load_texture(texture_path)
	var icon_size: Vector2 = Vector2(84, 84)
	if texture_resource != null:
		icon_size = texture_resource.get_size()

	var shadow: TextureRect = TextureRect.new()
	shadow.texture = texture_resource
	shadow.position = Vector2((root.size.x - icon_size.x) * 0.5, 4)
	shadow.size = icon_size
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.modulate = Color(0, 0, 0, 0.10)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	var button_texture: TextureButton = TextureButton.new()
	button_texture.texture_normal = texture_resource
	button_texture.texture_pressed = texture_resource
	button_texture.texture_hover = texture_resource
	button_texture.texture_disabled = texture_resource
	button_texture.position = Vector2((root.size.x - icon_size.x) * 0.5, 0)
	button_texture.size = icon_size
	button_texture.ignore_texture_size = true
	button_texture.stretch_mode = TextureButton.STRETCH_SCALE
	button_texture.focus_mode = Control.FOCUS_NONE
	root.add_child(button_texture)

	var label: Label = Label.new()
	label.text = caption
	label.position = Vector2(0, icon_size.y + BUTTON_LABEL_GAP)
	label.size = Vector2(root.size.x, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	if outfit_semibold != null:
		label.add_theme_font_override("font", outfit_semibold)
	label.add_theme_color_override("font_color", Color("#454698"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

	return root

func _create_time_controls() -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = Vector2(456, 120)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_texture_resource: Texture2D = _load_texture(TIME_BG_PATH)
	var bg_shadow: TextureRect = TextureRect.new()
	bg_shadow.texture = bg_texture_resource
	bg_shadow.position = Vector2(0, 4)
	bg_shadow.size = root.size
	bg_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	bg_shadow.modulate = Color(0, 0, 0, 0.10)
	bg_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_shadow)

	var bg_texture: TextureRect = TextureRect.new()
	bg_texture.texture = bg_texture_resource
	bg_texture.size = root.size
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
	bg_texture.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg_texture)

	pause_button = _create_time_button(PAUSE_ACTIVE_PATH, PAUSE_INACTIVE_PATH, "pause")
	play_button = _create_time_button(PLAY_ACTIVE_PATH, PLAY_INACTIVE_PATH, "play")
	x2_button = _create_time_button(X2_ACTIVE_PATH, X2_INACTIVE_PATH, "x2")
	x3_button = _create_time_button(X3_ACTIVE_PATH, X3_INACTIVE_PATH, "x3")
	var buttons: Array[TextureButton] = [pause_button, play_button, x2_button, x3_button]

	var button_size: float = 90.0
	var gap: float = 16.0
	var start_x: float = 24.0
	for i in range(buttons.size()):
		var button: TextureButton = buttons[i]
		button.position = Vector2(start_x + float(i) * (button_size + gap), 15.0)
		root.add_child(button)

	_update_time_button_visuals()
	return root

func _create_time_button(active_path: String, inactive_path: String, speed_key: String) -> TextureButton:
	var button: TextureButton = TextureButton.new()
	button.set_meta("active_path", active_path)
	button.set_meta("inactive_path", inactive_path)
	button.set_meta("speed_key", speed_key)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.size = Vector2(90, 90)
	button.focus_mode = Control.FOCUS_NONE

	var shadow: TextureRect = TextureRect.new()
	shadow.name = "DropShadow"
	shadow.show_behind_parent = true
	shadow.position = Vector2(-2, 1)
	shadow.size = Vector2(94, 94)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.modulate = Color(0, 0, 0, 0.20)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shadow)

	button.pressed.connect(_on_time_button_pressed.bind(button))
	return button

func _create_nav_bar() -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = Vector2(800, 144)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background: Panel = Panel.new()
	background.size = root.size
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(1, 1, 1, 0.70),
			72.0,
			Color(0, 0, 0, 0.10),
			Vector2(0, 16),
			32
		)
	)
	root.add_child(background)

	var entries: Array[Dictionary] = [
		{
			"label": "LIFESTYLE",
			"active": false,
			"active_path": NAV_LIFESTYLE_ACTIVE_PATH,
			"inactive_path": NAV_LIFESTYLE_INACTIVE_PATH
		},
		{
			"label": "FAMILY TREE",
			"active": true,
			"active_path": NAV_FAMILY_TREE_ACTIVE_PATH,
			"inactive_path": NAV_FAMILY_TREE_INACTIVE_PATH
		},
		{
			"label": "MAP",
			"active": false,
			"active_path": NAV_MAP_ACTIVE_PATH,
			"inactive_path": NAV_MAP_INACTIVE_PATH
		}
	]

	var section_width: float = root.size.x / 3.0
	var label_height: float = 30.0
	var label_bottom: float = root.size.y - 20.0
	var label_top: float = label_bottom - label_height
	var icon_bottom: float = label_top - BUTTON_LABEL_GAP

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var is_active: bool = bool(entry["active"])

		var item: Control = Control.new()
		item.position = Vector2(section_width * float(i), 0)
		item.size = Vector2(section_width, root.size.y)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(item)

		var texture_path: String = str(
			entry["active_path"] if is_active else entry["inactive_path"]
		)
		var texture_resource: Texture2D = _load_texture(texture_path)
		var icon_size: Vector2 = Vector2(132, 132) if is_active else Vector2(110, 110)
		var icon_position: Vector2 = Vector2(
			(section_width - icon_size.x) * 0.5,
			icon_bottom - icon_size.y
		)

		if not is_active and texture_resource != null:
			_add_soft_texture_shadow(
				item,
				texture_resource,
				icon_position,
				icon_size,
				Vector2(0, 4),
				4.0,
				0.10
			)

		var icon: TextureRect = TextureRect.new()
		icon.texture = texture_resource
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = icon_size
		icon.position = icon_position
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)

		var label: Label = Label.new()
		label.text = str(entry["label"])
		label.position = Vector2(0, label_top)
		label.size = Vector2(section_width, label_height)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		if outfit_semibold != null:
			label.add_theme_font_override("font", outfit_semibold)
		label.add_theme_color_override(
			"font_color",
			Color("#3528BD") if is_active else Color("#454698")
		)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)

	return root

func _create_shadowed_icon(texture_path: String, icon_size: Vector2, shadow_offset: Vector2, shadow_size: int, shadow_color: Color) -> TextureRect:
	var root: TextureRect = TextureRect.new()
	root.custom_minimum_size = icon_size
	root.size = icon_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_texture: Texture2D = _load_texture(texture_path)
	var soft_shadow: SoftTextureShadow = SoftTextureShadow.new()
	soft_shadow.configure(
		icon_texture,
		icon_size,
		shadow_offset,
		float(shadow_size),
		shadow_color.a
	)
	root.add_child(soft_shadow)

	var icon: TextureRect = TextureRect.new()
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	return root

func _set_visual_subtree_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_visual_subtree_mouse_ignore(child)

func _add_soft_circle_shadow(
	parent: Control,
	shadow_position: Vector2,
	diameter: float,
	shadow_offset: Vector2,
	blur_radius: float,
	opacity: float
) -> SoftCircleShadow:
	var shadow: SoftCircleShadow = SoftCircleShadow.new()
	shadow.position = shadow_position
	shadow.configure(
		diameter,
		shadow_offset,
		blur_radius,
		opacity
	)
	parent.add_child(shadow)
	return shadow

func _add_soft_rounded_shadow(
	parent: Control,
	shadow_position: Vector2,
	shadow_size: Vector2,
	corner_radius: float,
	shadow_offset: Vector2,
	blur_radius: float,
	opacity: float
) -> SoftRoundedShadow:
	var shadow: SoftRoundedShadow = SoftRoundedShadow.new()
	shadow.position = shadow_position
	shadow.configure(
		shadow_size,
		corner_radius,
		shadow_offset,
		blur_radius,
		opacity
	)
	parent.add_child(shadow)
	return shadow

func _add_soft_texture_shadow(
	parent: Control,
	texture: Texture2D,
	shadow_position: Vector2,
	shadow_size: Vector2,
	shadow_offset: Vector2,
	blur_radius: float,
	opacity: float
) -> SoftTextureShadow:
	var shadow: SoftTextureShadow = SoftTextureShadow.new()
	shadow.position = shadow_position
	shadow.configure(
		texture,
		shadow_size,
		shadow_offset,
		blur_radius,
		opacity
	)
	parent.add_child(shadow)
	return shadow

func _make_stylebox(bg_color: Color, radius: float, shadow_color: Color, shadow_offset: Vector2, shadow_size: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.shadow_color = shadow_color
	style.shadow_offset = shadow_offset
	style.shadow_size = shadow_size
	return style

func _make_shadow_only_style(shadow_color: Color, shadow_offset: Vector2, shadow_size: int, radius: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.001)
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.shadow_color = shadow_color
	style.shadow_offset = shadow_offset
	style.shadow_size = shadow_size
	return style

func _on_time_button_pressed(button: TextureButton) -> void:
	active_speed = str(button.get_meta("speed_key", "play"))
	_update_time_button_visuals()

func _update_time_button_visuals() -> void:
	var buttons: Array[TextureButton] = [pause_button, play_button, x2_button, x3_button]
	for button in buttons:
		if button == null:
			continue
		var speed_key: String = str(button.get_meta("speed_key", ""))
		var is_active: bool = speed_key == active_speed
		var texture_path: String = str(button.get_meta("active_path", "")) if is_active else str(button.get_meta("inactive_path", ""))
		var texture_res: Texture2D = _load_texture(texture_path)
		button.texture_normal = texture_res
		button.texture_pressed = texture_res
		button.texture_hover = texture_res
		button.texture_disabled = texture_res
		var shadow_node: TextureRect = button.get_node_or_null("DropShadow") as TextureRect
		if shadow_node != null:
			shadow_node.texture = texture_res

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touches[event.index] = event.position
	else:
		active_touches.erase(event.index)
	if active_touches.size() == 2:
		last_pinch_distance = _get_current_pinch_distance()
	else:
		last_pinch_distance = 0.0

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	active_touches[event.index] = event.position
	if active_touches.size() == 1:
		movable_content.position += event.relative
		_clamp_movable_content()
		return
	if active_touches.size() != 2:
		return
	var current_distance: float = _get_current_pinch_distance()
	if last_pinch_distance <= 0.0 or current_distance <= 0.0:
		last_pinch_distance = current_distance
		return
	var factor: float = current_distance / last_pinch_distance
	_set_zoom_at(current_zoom * factor, _get_current_pinch_center())
	last_pinch_distance = current_distance

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_dragging = event.pressed
		drag_last_position = event.position
		return
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom_at(current_zoom + 0.05, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom_at(current_zoom - 0.05, event.position)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not mouse_dragging:
		return
	movable_content.position += event.relative
	drag_last_position = event.position
	_clamp_movable_content()

func _get_current_pinch_distance() -> float:
	if active_touches.size() != 2:
		return 0.0
	var values: Array = active_touches.values()
	var first: Vector2 = values[0]
	var second: Vector2 = values[1]
	return first.distance_to(second)

func _get_current_pinch_center() -> Vector2:
	if active_touches.size() != 2:
		return size * 0.5
	var values: Array = active_touches.values()
	var first: Vector2 = values[0]
	var second: Vector2 = values[1]
	return (first + second) * 0.5

func _set_zoom(new_zoom: float) -> void:
	_set_zoom_at(new_zoom, size * 0.5)

func _set_zoom_at(new_zoom: float, screen_anchor: Vector2) -> void:
	if movable_content == null:
		return
	var old_zoom: float = maxf(current_zoom, 0.001)
	var clamped_zoom: float = clampf(new_zoom, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, clamped_zoom):
		return
	var local_anchor: Vector2 = (screen_anchor - movable_content.position) / old_zoom
	current_zoom = clamped_zoom
	movable_content.scale = Vector2(current_zoom, current_zoom)
	movable_content.position = screen_anchor - local_anchor * current_zoom
	_clamp_movable_content()

func _clamp_movable_content() -> void:
	if movable_content == null or interaction_layer == null:
		return
	var viewport_size: Vector2 = interaction_layer.size
	var scaled_size: Vector2 = movable_content.size * current_zoom
	var edge_margin: float = 100.0

	var min_x: float
	var max_x: float
	if scaled_size.x <= viewport_size.x:
		min_x = (viewport_size.x - scaled_size.x) * 0.5
		max_x = min_x
	else:
		min_x = viewport_size.x - scaled_size.x - edge_margin
		max_x = edge_margin

	var min_y: float
	var max_y: float
	if scaled_size.y <= viewport_size.y:
		min_y = (viewport_size.y - scaled_size.y) * 0.5
		max_y = min_y
	else:
		min_y = viewport_size.y - scaled_size.y - edge_margin
		max_y = edge_margin

	movable_content.position.x = clamp(movable_content.position.x, min_x, max_x)
	movable_content.position.y = clamp(movable_content.position.y, min_y, max_y)

func _update_root_layout() -> void:
	if background_rect != null:
		background_rect.size = size
	if interaction_layer != null:
		interaction_layer.size = size
	if fixed_ui_layer != null:
		fixed_ui_layer.size = size
	_center_tree_background()
	_layout_fixed_ui()
	_layout_movable_content_default_if_needed()
	_clamp_movable_content()

func _center_tree_background() -> void:
	if center_tree_rect == null:
		return
	var texture_size: Vector2 = Vector2(921, 1024)
	if center_tree_rect.texture != null:
		texture_size = center_tree_rect.texture.get_size()
	var target_width: float = minf(size.x * 0.86, 920.0)
	var aspect: float = texture_size.y / maxf(texture_size.x, 1.0)
	var target_height: float = target_width * aspect
	if target_height > size.y * 0.62:
		target_height = size.y * 0.62
		target_width = target_height / aspect
	center_tree_rect.size = Vector2(target_width, target_height)
	center_tree_rect.position = (size - center_tree_rect.size) * 0.5

func _layout_fixed_ui() -> void:
	if date_pill != null:
		date_pill.position = Vector2(SIDE_MARGIN, TOP_MARGIN)
	if shop_block != null:
		shop_block.position = Vector2(20, 180)
	if settings_block != null:
		settings_block.position = Vector2(20, 180 + shop_block.size.y + SHOP_SETTINGS_GAP)
	if coin_pill != null:
		coin_pill.position = Vector2(size.x - SIDE_MARGIN - coin_pill.size.x, TOP_MARGIN)
	if diamond_pill != null:
		diamond_pill.position = Vector2(size.x - SIDE_MARGIN - diamond_pill.size.x, TOP_MARGIN + coin_pill.size.y + 22)
	if nav_root != null:
		nav_root.position = Vector2((size.x - nav_root.size.x) * 0.5, size.y - NAV_BOTTOM_MARGIN - nav_root.size.y)
	if time_control_root != null:
		time_control_root.position = Vector2((size.x - time_control_root.size.x) * 0.5, size.y - TIME_CONTROL_BOTTOM_MARGIN - time_control_root.size.y)

func _layout_movable_content_default_if_needed() -> void:
	if movable_content == null:
		return
	if movable_content.position == Vector2.ZERO:
		movable_content.position = Vector2((size.x - movable_content.size.x * current_zoom) * 0.5, DEFAULT_VIEW_Y)

func set_demo_scenario(scenario: String) -> void:
	if scenario not in ["normal", "divorce", "remarriage", "distant_relative"]:
		return
	demo_scenario = scenario
	_prepare_demo_members()
	if movable_content != null and family_logo_root != null:
		await _build_tree_graph()
		reset_view()

func reset_view() -> void:
	current_zoom = default_zoom
	if movable_content == null:
		return
	movable_content.scale = Vector2(current_zoom, current_zoom)
	movable_content.position = Vector2((size.x - movable_content.size.x * current_zoom) * 0.5, DEFAULT_VIEW_Y)
	_clamp_movable_content()

func _get_gender_icon_path(gender_value: String) -> String:
	return FEMALE_ICON_PATH if gender_value.to_lower() == "female" else MALE_ICON_PATH

func _load_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as Texture2D
	return null

func _load_first_existing_font(paths: Array[String]) -> FontFile:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path) as FontFile
	return null
